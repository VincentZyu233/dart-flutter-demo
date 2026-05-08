import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

// FFI type defs for Windows C++ exports (using Uint8 instead of Utf8)
typedef _GetSystemInfoJsonNative = Pointer<Uint8> Function();
typedef _GetSystemInfoJsonDart = Pointer<Uint8> Function();
typedef _FreeSystemInfoJsonNative = Void Function(Pointer<Uint8>);
typedef _FreeSystemInfoJsonDart = void Function(Pointer<Uint8>);

// Helper: convert null-terminated C string to Dart String
String _ptrToString(Pointer<Uint8> ptr) {
  final bytes = <int>[];
  for (int i = 0;; i++) {
    final b = ptr[i];
    if (b == 0) break;
    bytes.add(b);
  }
  return utf8.decode(bytes);
}

abstract class SystemInfoService {
  Future<Map<String, String>> getInfo();
}

SystemInfoService createSystemInfoService() {
  if (Platform.isWindows) return _WindowsSystemInfo();
  if (Platform.isLinux) return _LinuxSystemInfo();
  if (Platform.isAndroid) return _AndroidSystemInfo();
  if (Platform.isIOS) return _IOSSystemInfo();
  throw UnsupportedError('Platform not supported');
}

// ── iOS (Swift MethodChannel with dart:io fallback) ──────────────────────────

class _IOSSystemInfo implements SystemInfoService {
  static const _channel = MethodChannel('flutter_showcase/system_info');

  @override
  Future<Map<String, String>> getInfo() async {
    try {
      final result = await _channel.invokeMapMethod<String, String>('getInfo');
      if (result != null) return result;
    } catch (_) {}
    return _getInfoFallback();
  }

  Map<String, String> _getInfoFallback() {
    final result = <String, String>{};
    result['OS'] = Platform.operatingSystemVersion;
    result['Host'] = Platform.localHostname;
    result['Kernel'] = 'Darwin ${Platform.operatingSystemVersion}';
    result['Uptime'] = 'N/A (fallback)';
    result['CPU'] = '${Platform.numberOfProcessors} cores';
    result['Memory'] = 'N/A (fallback)';
    result['Disk'] = 'N/A (fallback)';
    result['Local IP'] = 'N/A (fallback)';
    result['Locale'] = Platform.localeName;
    return result;
  }
}

// ── Windows (C++ FFI with dart:io fallback) ──────────────────────────────────

class _WindowsSystemInfo implements SystemInfoService {
  @override
  Future<Map<String, String>> getInfo() async {
    try {
      final dylib = DynamicLibrary.process();
      final getJson = dylib.lookupFunction<_GetSystemInfoJsonNative, _GetSystemInfoJsonDart>('GetSystemInfoJson');
      final freeJson = dylib.lookupFunction<_FreeSystemInfoJsonNative, _FreeSystemInfoJsonDart>('FreeSystemInfoJson');

      final ptr = getJson();
      final jsonStr = _ptrToString(ptr);
      freeJson(ptr);

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return _getInfoFallback();
    }
  }

