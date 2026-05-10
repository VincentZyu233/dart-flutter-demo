import Cocoa
import Darwin
import FlutterMacOS
import Foundation

public class SystemInfoPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dart_flutter_demo/system_info",
            binaryMessenger: registrar.messenger
        )
        let instance = SystemInfoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "getInfo" {
            result(getInfo())
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func getInfo() -> [String: String] {
        [
            "OS": getOS(),
            "Host": getHost(),
            "Kernel": getKernel(),
            "Uptime": getUptime(),
            "CPU": getCPU(),
            "Memory": getMemory(),
            "Disk": getDisk(),
            "Local IP": getLocalIP(),
            "Locale": getLocale(),
        ]
    }

    private func getOS() -> String {
        let processInfo = ProcessInfo.processInfo
        let arch = sysctlString("hw.machine") ?? "unknown"
        return "\(processInfo.operatingSystemVersionString) \(arch)"
    }

    private func getHost() -> String {
        Host.current().localizedName ?? Host.current().name ?? "unknown"
    }

    private func getKernel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let release = withUnsafePointer(to: &systemInfo.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                String(cString: $0)
            }
        }
        return "Darwin \(release)"
    }

    private func getUptime() -> String {
        let seconds = Int(ProcessInfo.processInfo.systemUptime)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let mins = (seconds % 3600) / 60
        var result = ""
        if days > 0 { result += "\(days) days, " }
        result += "\(hours) hours, \(mins) mins"
        return result
    }

    private func getCPU() -> String {
        let cores = ProcessInfo.processInfo.processorCount
        let brand = sysctlString("machdep.cpu.brand_string") ?? "Apple CPU"
        return "\(brand) (\(cores) cores)"
    }

    private func getMemory() -> String {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            let totalGiB = Double(totalBytes) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GiB total", totalGiB)
        }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            let totalGiB = Double(totalBytes) / (1024.0 * 1024.0 * 1024.0)
            return String(format: "%.2f GiB total", totalGiB)
        }

        let freePages = UInt64(stats.free_count > stats.speculative_count ? stats.free_count - stats.speculative_count : 0)
        let fileBackedPages = UInt64(stats.external_page_count)
        let cachedBytes = (freePages + fileBackedPages) * UInt64(pageSize)
        let usedBytes = totalBytes > cachedBytes ? totalBytes - cachedBytes : 0
        let usedGiB = Double(usedBytes) / (1024.0 * 1024.0 * 1024.0)
        let totalGiB = Double(totalBytes) / (1024.0 * 1024.0 * 1024.0)
        let pct = totalBytes > 0 ? Int((Double(usedBytes) / Double(totalBytes)) * 100) : 0
        return String(format: "%.2f GiB / %.2f GiB (%d%%)", usedGiB, totalGiB, pct)
    }

    private func getDisk() -> String {
        let url = URL(fileURLWithPath: "/")
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey,
            ])
            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacityForImportantUsageKey ?? values.volumeAvailableCapacityKey {
                let used = total - available
                let totalGiB = Double(total) / (1024.0 * 1024.0 * 1024.0)
                let usedGiB = Double(used) / (1024.0 * 1024.0 * 1024.0)
                let pct = total > 0 ? Int((Double(used) / Double(total)) * 100) : 0
                return String(format: "%.2f GiB / %.2f GiB (%d%%)", usedGiB, totalGiB, pct)
            }
        } catch {}
        return "unknown"
    }

    private func getLocalIP() -> String {
        var preferredAddress: String?
        var fallbackAddress: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return "unknown" }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let addr = ptr.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_INET) {
                let name = String(cString: ptr.pointee.ifa_name)
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    ptr.pointee.ifa_addr,
                    socklen_t(addr.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                let ip = String(cString: hostname)
                if !ip.hasPrefix("127.") {
                    if name.hasPrefix("en") {
                        preferredAddress = ip
                        break
                    }
                    if fallbackAddress == nil {
                        fallbackAddress = ip
                    }
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return preferredAddress ?? fallbackAddress ?? "unknown"
    }

    private func getLocale() -> String {
        Locale.current.identifier
    }

    private func sysctlString(_ name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(size))
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }
}
