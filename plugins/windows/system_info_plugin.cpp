// Windows system info: compiled into runner, called via dart:ffi.
// No Flutter plugin API used — pure Win32 C++ with extern "C" exports.

#include "system_info_plugin.h"

#include <windows.h>
#include <winsock2.h>
#include <iphlpapi.h>
#include <psapi.h>
#include <sysinfoapi.h>

#include <codecvt>
#include <locale>
#include <string>
#include <sstream>
#include <cstring>
#include <cstdlib>

#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "iphlpapi.lib")

// ── Helpers ──────────────────────────────────────────────────────────────────

static std::string WStringToString(const std::wstring& wstr) {
  if (wstr.empty()) return "";
  int size = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.size(),
                                 nullptr, 0, nullptr, nullptr);
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), (int)wstr.size(),
                      &result[0], size, nullptr, nullptr);
  return result;
}

static std::string GetenvOrDefault(const char* name, const char* def = "") {
  char buf[256];
  DWORD len = GetEnvironmentVariableA(name, buf, sizeof(buf));
  return (len > 0 && len < sizeof(buf)) ? std::string(buf, len) : def;
}

static std::string EscapeJson(const std::string& s) {
  std::string r;
  r.reserve(s.size());
  for (char c : s) {
    switch (c) {
      case '"': r += "\\\""; break;
      case '\\': r += "\\\\"; break;
      case '\n': r += "\\n"; break;
      case '\r': r += "\\r"; break;
      case '\t': r += "\\t"; break;
      default: r += c;
    }
  }
  return r;
}

static std::string ToJson(const std::string& key, const std::string& value) {
  return "{\"" + EscapeJson(key) + "\":\"" + EscapeJson(value) + "\"}";
}

// ── OS Info ──────────────────────────────────────────────────────────────────

static std::string GetOSVersion() {
  using RtlGetVersion = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  auto rtlGetVersion = (RtlGetVersion)GetProcAddress(
      GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion");

  if (!rtlGetVersion) return "Windows (unknown version)";

  RTL_OSVERSIONINFOW osvi = {};
  osvi.dwOSVersionInfoSize = sizeof(osvi);
  if (rtlGetVersion(&osvi) != 0) return "Windows (unknown version)";

  std::string edition = "Windows";
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_LOCAL_MACHINE,
      L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", 0,
      KEY_READ, &hKey) == ERROR_SUCCESS) {
    wchar_t buf[256] = {};
    DWORD size = sizeof(buf);
    if (RegQueryValueExW(hKey, L"ProductName", nullptr, nullptr,
                         (LPBYTE)buf, &size) == ERROR_SUCCESS) {
      edition = WStringToString(buf);
    }
    RegCloseKey(hKey);
  }

  SYSTEM_INFO si;
  GetSystemInfo(&si);
  std::string arch;
  switch (si.wProcessorArchitecture) {
    case PROCESSOR_ARCHITECTURE_AMD64: arch = "x86_64"; break;
    case PROCESSOR_ARCHITECTURE_ARM64: arch = "aarch64"; break;
    case PROCESSOR_ARCHITECTURE_INTEL: arch = "x86"; break;
    default: arch = "unknown"; break;
  }

  std::ostringstream ss;
  ss << edition << " " << osvi.dwMajorVersion << "." << osvi.dwMinorVersion
     << " (Build " << osvi.dwBuildNumber << ") " << arch;
  return ss.str();
}

static std::string GetHostname() {
  wchar_t buf[MAX_COMPUTERNAME_LENGTH + 1];
  DWORD size = sizeof(buf) / sizeof(buf[0]);
  if (GetComputerNameW(buf, &size)) {
    return WStringToString(std::wstring(buf, size));
  }
  return "unknown";
}

static std::string GetKernelVersion() {
  std::ostringstream ss;
  ss << "WIN32_NT " << GetenvOrDefault("OS", "Windows");
  return ss.str();
}

static std::string GetUptime() {
  ULONGLONG millis = GetTickCount64();
  DWORD seconds = (DWORD)(millis / 1000);
  DWORD days = seconds / 86400;
  DWORD hours = (seconds % 86400) / 3600;
  DWORD mins = (seconds % 3600) / 60;

  std::ostringstream ss;
  if (days > 0) ss << days << " days, ";
  ss << hours << " hours, " << mins << " mins";
  return ss.str();
}

// ── CPU Info ─────────────────────────────────────────────────────────────────

static std::string GetCPUInfo() {
  HKEY hKey;
  std::string cpuName = "Unknown CPU";

  if (RegOpenKeyExW(HKEY_LOCAL_MACHINE,
      L"HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", 0,
      KEY_READ, &hKey) == ERROR_SUCCESS) {
    wchar_t buf[256] = {};
    DWORD size = sizeof(buf);
    if (RegQueryValueExW(hKey, L"ProcessorNameString", nullptr, nullptr,
                         (LPBYTE)buf, &size) == ERROR_SUCCESS) {
      cpuName = WStringToString(buf);
    }
    RegCloseKey(hKey);
  }

  SYSTEM_INFO si;
  GetSystemInfo(&si);
  DWORD cores = si.dwNumberOfProcessors;

  DWORD maxMHz = 0;
  if (RegOpenKeyExW(HKEY_LOCAL_MACHINE,
      L"HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", 0,
      KEY_READ, &hKey) == ERROR_SUCCESS) {
    DWORD size = sizeof(maxMHz);
    RegQueryValueExW(hKey, L"~MHz", nullptr, nullptr,
                     (LPBYTE)&maxMHz, &size);
    RegCloseKey(hKey);
  }

  std::ostringstream ss;
  ss << cpuName;
  ss << " (" << cores << ")";
  if (maxMHz > 0) ss << " @ " << (maxMHz / 1000.0) << " GHz";
  return ss.str();
}