  Map<String, String> _getInfoFallback() {
    final result = <String, String>{};
    result['OS'] = Platform.operatingSystemVersion;
    result['Host'] = Platform.localHostname;
    result['Kernel'] = 'Windows ${Platform.operatingSystemVersion}';

    // Parse systeminfo output for uptime, CPU, memory
    try {
      final proc = Process.runSync('systeminfo', [], runInShell: true);
      final out = proc.stdout.toString();
      final lines = out.split('\n');
      String? host, bootTimeStr, cpuStr, totalMem, availMem;

      for (final line in lines) {
        final l = line.trim();
        if (host == null) {
          host = _tryExtract(l, ['Host Name:', '主机名:', '主機名:']);
        }
        if (bootTimeStr == null) {
          bootTimeStr = _tryExtract(l, ['System Boot Time:', '系统启动时间:', '系統啟動時間:']);
        }
        if (cpuStr == null) {
          cpuStr = _tryExtract(l, ['Processor(s):', '处理器:', '處理器:']);
        }
        if (totalMem == null) {
          totalMem = _tryExtract(l, ['Total Physical Memory:', '物理内存总量:', '物理記憶體總量:']);
        }
        if (availMem == null) {
          availMem = _tryExtract(l, ['Available Physical Memory:', '可用的物理内存:', '可用的物理記憶體:']);
        }
      }

      if (bootTimeStr != null) {
        result['Uptime'] = _parseWindowsBootUptime(bootTimeStr);
      }
      if (cpuStr != null) {
        result['CPU'] = '$cpuStr (${Platform.numberOfProcessors} cores)';
      } else {
        result['CPU'] = '${Platform.numberOfProcessors} cores';
      }
      if (totalMem != null && availMem != null) {
        result['Memory'] = '$_parseMemField(availMem) available / $_parseMemField(totalMem) total';
      }
    } catch (_) {
      result['Uptime'] = 'unavailable (ffi fallback)';
      result['CPU'] = '${Platform.numberOfProcessors} cores';
    }

    // Disk info via PowerShell (locale-independent)
    try {
      final proc = Process.runSync(
        'powershell',
        ['-NoProfile', '-Command',
          "Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID='C:'\" | Select-Object -ExpandProperty Size,FreeSpace"],
        runInShell: true,
      );
      final out = proc.stdout.toString().trim();
      final parts = out.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final total = int.tryParse(parts[0]);
        final free = int.tryParse(parts[1]);
        if (total != null && free != null && total > 0) {
          final used = total - free;
          final totalGiB = total / (1024.0 * 1024.0 * 1024.0);
          final usedGiB = used / (1024.0 * 1024.0 * 1024.0);
          final pct = ((used / total) * 100).round();
          result['Disk (C:\\)'] = 'C: ${usedGiB.toStringAsFixed(1)} GiB / ${totalGiB.toStringAsFixed(1)} GiB ($pct%)';
        }
      }
    } catch (_) {
      result['Disk (C:\\)'] = _deriveDiskFallback();
    }

