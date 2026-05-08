#include "system_info_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/standard_method_codec.h>

#include <cstring>
#include <fstream>
#include <memory>
#include <sstream>
#include <string>
#include <sys/statvfs.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <arpa/inet.h>

namespace flutter_showcase {

// ── Helpers ──────────────────────────────────────────────────────────────────

static std::string ReadFileFirstLine(const std::string& path) {
  std::ifstream f(path);
  std::string line;
  if (std::getline(f, line)) {
    // trim trailing newline/carriage return
    while (!line.empty() && (line.back() == '\n' || line.back() == '\r')) {
      line.pop_back();
    }
    return line;
  }
  return "unknown";
}

static std::string TrimSuffix(const std::string& s, const std::string& suffix) {
  if (suffix.size() <= s.size() &&
      s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0) {
    return s.substr(0, s.size() - suffix.size());
  }
  return s;
}

// ── OS Info ──────────────────────────────────────────────────────────────────

static std::string GetOSVersion() {
  std::string version = ReadFileFirstLine("/etc/os-release");
  // Parse PRETTY_NAME="..."
  auto pos = version.find("PRETTY_NAME=\"");
  if (pos != std::string::npos) {
    version = version.substr(pos + 14);
    auto end = version.find('"');
    if (end != std::string::npos) version = version.substr(0, end);
  } else {
    version = ReadFileFirstLine("/etc/issue");
    version = TrimSuffix(version, " \\n \\l");
  }
  return version;
}

static std::string GetHostname() {
  char buf[256];
  if (gethostname(buf, sizeof(buf)) == 0) {
    return std::string(buf);
  }
  return "unknown";
}

static std::string GetKernelVersion() {
  struct utsname uts;
  if (uname(&uts) == 0) {
    std::ostringstream ss;
    ss << uts.sysname << " " << uts.release << " " << uts.machine;
    return ss.str();
  }
  return "unknown";
}

static std::string GetUptime() {
  std::ifstream f("/proc/uptime");
  double uptimeSeconds = 0;
  if (f >> uptimeSeconds) {
    int total = (int)uptimeSeconds;
    int days = total / 86400;
    int hours = (total % 86400) / 3600;
    int mins = (total % 3600) / 60;

    std::ostringstream ss;
    if (days > 0) ss << days << " days, ";
    ss << hours << " hours, " << mins << " mins";
    return ss.str();
  }
  return "unknown";
}

// ── CPU Info ─────────────────────────────────────────────────────────────────

static std::string GetCPUInfo() {
  std::ifstream f("/proc/cpuinfo");
  std::string line;
  std::string modelName;
  int cores = 0;
  float mhz = 0;

  while (std::getline(f, line)) {
    if (line.find("model name") != std::string::npos && modelName.empty()) {
      auto pos = line.find(':');
      if (pos != std::string::npos) {
        modelName = line.substr(pos + 2);
      }
    }
    if (line.find("cpu MHz") != std::string::npos) {
      auto pos = line.find(':');
      if (pos != std::string::npos) {
        mhz = std::stof(line.substr(pos + 2));
      }
    }
    if (line.find("processor") != std::string::npos) {
      cores++;
    }
  }

  std::ostringstream ss;
  ss << (modelName.empty() ? "Unknown CPU" : modelName);
  ss << " (" << cores << ")";
  if (mhz > 0) ss << " @ " << (mhz / 1000.0) << " GHz";
  return ss.str();
}

// ── Memory Info ──────────────────────────────────────────────────────────────

static std::string GetMemoryInfo() {
  std::ifstream f("/proc/meminfo");
  long memTotal = 0, memAvail = 0;
  std::string line;

  while (std::getline(f, line)) {
    if (line.find("MemTotal:") != std::string::npos) {
      sscanf(line.c_str(), "MemTotal: %ld kB", &memTotal);
    }
    if (line.find("MemAvailable:") != std::string::npos) {
      sscanf(line.c_str(), "MemAvailable: %ld kB", &memAvail);
    }
  }

  if (memTotal == 0) return "unknown";

  double totalGiB = memTotal / (1024.0 * 1024.0);
  double usedGiB = (memTotal - memAvail) / (1024.0 * 1024.0);
  int usedPct = (int)((1.0 - (double)memAvail / memTotal) * 100);

  std::ostringstream ss;
  ss << std::fixed;
  ss.precision(2);
  ss << usedGiB << " GiB / " << totalGiB << " GiB (" << usedPct << "%)";
  return ss.str();
}

// ── Disk Info ────────────────────────────────────────────────────────────────

static std::string GetDiskInfo(const std::string& mount) {
  struct statvfs stat;
  if (statvfs(mount.c_str(), &stat) != 0) {
    return mount + ": not available";
  }

  double totalGiB = (double)(stat.f_blocks * stat.f_frsize) / (1024.0 * 1024.0 * 1024.0);
  double freeGiB = (double)(stat.f_bavail * stat.f_frsize) / (1024.0 * 1024.0 * 1024.0);
  double usedGiB = totalGiB - freeGiB;
  int usedPct = (int)((1.0 - (double)stat.f_bavail / stat.f_blocks) * 100);

  std::ostringstream ss;
  ss << std::fixed;
  ss.precision(2);
  ss << mount << ": " << usedGiB << " GiB / " << totalGiB
     << " GiB (" << usedPct << "%)";
  return ss.str();
}

// ── Network Info ─────────────────────────────────────────────────────────────

static std::string GetLocalIP() {
  struct ifaddrs *ifaddr = nullptr;
  if (getifaddrs(&ifaddr) == -1) return "unknown";

  std::string result = "unknown";
  for (auto* ifa = ifaddr; ifa != nullptr; ifa = ifa->ifa_next) {
    if (ifa->ifa_addr == nullptr) continue;
    if (ifa->ifa_addr->sa_family != AF_INET) continue;
    // skip loopback
    if (strcmp(ifa->ifa_name, "lo") == 0) continue;

    char ip[INET_ADDRSTRLEN];
    auto addr = (struct sockaddr_in*)ifa->ifa_addr;
    inet_ntop(AF_INET, &addr->sin_addr, ip, sizeof(ip));
    result = std::string(ip) + " (" + ifa->ifa_name + ")";
    break;
  }
  freeifaddrs(ifaddr);
  return result;
}

// ── Locale ───────────────────────────────────────────────────────────────────

static std::string GetLocale() {
  const char* lang = getenv("LANG");
  if (lang && lang[0]) return lang;
  const char* lc = setlocale(LC_ALL, nullptr);
  if (lc && lc[0]) return lc;
  return "unknown";
}

// ── Plugin Implementation ────────────────────────────────────────────────────

void SystemInfoPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrar* registrar) {
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
    map[flutter::EncodableValue("Disk (/)")] =
        flutter::EncodableValue(GetDiskInfo("/"));
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