// ── Memory Info ──────────────────────────────────────────────────────────────

static std::string GetMemoryInfo() {
  MEMORYSTATUSEX stat;
  stat.dwLength = sizeof(stat);
  if (!GlobalMemoryStatusEx(&stat)) return "unknown";

  double totalGiB = stat.ullTotalPhys / (1024.0 * 1024.0 * 1024.0);
  double usedGiB = (stat.ullTotalPhys - stat.ullAvailPhys) / (1024.0 * 1024.0 * 1024.0);
  DWORD usedPct = stat.dwMemoryLoad;

  std::ostringstream ss;
  ss << std::fixed;
  ss.precision(2);
  ss << usedGiB << " GiB / " << totalGiB << " GiB (" << usedPct << "%)";
  return ss.str();
}

// ── Disk Info ────────────────────────────────────────────────────────────────

static std::string GetDiskInfo(const std::string& drive) {
  std::wstring wdrive(drive.begin(), drive.end());
  ULARGE_INTEGER freeBytes, totalBytes, availBytes;

  if (!GetDiskFreeSpaceExW(wdrive.c_str(), &freeBytes, &totalBytes, &availBytes)) {
    return drive + ": not available";
  }

  double totalGiB = totalBytes.QuadPart / (1024.0 * 1024.0 * 1024.0);
  double usedGiB = (totalBytes.QuadPart - availBytes.QuadPart) / (1024.0 * 1024.0 * 1024.0);
  int usedPct = (int)((1.0 - (double)availBytes.QuadPart / totalBytes.QuadPart) * 100);

  wchar_t fsName[MAX_PATH + 1] = {};
  GetVolumeInformationW(wdrive.c_str(), nullptr, 0, nullptr, nullptr,
                        nullptr, fsName, sizeof(fsName) / sizeof(fsName[0]));

  std::ostringstream ss;
  ss << std::fixed;
  ss.precision(2);
  ss << drive << ": " << usedGiB << " GiB / " << totalGiB
     << " GiB (" << usedPct << "%) - " << WStringToString(fsName);
  return ss.str();
}

// ── Network Info ─────────────────────────────────────────────────────────────

static std::string GetLocalIP() {
  WSADATA wsaData;
  if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0) return "unknown";
  WSACleanup();

  char hostname[256];
  if (gethostname(hostname, sizeof(hostname)) != 0) return "unknown";

  struct addrinfo hints = {}, *result = nullptr;
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;

  if (getaddrinfo(hostname, nullptr, &hints, &result) != 0) return "unknown";

  char ip[INET_ADDRSTRLEN];
  auto addr = (struct sockaddr_in*)result->ai_addr;
  inet_ntop(AF_INET, &addr->sin_addr, ip, sizeof(ip));
  freeaddrinfo(result);

  return std::string(ip);
}

// ── Locale ───────────────────────────────────────────────────────────────────

static std::string GetLocale() {
  wchar_t buf[LOCALE_NAME_MAX_LENGTH];
  if (GetUserDefaultLocaleName(buf, LOCALE_NAME_MAX_LENGTH) > 0) {
    return WStringToString(buf);
  }
  return "unknown";
}

// ── JSON Builder ─────────────────────────────────────────────────────────────

static std::string BuildInfoJson() {
  std::ostringstream json;
  json << "{";
  json << "\"OS\":\"" << EscapeJson(GetOSVersion()) << "\",";
  json << "\"Host\":\"" << EscapeJson(GetHostname()) << "\",";
  json << "\"Kernel\":\"" << EscapeJson(GetKernelVersion()) << "\",";
  json << "\"Uptime\":\"" << EscapeJson(GetUptime()) << "\",";
  json << "\"CPU\":\"" << EscapeJson(GetCPUInfo()) << "\",";
  json << "\"Memory\":\"" << EscapeJson(GetMemoryInfo()) << "\",";
  json << "\"Disk (C:\\\\)\":\"" << EscapeJson(GetDiskInfo("C:\\")) << "\",";
  json << "\"Local IP\":\"" << EscapeJson(GetLocalIP()) << "\",";
  json << "\"Locale\":\"" << EscapeJson(GetLocale()) << "\"";
  json << "}";
  return json.str();
}

// ── Exported C API (called via dart:ffi) ─────────────────────────────────────

extern "C" {

__declspec(dllexport) char* GetSystemInfoJson() {
  std::string info = BuildInfoJson();
  char* result = (char*)malloc(info.size() + 1);
  memcpy(result, info.c_str(), info.size() + 1);
  return result;
}

__declspec(dllexport) void FreeSystemInfoJson(char* str) {
  free(str);
}

}  // extern "C"