    // Local IP
    result['Local IP'] = _getWindowsLocalIPFallback();
    result['Locale'] = Platform.localeName;
    return result;
  }

  static String? _tryExtract(String line, List<String> prefixes) {
    for (final p in prefixes) {
      if (line.contains(p)) {
        return line.substring(line.indexOf(p) + p.length).trim();
      }
    }
    return null;
  }

  static String _parseMemField(String raw) {
    raw = raw.replaceAll(',', '');
    final parts = raw.split(' ');
    // e.g. "8,192 MB" or "8.19 GB"
    double? value;
    String unit = '';
    for (int i = 0; i < parts.length; i++) {
      final v = double.tryParse(parts[i]);
      if (v != null) {
        value = v;
        if (i + 1 < parts.length) unit = parts[i + 1].toUpperCase();
        break;
      }
    }
    if (value == null) return raw;
    if (unit == 'MB') return '${(value / 1024).toStringAsFixed(1)} GiB';
    if (unit == 'GB') return '${value.toStringAsFixed(1)} GiB';
    return raw;
  }

  static String _parseWindowsBootUptime(String bootStr) {
    try {
      // systeminfo format: "5/7/2026, 8:30:15 AM" or "2026/5/7, 8:30:15"
      // Try wmic format first: "20260507083015.500000+480"
      final digits = bootStr.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 14) {
        final y = int.parse(digits.substring(0, 4));
        final m = int.parse(digits.substring(4, 6));
        final d = int.parse(digits.substring(6, 8));
        final h = int.parse(digits.substring(8, 10));
        final mi = int.parse(digits.substring(10, 12));
        final s = int.parse(digits.substring(12, 14));
        final dt = DateTime(y, m, d, h, mi, s);
        final diff = DateTime.now().toUtc().difference(dt);
        return _formatDuration(diff);
      }
    } catch (_) {}

    // Try common date/time formats
    try {
      final cleaned = bootStr
          .replaceAll(RegExp(r'[^0-9/:,\- APMampm.]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      DateTime? dt;
      dt = DateTime.tryParse(cleaned);
      if (dt == null) {
        // Try "M/d/yyyy, h:mm:ss AM" format
        final regex = RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})[, ]+(\d{1,2}):(\d{2}):(\d{2})');
        final m = regex.firstMatch(cleaned);
        if (m != null) {
          final month = int.tryParse(m.group(1)!) ?? 0;
          final day = int.tryParse(m.group(2)!) ?? 0;
          final year = int.tryParse(m.group(3)!) ?? 0;
          final hour = int.tryParse(m.group(4)!) ?? 0;
          final min = int.tryParse(m.group(5)!) ?? 0;
          final sec = int.tryParse(m.group(6)!) ?? 0;
          if (year > 2000) {
            var h24 = hour;
            if (cleaned.contains('PM') && hour < 12) h24 += 12;
            if (cleaned.contains('AM') && hour == 12) h24 = 0;
            dt = DateTime(month > 12 ? year : year, month > 12 ? day : month, month > 12 ? month : day, h24, min, sec);
          }
        }
      }
      if (dt != null) {
        final diff = DateTime.now().difference(dt);
        return _formatDuration(diff);
      }
    } catch (_) {}
    return bootStr;
  }

  static String _formatDuration(Duration diff) {
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    final buf = StringBuffer();
    if (days > 0) buf.write('$days days, ');
    buf.write('$hours hours, $mins mins');
    return buf.toString();
  }

  static String _getWindowsLocalIPFallback() {
    try {
      final proc = Process.runSync('ipconfig', [], runInShell: true);
      final out = proc.stdout.toString();
      final regex = RegExp(r'IPv4 Address[ .]*:\s*([0-9.]+)');
      final match = regex.firstMatch(out);
      if (match != null) return match.group(1)!;

      // Fallback: try ipconfig with Chinese locale
      final cnRegex = RegExp(r'IPv4 \S+[ .]*:\s*([0-9.]+)');
      final cnMatch = cnRegex.firstMatch(out);
      if (cnMatch != null) return cnMatch.group(1)!;
    } catch (_) {}
    return 'unknown';
  }

  static String _deriveDiskFallback() {
    try {
      final cwd = Directory.current.path;
      final stat = FileStat.statSync(cwd);
      return 'C: drive accessible';
    } catch (_) {
      return 'C: unknown';
    }
  }
}

// ── Linux (dart:io) ──────────────────────────────────────────────────────────

class _LinuxSystemInfo implements SystemInfoService {
  @override
  Future<Map<String, String>> getInfo() async {
    return {
      'OS': _getOS(),
      'Host': _getHostname(),
      'Kernel': _getKernel(),
      'Uptime': _getUptime(),
      'CPU': _getCPU(),
      'Memory': _getMemory(),
      'Disk (/)': _getDisk('/'),
      'Local IP': _getLocalIP(),
      'Locale': _getLocale(),
    };
  }

  String _readFile(String path) {
    try {
      return File(path).readAsStringSync().trim();
    } catch (_) {
      return 'unknown';
    }
  }

  String _readFirstLine(String path) {
    try {
      final lines = File(path).readAsLinesSync();
      return lines.isNotEmpty ? lines.first : 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  String _getOS() {
    final osRelease = _readFile('/etc/os-release');
    var match = RegExp(r'PRETTY_NAME="(.+)"').firstMatch(osRelease);
    if (match != null) return match.group(1)!;
    match = RegExp(r'PRETTY_NAME=(.+)').firstMatch(osRelease);
    if (match != null) return match.group(1)!;
    final issue = _readFirstLine('/etc/issue')
        .replaceAll(RegExp(r'\\[nrl]'), '')
        .trim();
    if (issue.isNotEmpty && issue != 'unknown') return issue;
    return 'Linux (unknown)';
  }

  String _getHostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return _readFirstLine('/proc/sys/kernel/hostname');
    }
  }

  String _getKernel() {
    final version = _readFirstLine('/proc/version');
    final parts = version.split(' ');
    if (parts.length >= 3) {
      return '${parts[0]} ${parts[2]} ${Platform.localHostname}';
    }
    return version;
  }

