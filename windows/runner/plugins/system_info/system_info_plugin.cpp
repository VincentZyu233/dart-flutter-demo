#include "system_info_plugin.h"

#include <windows.h>
#include <winsock2.h>
#include <iphlpapi.h>
#include <psapi.h>
#include <sysinfoapi.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <codecvt>
#include <locale>
#include <memory>
#include <string>
#include <sstream>

#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "iphlpapi.lib")

namespace flutter_showcase {

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

// ── OS Info ──────────────────────────────────────────────────────────────────

static std::string GetOSVersion() {
  // Use RtlGetVersion for accurate version (not affected by manifest)
  using RtlGetVersion = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  auto rtlGetVersion = (RtlGetVersion)GetProcAddress(
      GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion");

  if (!rtlGetVersion) return "Windows (unknown version)";

  RTL_OSVERSIONINFOW osvi = {};
  osvi.dwOSVersionInfoSize = sizeof(osvi);
  if (rtlGetVersion(&osvi) != 0) return "Windows (unknown version)";

  // Detect edition
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

  // Architecture
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

  // Get max MHz from registry
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

  // Get filesystem type
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

// ── Plugin Implementation ────────────────────────────────────────────────────

void SystemInfoPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "flutter_showcase/system_info",
      &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SystemInfoPlugin>();

  channel->SetMethodCallHandler(
      [plugin_ptr = plugin.get()](
          const flutter::MethodCall<flutter::EncodableValue>& call,
          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        plugin_ptr->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

SystemInfoPlugin::SystemInfoPlugin() {}

SystemInfoPlugin::~SystemInfoPlugin() {}

void SystemInfoPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "getInfo") {
    flutter::EncodableMap map;

    map[flutter::EncodableValue("OS")] =
        flutter::EncodableValue(GetOSVersion());
    map[flutter::EncodableValue("Host")] =
        flutter::EncodableValue(GetHostname());
    map[flutter::EncodableValue("Kernel")] =
        flutter::EncodableValue(GetKernelVersion());
    map[flutter::EncodableValue("Uptime")] =
        flutter::EncodableValue(GetUptime());
    map[flutter::EncodableValue("CPU")] =
        flutter::EncodableValue(GetCPUInfo());
    map[flutter::EncodableValue("Memory")] =
        flutter::EncodableValue(GetMemoryInfo());
    map[flutter::EncodableValue("Disk (C:\\)")] =
        flutter::EncodableValue(GetDiskInfo("C:\\"));
    map[flutter::EncodableValue("Local IP")] =
        flutter::EncodableValue(GetLocalIP());
    map[flutter::EncodableValue("Locale")] =
        flutter::EncodableValue(GetLocale());

    result->Success(flutter::EncodableValue(std::move(map)));
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_showcase
