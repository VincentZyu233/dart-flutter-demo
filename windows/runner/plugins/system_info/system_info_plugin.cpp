// Windows system info: compiled into runner, called via dart:ffi.
// No Flutter plugin API used — pure Win32 C++ with extern "C" exports.

#include "system_info_plugin.h"

#include <windows.h>
#include <winsock2.h>
#include <iphlpapi.h>
#include <psapi.h>
#include <sysinfoapi.h>
#include <netioapi.h>

#include <codecvt>
#include <locale>
#include <string>
#include <sstream>
#include <cstring>
#include <cstdlib>
#include <iomanip>

#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "iphlpapi.lib")

// ── Helpers ──────────────────────────────────────────────────────────────────

typedef struct RawSMBIOSData {
  BYTE Used20CallingMethod;
  BYTE SMBIOSMajorVersion;
  BYTE SMBIOSMinorVersion;
  BYTE DmiRevision;
  DWORD Length;
  BYTE SMBIOSTableData[];
} RawSMBIOSData;

typedef struct SMBIOSHeader {
  BYTE Type;
  BYTE Length;
  WORD Handle;
} SMBIOSHeader;

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

static std::string Trim(const std::string& value) {
  const char* whitespace = " \t\r\n";
  const auto start = value.find_first_not_of(whitespace);
  if (start == std::string::npos) return "";
  const auto end = value.find_last_not_of(whitespace);
  return value.substr(start, end - start + 1);
}

static bool IsPlaceholderValue(const std::string& value) {
  if (value.empty()) return true;
  const std::string trimmed = Trim(value);
  return trimmed.empty() ||
         trimmed == "To be filled by O.E.M." ||
         trimmed == "To Be Filled By O.E.M." ||
         trimmed == "System Product Name" ||
         trimmed == "System Version" ||
         trimmed == "Default string";
}

static std::string ReadSmbiosString(const BYTE* stringArea, BYTE index) {
  if (index == 0) return "";

  BYTE current = 1;
  const char* ptr = reinterpret_cast<const char*>(stringArea);
  while (*ptr) {
    if (current == index) return Trim(ptr);
    ptr += strlen(ptr) + 1;
    ++current;
  }
  return "";
}

struct HostInfo {
  std::string vendor;
  std::string family;
  std::string name;
  std::string version;
};