  String _getUptime() {
    final content = _readFirstLine('/proc/uptime');
    final seconds = double.tryParse(content.split(' ').first) ?? 0;
    final total = seconds.toInt();
    final days = total ~/ 86400;
    final hours = (total % 86400) ~/ 3600;
    final mins = (total % 3600) ~/ 60;
    final buf = StringBuffer();
    if (days > 0) buf.write('$days days, ');
    buf.write('$hours hours, $mins mins');
    return buf.toString();
  }

  String _getCPU() {
    final content = _readFile('/proc/cpuinfo');
    var modelName = 'Unknown CPU';
    var cores = 0;
    var mhz = 0.0;

    for (final line in content.split('\n')) {
      if (line.startsWith('model name') && modelName == 'Unknown CPU') {
        modelName = line.split(':').last.trim();
      }
      if (line.startsWith('cpu MHz')) {
        mhz = double.tryParse(line.split(':').last.trim()) ?? 0;
      }
      if (line.startsWith('processor')) {
        cores++;
      }
    }

    var result = '$modelName ($cores)';
    if (mhz > 0) result += ' @ ${(mhz / 1000).toStringAsFixed(2)} GHz';
    return result;
  }

  String _getMemory() {
    final content = _readFile('/proc/meminfo');
    var memTotal = 0;
    var memAvail = 0;

    for (final line in content.split('\n')) {
      if (line.startsWith('MemTotal:')) {
        memTotal = int.tryParse(
                line.split(':').last.trim().split(' ').first) ??
            0;
      }
      if (line.startsWith('MemAvailable:')) {
        memAvail = int.tryParse(
                line.split(':').last.trim().split(' ').first) ??
            0;
      }
    }

    if (memTotal == 0) return 'unknown';
    final totalGiB = memTotal / (1024.0 * 1024.0);
    final usedGiB = (memTotal - memAvail) / (1024.0 * 1024.0);
    final pct = ((1 - memAvail / memTotal) * 100).round();
    return '${usedGiB.toStringAsFixed(2)} GiB / ${totalGiB.toStringAsFixed(2)} GiB ($pct%)';
  }

  String _getDisk(String mount) {
    try {
      final stat = FileStat.statSync(mount);
      final total = stat.size;
      final free = stat.size - stat.size; // not possible via dart:io
      // Use process to get df
      final result = Process.runSync('df', ['-B1', '--output=size,used,avail', mount]);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().trim().split('\n');
        if (lines.length >= 2) {
          final parts = lines[1].trim().split(RegExp(r'\s+'));
          if (parts.length >= 3) {
            final totalBytes = int.tryParse(parts[0]) ?? 0;
            final usedBytes = int.tryParse(parts[1]) ?? 0;
            final totalGiB = totalBytes / (1024.0 * 1024.0 * 1024.0);
            final usedGiB = usedBytes / (1024.0 * 1024.0 * 1024.0);
            final pct = totalBytes > 0
                ? ((usedBytes / totalBytes) * 100).round()
                : 0;
            return '$mount: ${usedGiB.toStringAsFixed(2)} GiB / ${totalGiB.toStringAsFixed(2)} GiB ($pct%)';
          }
        }
      }
    } catch (_) {}
    return '$mount: unknown';
  }

  String _getLocalIP() {
    try {
      final result = Process.runSync('hostname', ['-I']);
      if (result.exitCode == 0) {
        final ips = result.stdout.toString().trim().split(' ');
        if (ips.isNotEmpty && ips[0].isNotEmpty) return ips[0];
      }
    } catch (_) {}
    return 'unknown';
  }

  String _getLocale() {
    try {
      return Platform.localeName;
    } catch (_) {
      return 'unknown';
    }
  }
}

// ── Android (Kotlin MethodChannel) ───────────────────────────────────────────

class _AndroidSystemInfo implements SystemInfoService {
  static const _channel = MethodChannel('flutter_showcase/system_info');

  @override
  Future<Map<String, String>> getInfo() async {
    final result = await _channel.invokeMapMethod<String, String>('getInfo');
    return result ?? {};
  }
}
