package com.example.flutter_showcase

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.view.Display
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.net.NetworkInterface
import java.text.DecimalFormat
import java.util.Locale
import java.util.concurrent.TimeUnit

class SystemInfoPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "flutter_showcase/system_info")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "getInfo") {
            result.success(getInfo())
        } else {
            result.notImplemented()
        }
    }

    private fun getInfo(): Map<String, String> {
        val info = mutableMapOf<String, String>()
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

    private fun getOS(): String {
        return "${Build.MANUFACTURER} ${Build.MODEL} (Android ${Build.VERSION.RELEASE}, API ${Build.VERSION.SDK_INT})"
    }

    private fun getHost(): String {
        return "${Build.MANUFACTURER} ${Build.MODEL}"
    }

    private fun getKernel(): String {
        return "Linux ${System.getProperty("os.version")} (${Build.HARDWARE})"
    }

    private fun getUptime(): String {
        val uptimeMillis = System.currentTimeMillis() - android.os.SystemClock.elapsedRealtime()
        val uptimeSec = TimeUnit.MILLISECONDS.toSeconds(
            System.currentTimeMillis() - android.os.SystemClock.elapsedRealtime()
        )
        // elapsedRealtime is time since boot, so uptime = elapsedRealtime
        val elapsed = android.os.SystemClock.elapsedRealtime()
        val seconds = TimeUnit.MILLISECONDS.toSeconds(elapsed)
        val days = seconds / 86400
        val hours = (seconds % 86400) / 3600
        val mins = (seconds % 3600) / 60

        return buildString {
            if (days > 0) append("$days days, ")
            append("$hours hours, $mins mins")
        }
    }

    private fun getCPU(): String {
        return try {
            val reader = java.io.BufferedReader(java.io.FileReader("/proc/cpuinfo"))
            var model = "Unknown CPU"
            var cores = 0
            reader.useLines { lines ->
                lines.forEach { line ->
                    if (line.startsWith("model name") && model == "Unknown CPU") {
                        model = line.substringAfter(": ").trim()
                    }
                    if (line.startsWith("processor")) {
                        cores++
                    }
                }
            }
            "$model ($cores)"
        } catch (e: Exception) {
            "${Runtime.getRuntime().availableProcessors()} cores"
        }
    }

    private fun getMemory(): String {
        val runtime = Runtime.getRuntime()
        val maxMemory = runtime.maxMemory()
        val totalMemory = runtime.totalMemory()
        val freeMemory = runtime.freeMemory()
        val usedMemory = totalMemory - freeMemory

        // Try to get system memory from /proc/meminfo if available
        return try {
            val reader = java.io.BufferedReader(java.io.FileReader("/proc/meminfo"))
            var memTotal = 0L
            var memAvailable = 0L
            reader.useLines { lines ->
                lines.forEach { line ->
                    if (line.startsWith("MemTotal:")) {
                        memTotal = line.substringAfter(":").trim()
                            .split(" ")[0].toLongOrNull() ?: 0
                    }
                    if (line.startsWith("MemAvailable:")) {
                        memAvailable = line.substringAfter(":").trim()
                            .split(" ")[0].toLongOrNull() ?: 0
                    }
                }
            }
            if (memTotal > 0) {
                val totalGiB = memTotal / (1024.0 * 1024.0)
                val usedGiB = (memTotal - memAvailable) / (1024.0 * 1024.0)
                val pct = ((1.0 - memAvailable.toDouble() / memTotal) * 100).toInt()
                "${formatGiB(usedGiB)} / ${formatGiB(totalGiB)} ($pct%)"
            } else {
                "${formatBytes(usedMemory)} / ${formatBytes(maxMemory)}"
            }
        } catch (e: Exception) {
            "${formatBytes(usedMemory)} / ${formatBytes(maxMemory)}"
        }
    }

    private fun getDisk(): String {
        val stat = StatFs(Environment.getDataDirectory().path)
        val totalBytes = stat.totalBytes
        val freeBytes = stat.freeBytes
        val usedBytes = totalBytes - freeBytes
        val totalGiB = totalBytes / (1024.0 * 1024.0 * 1024.0)
        val usedGiB = usedBytes / (1024.0 * 1024.0 * 1024.0)
        val pct = ((1.0 - freeBytes.toDouble() / totalBytes) * 100).toInt()

        return "${formatGiB(usedGiB)} / ${formatGiB(totalGiB)} ($pct%)"
    }

    private fun getLocalIP(): String {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val networkInterface = interfaces.nextElement()
                if (networkInterface.isLoopback || !networkInterface.isUp) continue

                val addresses = networkInterface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val address = addresses.nextElement()
                    if (!address.isLoopbackAddress && address is java.net.Inet4Address) {
                        return "${address.hostAddress}/${networkInterface.name}"
                    }
                }
            }
        } catch (e: Exception) {
            // ignore
        }
        return "unknown"
    }

    private fun getLocale(): String {
        return Locale.getDefault().toString()
    }

    private fun formatBytes(bytes: Long): String {
        val df = DecimalFormat("#.##")
        return when {
            bytes >= 1024L * 1024 * 1024 -> "${df.format(bytes / (1024.0 * 1024.0 * 1024.0))} GiB"
            bytes >= 1024L * 1024 -> "${df.format(bytes / (1024.0 * 1024.0))} MiB"
            bytes >= 1024L -> "${df.format(bytes / 1024.0)} KiB"
            else -> "$bytes B"
        }
    }

    private fun formatGiB(gib: Double): String {
        return DecimalFormat("#.##").format(gib) + " GiB"
    }
}
