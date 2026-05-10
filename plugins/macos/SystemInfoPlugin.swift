import Cocoa
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
        let physical = ProcessInfo.processInfo.physicalMemory
        let totalGiB = Double(physical) / (1024.0 * 1024.0 * 1024.0)
        return String(format: "%.2f GiB total", totalGiB)
    }

    private func getDisk() -> String {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey,
            ])
            if let total = values.volumeTotalCapacity,
               let available = values.volumeAvailableCapacityForImportantUsageKey {
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
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return "unknown" }
        defer { freeifaddrs(ifaddr) }

        var ptr = firstAddr
        while true {
            let addr = ptr.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_INET) {
                let name = String(cString: ptr.pointee.ifa_name)
                if name.hasPrefix("en") {
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
                    address = String(cString: hostname)
                    break
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return address ?? "unknown"
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