static bool ReadHostInfoFromSmbios(HostInfo* out) {
  const DWORD bufferSize = GetSystemFirmwareTable('RSMB', 0, nullptr, 0);
  if (bufferSize == 0) return false;

  BYTE* buffer = reinterpret_cast<BYTE*>(malloc(bufferSize));
  if (!buffer) return false;

  const UINT bytesWritten = GetSystemFirmwareTable('RSMB', 0, buffer, bufferSize);
  if (bytesWritten != bufferSize) {
    free(buffer);
    return false;
  }

  const auto* raw = reinterpret_cast<const RawSMBIOSData*>(buffer);
  const BYTE* ptr = raw->SMBIOSTableData;
  const BYTE* end = raw->SMBIOSTableData + raw->Length;

  while (ptr + sizeof(SMBIOSHeader) < end) {
    const auto* header = reinterpret_cast<const SMBIOSHeader*>(ptr);
    if (header->Length == 0 || ptr + header->Length > end) break;

    const BYTE* stringArea = ptr + header->Length;
    const BYTE* next = stringArea;
    while (next + 1 < end && !(next[0] == 0 && next[1] == 0)) ++next;
    if (next + 1 >= end) break;

    if (header->Type == 1 && header->Length >= 0x1B) {
      out->vendor = ReadSmbiosString(stringArea, ptr[0x04]);
      out->name = ReadSmbiosString(stringArea, ptr[0x05]);
      out->version = ReadSmbiosString(stringArea, ptr[0x06]);
      out->family = ReadSmbiosString(stringArea, ptr[0x1A]);
      free(buffer);
      return true;
    }

    ptr = next + 2;
  }

  free(buffer);
  return false;
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

  // BrandingFormatString is the official Windows API to get the correct
  // product name (e.g. "Windows 11 IoT Enterprise LTSC" on actual Win11).
  // It's available since Windows 10 build 10240 (shell32.dll).
  std::string edition = "Windows";
  std::string displayVersion;
  using BrandingFormatString_t = PWSTR(WINAPI*)(PCWSTR);
  auto branding = (BrandingFormatString_t)GetProcAddress(
      GetModuleHandleW(L"shell32.dll"), "BrandingFormatString");
  if (branding) {
    PWSTR rawName = branding(L"%WINDOWS_LONG%");
    if (rawName && *rawName) {
      edition = WStringToString(rawName);
    }
    GlobalFree(rawName);
  } else {
    // Fallback: read ProductName from registry (old Windows or PE)
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
  }
  // DisplayVersion is always read from registry
  HKEY hKey;
  if (RegOpenKeyExW(HKEY_LOCAL_MACHINE,
      L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", 0,
      KEY_READ, &hKey) == ERROR_SUCCESS) {
    wchar_t buf[256] = {};
    DWORD size = sizeof(buf);
    if (RegQueryValueExW(hKey, L"DisplayVersion", nullptr, nullptr,
                         (LPBYTE)buf, &size) == ERROR_SUCCESS) {
      displayVersion = WStringToString(buf);
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
  ss << edition;
  if (!displayVersion.empty()) ss << " (" << displayVersion << ")";
  ss << " " << arch;
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

static std::string GetHostLabel() {
  HostInfo hostInfo;
  if (ReadHostInfoFromSmbios(&hostInfo)) {
    if (!IsPlaceholderValue(hostInfo.name)) {
      if (!IsPlaceholderValue(hostInfo.version)) {
        return hostInfo.name + " (" + hostInfo.version + ")";
      }
      return hostInfo.name;
    }
    if (!IsPlaceholderValue(hostInfo.family)) return hostInfo.family;
  }
  return GetHostname();
}

static std::string GetKernelVersion() {
  using RtlGetVersion = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  auto rtlGetVersion = (RtlGetVersion)GetProcAddress(
      GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion");

  if (!rtlGetVersion) return "WIN32_NT";

  RTL_OSVERSIONINFOW osvi = {};
  osvi.dwOSVersionInfoSize = sizeof(osvi);
  if (rtlGetVersion(&osvi) != 0) return "WIN32_NT";

  std::ostringstream ss;
  ss << "WIN32_NT " << osvi.dwMajorVersion << "."
     << osvi.dwMinorVersion << "." << osvi.dwBuildNumber;
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

  DWORD cores = GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
  if (cores == 0) {
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    cores = si.dwNumberOfProcessors;
  }

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
  ss << std::fixed << std::setprecision(2);
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

  ULONG size = 0;
  DWORD ret = GetAdaptersAddresses(AF_INET, GAA_FLAG_SKIP_ANYCAST |
      GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER, nullptr, nullptr, &size);
  if (ret != ERROR_BUFFER_OVERFLOW) {
    WSACleanup();
    return "unknown";
  }

  IP_ADAPTER_ADDRESSES* adapters =
      reinterpret_cast<IP_ADAPTER_ADDRESSES*>(malloc(size));
  if (!adapters) {
    WSACleanup();
    return "unknown";
  }

  ret = GetAdaptersAddresses(AF_INET, GAA_FLAG_SKIP_ANYCAST |
      GAA_FLAG_SKIP_MULTICAST | GAA_FLAG_SKIP_DNS_SERVER, nullptr, adapters, &size);
  if (ret != NO_ERROR) {
    free(adapters);
    WSACleanup();
    return "unknown";
  }

  DWORD defaultIfIndex = 0;
  MIB_IPFORWARDROW route = {};
  SOCKADDR_IN destination = {};
  destination.sin_family = AF_INET;
  SOCKADDR_IN source = {};
  source.sin_family = AF_INET;
  if (GetBestRoute(destination.sin_addr.S_un.S_addr, source.sin_addr.S_un.S_addr, &route) == NO_ERROR) {
    defaultIfIndex = route.dwForwardIfIndex;
  }

  std::string ip = "unknown";
  std::string fallbackIp = "unknown";
  for (auto adapter = adapters; adapter != nullptr; adapter = adapter->Next) {
    if (adapter->IfType == IF_TYPE_SOFTWARE_LOOPBACK ||
        adapter->OperStatus != IfOperStatusUp) {
      continue;
    }

    for (auto addr = adapter->FirstUnicastAddress; addr != nullptr; addr = addr->Next) {
      if (!addr->Address.lpSockaddr ||
          addr->Address.lpSockaddr->sa_family != AF_INET) {
        continue;
      }

      char buf[INET_ADDRSTRLEN] = {};
      auto* ipv4 = reinterpret_cast<sockaddr_in*>(addr->Address.lpSockaddr);
      if (inet_ntop(AF_INET, &ipv4->sin_addr, buf, sizeof(buf))) {
        if (strncmp(buf, "127.", 4) == 0 || strncmp(buf, "169.254.", 8) == 0) {
          continue;
        }
        if (adapter->IfIndex == defaultIfIndex) {
          ip = buf;
          break;
        }
        if (fallbackIp == "unknown") {
          fallbackIp = buf;
        }
      }
    }

    if (ip != "unknown") break;
  }

  if (ip == "unknown") {
    ip = fallbackIp;
  }

  free(adapters);
  WSACleanup();
  return ip;
}

// ── Locale ───────────────────────────────────────────────────────────────────

static std::string GetLocale() {
  wchar_t buf[LOCALE_NAME_MAX_LENGTH];
  if (GetUserDefaultLocaleName(buf, LOCALE_NAME_MAX_LENGTH) > 0) {
    return WStringToString(buf);
  }
  return "unknown";
}

static std::string GetBuildKernelVersion() {
  using RtlGetVersion = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  auto rtlGetVersion = (RtlGetVersion)GetProcAddress(
      GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion");

  if (!rtlGetVersion) return "WIN32_NT";

  RTL_OSVERSIONINFOW osvi = {};
  osvi.dwOSVersionInfoSize = sizeof(osvi);
  if (rtlGetVersion(&osvi) != 0) return "WIN32_NT";

  std::ostringstream ss;
  ss << "WIN32_NT " << osvi.dwMajorVersion << "."
     << osvi.dwMinorVersion << "." << osvi.dwBuildNumber;
  return ss.str();
}

// ── JSON Builder ─────────────────────────────────────────────────────────────

static std::string BuildInfoJson() {
  std::ostringstream json;
  json << "{";
  json << "\"OS\":\"" << EscapeJson(GetOSVersion()) << "\",";
  json << "\"Host\":\"" << EscapeJson(GetHostLabel()) << "\",";
  json << "\"Kernel\":\"" << EscapeJson(GetBuildKernelVersion()) << "\",";
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
