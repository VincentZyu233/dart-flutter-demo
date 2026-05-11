import Foundation
import UIKit
import Flutter

public class SystemInfoPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "dart_flutter_demo/system_info",
            binaryMessenger: registrar.messenger()
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
        var info: [String: String] = [:]
        info["OS"] = getOS()
        info["Host"] = getHost()
        info["Kernel"] = getKernel()
        info["Uptime"] = getUptime()
        info["CPU"] = getCPU()
        info["Memory"] = getMemory()
        info["Disk"] = getDisk()
        info["Local IP"] = getLocalIP()
        info["Locale"] = getLocale()
        return info
    }

    private func getOS() -> String {
        let device = UIDevice.current
        let osName = device.model == "iPad" ? "iPadOS" : device.systemName
        return "\(device.model) (\(osName) \(device.systemVersion))"
    }

    private func getHost() -> String {
        return UIDevice.current.name
    }

    private func getKernel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let version = withUnsafePointer(to: &systemInfo.version) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                String(cString: $0)
            }
        }
        let release = withUnsafePointer(to: &systemInfo.release) {
            $0.withMemoryRebound(to: CChar.self, capacity: 256) {
                String(cString: $0)
            }
        }
        return "Darwin \(release) (\(version))"
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
        let model = UIDevice.current.model
        let cores = ProcessInfo.processInfo.processorCount
        return "\(model) (\(cores) cores)"
    }

    private func getMemory() -> String {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let totalGiB = Double(physicalMemory) / (1024.0 * 1024.0 * 1024.0)
        return String(format: "%.2f GiB total", totalGiB)
    }

    private func getDisk() -> String {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        if let url = paths.first {
            do {
                let values = try url.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
                if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacityForImportantUsageKey {
                    let used = total - available
                    let totalGiB = Double(total) / (1024.0 * 1024.0 * 1024.0)
                    let usedGiB = Double(used) / (1024.0 * 1024.0 * 1024.0)
                    let pct = total > 0 ? Int((Double(used) / Double(total)) * 100) : 0
                    return String(format: "%.2f GiB / %.2f GiB (%d%%)", usedGiB, totalGiB, pct)
                }
            } catch {}
        }
        return "unknown"
    }

    private func getLocalIP() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return "unknown" }
        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_INET) {
                let name = String(cString: ptr.pointee.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        ptr.pointee.ifa_addr,
                        socklen_t(addr.sa_len),
                        &hostname, socklen_t(hostname.count),
                        nil, 0, NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        freeifaddrs(ifaddr)
        return address ?? "unknown"
    }

    private func getLocale() -> String {
        return Locale.current.identifier
    }
}
