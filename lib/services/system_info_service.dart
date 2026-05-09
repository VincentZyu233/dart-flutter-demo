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
  Future<Map<String, String>> getInfo({bool forceRefresh = false});
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
  static Map<String, String>? _cachedInfo;

  @override
  Future<Map<String, String>> getInfo({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedInfo != null) {
      return Map<String, String>.from(_cachedInfo!);
    }
    try {
      final result = await _channel.invokeMapMethod<String, String>('getInfo');
      if (result != null) {
        _cachedInfo = Map<String, String>.from(result);
        return Map<String, String>.from(result);
      }
    } catch (_) {}
    final fallback = _getInfoFallback();
    _cachedInfo = Map<String, String>.from(fallback);
    return fallback;
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
  static Map<String, String>? _cachedInfo;
  static Future<Map<String, String>>? _inFlight;

  @override
  Future<Map<String, String>> getInfo({bool forceRefresh = false}) {
    if (!forceRefresh && _cachedInfo != null) {
      return Future.value(Map<String, String>.from(_cachedInfo!));
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    late final Future<Map<String, String>> future;
    future = Future<Map<String, String>>(_getInfoSync).then((result) {
      _cachedInfo = Map<String, String>.from(result);
      return Map<String, String>.from(result);
    });

    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  static Map<String, String> _getInfoSync() {
    try {
      final dylib = DynamicLibrary.process();
      final getJson = dylib.lookupFunction<_GetSystemInfoJsonNative, _GetSystemInfoJsonDart>('GetSystemInfoJson');
      final freeJson = dylib.lookupFunction<_FreeSystemInfoJsonNative, _FreeSystemInfoJsonDart>('FreeSystemInfoJson');

      final ptr = getJson();
      final jsonStr = _ptrToString(ptr);
      freeJson(ptr);

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = decoded.map((k, v) => MapEntry(k, v.toString()));
      result['Locale'] = _normalizeWindowsLocale(result['Locale']);
      return result;
    } catch (_) {
      return _getInfoFallback();
    }
  }

  static Map<String, String> _getInfoFallback() {
    final result = <String, String>{};
    result['OS'] = Platform.operatingSystemVersion;
    result['Host'] = Platform.localHostname;
    result['Kernel'] = 'Windows ${Platform.operatingSystemVersion}';

    // Prefer the standalone .ps1 file (maintained at plugins/windows/SystemInfo.ps1).
    // Falls back to inline script if the file is not found (e.g. production build).
    List<String>? psOutput;
    try {
      final ps1 = File(r'plugins\windows\SystemInfo.ps1');
      if (ps1.existsSync()) {
        psOutput = Process.runSync(
          'powershell', ['-NoProfile', '-File', ps1.absolute.path],
          runInShell: true,
        ).stdout.toString().split('\n');
      }
    } catch (_) {}

    psOutput ??= _runInlinePowerShell();

    for (final line in psOutput!) {
      final l = line.trim();
      if (l.startsWith('UPTIME|')) {
        final raw = l.substring(7);
        final dt = DateTime.tryParse(raw);
        if (dt != null) {
          result['Uptime'] = _formatDuration(DateTime.now().toUtc().difference(dt));
        } else {
          result['Uptime'] = raw;
        }
      } else if (l.startsWith('CPU|')) {
        result['CPU'] = l.substring(4).trim();
      } else if (l.startsWith('MEM|')) {
        result['Memory'] = l.substring(4).trim();
      } else if (l.startsWith('DISK|')) {
        result['Disk (C:\\)'] = l.substring(5).trim();
      } else if (l.startsWith('NET|')) {
        result['Local IP'] = l.substring(4).trim();
      }
    }

    result.putIfAbsent('Uptime', () => 'unknown');
    result.putIfAbsent('CPU', () => '${Platform.numberOfProcessors} cores');
    result.putIfAbsent('Memory', () => 'unknown');
    result.putIfAbsent('Disk (C:\\)', () => 'unknown');
    result.putIfAbsent('Local IP', () => 'unknown');
    result['Locale'] = _normalizeWindowsLocale(Platform.localeName);
    return result;
  }

  static List<String> _runInlinePowerShell() {
    final script = [
      '-NoProfile', '-Command',
      r'''
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$net = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
Write-Output "UPTIME|$($os.LastBootUpTime)"
Write-Output "CPU|$($cpu.Name) ($($cpu.NumberOfLogicalProcessors) cores)"
Write-Output "MEM|$([math]::Round($cs.TotalPhysicalMemory/1GB,1)) GiB total"
Write-Output "DISK|$([math]::Round($disk.Size/1GB,1)) GiB total $([math]::Round(($disk.Size-$disk.FreeSpace)/1GB,1)) GiB used"
Write-Output "NET|$($net.Name)"
'''
    ];
    return Process.runSync('powershell', script, runInShell: true).stdout.toString().split('\n');
  }

  static String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final buf = StringBuffer();
    if (days > 0) buf.write('$days days, ');
    buf.write('$hours hours, $mins mins');
    return buf.toString();
  }
  static String _normalizeWindowsLocale(String? locale) {
    final trimmed = locale?.trim() ?? '';
    if (trimmed.isNotEmpty &&
        trimmed.toLowerCase() != 'und' &&
        trimmed.toLowerCase() != 'unknown') {
      return trimmed;
    }
    return trimmed.isNotEmpty ? trimmed : 'unknown';
  }
}

// ── Linux (dart:io) ──────────────────────────────────────────────────────────

class _LinuxSystemInfo implements SystemInfoService {
  static Map<String, String>? _cachedInfo;
  static Future<Map<String, String>>? _inFlight;

  @override
  Future<Map<String, String>> getInfo({bool forceRefresh = false}) {
    if (!forceRefresh && _cachedInfo != null) {
      return Future.value(Map<String, String>.from(_cachedInfo!));
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    late final Future<Map<String, String>> future;
    future = Future<Map<String, String>>(_getInfoSync).then((result) {
      _cachedInfo = Map<String, String>.from(result);
      return Map<String, String>.from(result);
    });

    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
    return future;
  }

  static Map<String, String> _getInfoSync() {
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

  static String _readFile(String path) {
    try {
      return File(path).readAsStringSync().trim();
    } catch (_) {
      return 'unknown';
    }
  }

  static String _readFirstLine(String path) {
    try {
      final lines = File(path).readAsLinesSync();
      return lines.isNotEmpty ? lines.first : 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  static String _getOS() {
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

  static String _getHostname() {
    try {
      return Platform.localHostname;
    } catch (_) {
      return _readFirstLine('/proc/sys/kernel/hostname');
    }
  }

  static String _getKernel() {
    final version = _readFirstLine('/proc/version');
    final parts = version.split(' ');
    if (parts.length >= 3) {
      return '${parts[0]} ${parts[2]} ${Platform.localHostname}';
    }
    return version;
  }

  static String _getUptime() {
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

  static String _getCPU() {
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

  static String _getMemory() {
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

  static String _getDisk(String mount) {
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

  static String _getLocalIP() {
    try {
      final result = Process.runSync('hostname', ['-I']);
      if (result.exitCode == 0) {
        final ips = result.stdout.toString().trim().split(' ');
        if (ips.isNotEmpty && ips[0].isNotEmpty) return ips[0];
      }
    } catch (_) {}
    return 'unknown';
  }

  static String _getLocale() {
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
  static Map<String, String>? _cachedInfo;

  @override
  Future<Map<String, String>> getInfo({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedInfo != null) {
      return Map<String, String>.from(_cachedInfo!);
    }
    final result = await _channel.invokeMapMethod<String, String>('getInfo');
    final info = result ?? {};
    _cachedInfo = Map<String, String>.from(info);
    return Map<String, String>.from(info);
  }
}
