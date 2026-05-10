import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';

typedef _GetSystemInfoJsonNative = Pointer<Uint8> Function();
typedef _GetSystemInfoJsonDart = Pointer<Uint8> Function();
typedef _FreeSystemInfoJsonNative = Void Function(Pointer<Uint8>);
typedef _FreeSystemInfoJsonDart = void Function(Pointer<Uint8>);

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
  Future<Map<String, String>> getInfo({
    bool forceRefresh = false,
    void Function(String key, String value)? onField,
  });
}

class SystemInfoDebugSnapshot {
  final String platform;
  final String source;
  final List<String> logs;
  final Map<String, String> data;

  const SystemInfoDebugSnapshot({
    required this.platform,
    required this.source,
    required this.logs,
    required this.data,
  });

  String toMultilineText() {
    final buffer = StringBuffer()
      ..writeln('platform: $platform')
      ..writeln('source: $source')
      ..writeln('')
      ..writeln('[data]');

    final sortedEntries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in sortedEntries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }

    buffer
      ..writeln('')
      ..writeln('[logs]');
    for (final line in logs) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }
}

SystemInfoService createSystemInfoService() {
  if (Platform.isWindows) return _WindowsSystemInfo();
  if (Platform.isLinux) return _LinuxSystemInfo();
  if (Platform.isAndroid) return _AndroidSystemInfo();
  if (Platform.isIOS) return _IOSSystemInfo();
  if (Platform.isMacOS) return _MacOSSystemInfo();
  throw UnsupportedError('Platform not supported');
}

SystemInfoDebugSnapshot getSystemInfoDebugSnapshot() {
  if (Platform.isWindows) return _WindowsSystemInfo.debugSnapshot;
  if (Platform.isLinux) return _LinuxSystemInfo.debugSnapshot;
  if (Platform.isAndroid) return _AndroidSystemInfo.debugSnapshot;
  if (Platform.isIOS) return _IOSSystemInfo.debugSnapshot;
  if (Platform.isMacOS) return _MacOSSystemInfo.debugSnapshot;
  return SystemInfoDebugSnapshot(
    platform: Platform.operatingSystem,
    source: 'unsupported',
    logs: const ['Debug snapshot unavailable on this platform.'],
    data: const {},
  );
}

Future<File> exportSystemInfoDebugSnapshot() async {
  final snapshot = getSystemInfoDebugSnapshot();
  final now = DateTime.now();
  final filename =
      'dart_flutter_demo_system_info_${_timestampForFile(now)}.log';
  final directory = await _resolveLogExportDirectory();
  await directory.create(recursive: true);
  final file = File('${directory.path}${Platform.pathSeparator}$filename');
  await file.writeAsString(snapshot.toMultilineText());
  return file;
}

Future<int> copySystemInfoDebugSnapshotToClipboard({
  int maxChars = 240000,
}) async {
  final snapshot = getSystemInfoDebugSnapshot();
  final text = snapshot.toMultilineText();
  final clipped = _clipFromLatest(text, maxChars: maxChars);
  await Clipboard.setData(ClipboardData(text: clipped));
  return clipped.length;
}

String _timestampForFile(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}${two(value.month)}${two(value.day)}_'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}';
}

Future<Directory> _resolveLogExportDirectory() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return Directory.current;
  }

  final temp = Directory.systemTemp;
  return Directory(
    '${temp.path}${Platform.pathSeparator}dart_flutter_demo_logs',
  );
}

String _clipFromLatest(String value, {required int maxChars}) {
  if (value.length <= maxChars) return value;
  return value.substring(value.length - maxChars);
}

class _DebugLogBuffer {
  final List<String> _lines = [];

  void add(String message) {
    _lines.add('[${DateTime.now().toIso8601String()}] $message');
  }

  List<String> snapshot() => List<String>.from(_lines);
}

class _ProcessTrace {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _ProcessTrace({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

class _WindowsFallbackState {
  final _DebugLogBuffer debug;
  final Map<String, String> result;
  final void Function(String key, String value)? onField;

  _WindowsFallbackState(this.debug, this.result, {this.onField});

  void putIfMissing(String key, String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final current = result[key]?.trim() ?? '';
    if (current.isEmpty || current == 'unknown' || current == 'unavailable') {
      result[key] = trimmed;
      onField?.call(key, trimmed);
      debug.add('Filled `$key` from fallback source.');
    }
  }

  void overwrite(String key, String? value, String reason) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return;
    result[key] = trimmed;
    onField?.call(key, trimmed);
    debug.add('Overwrote `$key`: $reason');
  }
}

// ── iOS ──────────────────────────────────────────────────────────────────────

class _IOSSystemInfo implements SystemInfoService {
  static const _channel = MethodChannel('dart_flutter_demo/system_info');
  static Map<String, String>? _cachedInfo;
  static SystemInfoDebugSnapshot _debugSnapshot = const SystemInfoDebugSnapshot(
    platform: 'ios',
    source: 'idle',
    logs: <String>[],
    data: <String, String>{},
  );

  static SystemInfoDebugSnapshot get debugSnapshot => _debugSnapshot;

  @override
  Future<Map<String, String>> getInfo({
    bool forceRefresh = false,
    void Function(String key, String value)? onField,
  }) async {
    if (!forceRefresh && _cachedInfo != null) {
      for (final entry in _cachedInfo!.entries) {
        onField?.call(entry.key, entry.value);
      }
      return Map<String, String>.from(_cachedInfo!);
    }
    try {
      final result = await _channel.invokeMapMethod<String, String>('getInfo');
      if (result != null) {
        _cachedInfo = Map<String, String>.from(result);
        for (final entry in result.entries) {
          onField?.call(entry.key, entry.value);
        }
        _debugSnapshot = SystemInfoDebugSnapshot(
          platform: 'ios',
          source: 'method-channel',
          logs: const ['Loaded via iOS method channel.'],
          data: Map<String, String>.from(result),
        );
        return Map<String, String>.from(result);
      }
    } catch (e) {
      _debugSnapshot = SystemInfoDebugSnapshot(
        platform: 'ios',
        source: 'fallback',
        logs: ['MethodChannel failed: $e'],
        data: const {},
      );
    }
    final fallback = _getInfoFallback();
    _cachedInfo = Map<String, String>.from(fallback);
    return fallback;
  }

  Map<String, String> _getInfoFallback() {
    final result = <String, String>{};
    result['OS'] = Platform.operatingSystemVersion;
    result['Host'] = Platform.localHostname;
    result['Kernel'] = 'Darwin ${Platform.operatingSystemVersion}';
    result['Uptime'] = 'unavailable';
    result['CPU'] = '${Platform.numberOfProcessors} cores';
    result['Memory'] = 'unavailable';
    result['Disk'] = 'unavailable';
    result['Local IP'] = 'unavailable';
    result['Locale'] = Platform.localeName;
    _debugSnapshot = SystemInfoDebugSnapshot(
      platform: 'ios',
      source: 'fallback',
      logs: const ['Using basic dart:io fallback on iOS.'],
      data: Map<String, String>.from(result),
    );
    return result;
  }
}

// ── macOS ────────────────────────────────────────────────────────────────────

class _MacOSSystemInfo implements SystemInfoService {
  static const _channel = MethodChannel('dart_flutter_demo/system_info');
  static Map<String, String>? _cachedInfo;
  static SystemInfoDebugSnapshot _debugSnapshot = const SystemInfoDebugSnapshot(
    platform: 'macos',
    source: 'idle',
    logs: <String>[],
    data: <String, String>{},
  );

  static SystemInfoDebugSnapshot get debugSnapshot => _debugSnapshot;

  @override
  Future<Map<String, String>> getInfo({
    bool forceRefresh = false,
    void Function(String key, String value)? onField,
  }) async {
    if (!forceRefresh && _cachedInfo != null) {
      for (final entry in _cachedInfo!.entries) {
        onField?.call(entry.key, entry.value);
      }
      return Map<String, String>.from(_cachedInfo!);
    }
    try {
      final result = await _channel.invokeMapMethod<String, String>('getInfo');
      if (result != null) {
        _cachedInfo = Map<String, String>.from(result);
        for (final entry in result.entries) {
          onField?.call(entry.key, entry.value);
        }
        _debugSnapshot = SystemInfoDebugSnapshot(
          platform: 'macos',
          source: 'method-channel',
          logs: const ['Loaded via macOS method channel.'],
          data: Map<String, String>.from(result),
        );
        return Map<String, String>.from(result);
      }
    } catch (e) {
      _debugSnapshot = SystemInfoDebugSnapshot(
        platform: 'macos',
        source: 'fallback',
        logs: ['MethodChannel failed: $e'],
        data: const {},
      );
    }

    final fallback = _getInfoFallback();
    _cachedInfo = Map<String, String>.from(fallback);
    return fallback;
  }

  Map<String, String> _getInfoFallback() {
    final result = <String, String>{};
    result['OS'] = Platform.operatingSystemVersion;
    result['Host'] = Platform.localHostname;
    result['Kernel'] = 'Darwin ${Platform.operatingSystemVersion}';
    result['Uptime'] = 'unavailable';
    result['CPU'] = '${Platform.numberOfProcessors} cores';
    result['Memory'] = 'unavailable';
    result['Disk'] = 'unavailable';
    result['Local IP'] = 'unavailable';
    result['Locale'] = Platform.localeName;
    _debugSnapshot = SystemInfoDebugSnapshot(
      platform: 'macos',
      source: 'fallback',
      logs: const ['Using basic dart:io fallback on macOS.'],
      data: Map<String, String>.from(result),
    );
    return result;
  }
}

// ── Windows ──────────────────────────────────────────────────────────────────

class _WindowsSystemInfo implements SystemInfoService {
  static Map<String, String>? _cachedInfo;
  static Future<Map<String, String>>? _inFlight;
  static SystemInfoDebugSnapshot _debugSnapshot = const SystemInfoDebugSnapshot(
    platform: 'windows',
    source: 'idle',
    logs: <String>[],
    data: <String, String>{},
  );

  static SystemInfoDebugSnapshot get debugSnapshot => _debugSnapshot;

  @override
  Future<Map<String, String>> getInfo({
    bool forceRefresh = false,
    void Function(String key, String value)? onField,
  }) {
    if (!forceRefresh && _cachedInfo != null) {
      for (final entry in _cachedInfo!.entries) {
        onField?.call(entry.key, entry.value);
      }
      return Future.value(Map<String, String>.from(_cachedInfo!));
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    late final Future<Map<String, String>> future;
    future = Future<Map<String, String>>(() async {
      final result = await _getInfoAsync(onField: onField);
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

  static Future<Map<String, String>> _getInfoAsync({
    void Function(String key, String value)? onField,
  }) async {
    final debug = _DebugLogBuffer();
    debug.add('Windows system info request started.');

    try {
      debug.add('Trying FFI via DynamicLibrary.process().');
      final dylib = DynamicLibrary.process();
      final getJson = dylib.lookupFunction<_GetSystemInfoJsonNative, _GetSystemInfoJsonDart>(
        'GetSystemInfoJson',
      );
      final freeJson = dylib.lookupFunction<_FreeSystemInfoJsonNative, _FreeSystemInfoJsonDart>(
        'FreeSystemInfoJson',
      );

      final ptr = getJson();
      final jsonStr = _ptrToString(ptr);
      freeJson(ptr);
      debug.add('FFI JSON length=${jsonStr.length}.');

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final result = decoded.map((k, v) => MapEntry(k, v.toString()));
      result['Locale'] = _normalizeWindowsLocale(result['Locale']);
      for (final entry in result.entries) {
        onField?.call(entry.key, entry.value);
      }
      _recordWindowsDebug(
        source: 'ffi',
        logs: debug.snapshot(),
        data: result,
      );
      return result;
    } catch (e) {
      debug.add('FFI failed: $e');
    }

    final result = <String, String>{
      'OS': Platform.operatingSystemVersion,
      'Host': Platform.localHostname,
      'Kernel': 'Windows ${Platform.operatingSystemVersion}',
      'Uptime': 'unavailable',
      'CPU': 'unavailable',
      'Memory': 'unavailable',
      'Disk (C:\\)': 'unavailable',
      'Local IP': 'unavailable',
      'Locale': _normalizeWindowsLocale(Platform.localeName),
    };

    final state = _WindowsFallbackState(debug, result, onField: onField);
    for (final entry in result.entries) {
      onField?.call(entry.key, entry.value);
    }
    debug.add('Entering fallback chain.');
    await _tryNativeCommands(state);
    /*
    Historical slow-path fallbacks kept for reference:
    Uncomment only if the faster native chain stops working on some build.
    await _tryStandalonePs1(state);
    await _tryInlinePowerShell(state);
    */

    _recordWindowsDebug(
      source: 'fallback',
      logs: debug.snapshot(),
      data: result,
    );
    return result;
  }

  static void _recordWindowsDebug({
    required String source,
    required List<String> logs,
    required Map<String, String> data,
  }) {
    _debugSnapshot = SystemInfoDebugSnapshot(
      platform: 'windows',
      source: source,
      logs: logs,
      data: Map<String, String>.from(data),
    );
  }

  static Future<void> _tryStandalonePs1(_WindowsFallbackState state) async {
    // Historical fallback path:
    // keep this around for reference, but prefer the faster native chain first.
    final ps1 = File(r'plugins\windows\SystemInfo.ps1');
    state.debug.add('Checking PS1 path: ${ps1.absolute.path}');
    if (!ps1.existsSync()) {
      state.debug.add('Standalone PS1 file not found.');
      return;
    }

    final trace = await _runProcess(
      state.debug,
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1.absolute.path],
      label: 'PS1 file',
    );
    _ingestTaggedOutput(state, trace.stdout, source: 'ps1');
  }

  static Future<void> _tryInlinePowerShell(_WindowsFallbackState state) async {
    // Historical fallback path:
    // inline PowerShell worked, but it is comparatively expensive.
    final script = r'''
$os = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$ip = Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp,Manual |
  Where-Object {
    $_.IPAddress -notlike '127.*' -and
    $_.IPAddress -notlike '169.254.*' -and
    $_.InterfaceAlias -notmatch 'Radmin|VPN|VMware|vEthernet|Hyper-V|WSL|Virtual|Todesk|Parsec|GameViewer'
  } |
  Sort-Object {
    if ($_.AddressState -eq 'Preferred') { 0 } else { 1 }
  }, {
    if ($_.PrefixOrigin -eq 'Dhcp') { 0 } else { 1 }
  } |
  Select-Object -First 1
Write-Output "UPTIME|$($os.LastBootUpTime)"
Write-Output "CPU|$($cpu.Name) ($($cpu.NumberOfLogicalProcessors) cores)"
Write-Output "MEM|$([math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024) / 1024, 2)) GiB / $([math]::Round(($os.TotalVisibleMemorySize / 1024) / 1024, 2)) GiB"
Write-Output "DISK|$([math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)) GiB / $([math]::Round($disk.Size / 1GB, 2)) GiB"
Write-Output "NET|$($ip.IPAddress)"
''';
    final trace = await _runProcess(
      state.debug,
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      label: 'Inline PowerShell',
    );
    _ingestTaggedOutput(state, trace.stdout, source: 'inline-powershell');
  }

  static Future<void> _tryNativeCommands(_WindowsFallbackState state) async {
    state.debug.add('Trying native command fallbacks.');

    final uptime = await _runProcess(
      state.debug,
      'cmd',
      ['/c', 'net stats workstation'],
      label: 'net stats workstation',
    );
    state.putIfMissing('Uptime', _extractNetStatsUptime(uptime.stdout));

    final cpuName = await _runProcess(
      state.debug,
      'reg',
      ['query', r'HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0', '/v', 'ProcessorNameString'],
      label: 'reg cpu name',
    );
    final cpuSpeed = await _runProcess(
      state.debug,
      'reg',
      ['query', r'HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0', '/v', '~MHz'],
      label: 'reg cpu speed',
    );
    final cpuValue = _mergeCpuFallback(cpuName.stdout, cpuSpeed.stdout);
    state.putIfMissing('CPU', cpuValue);

    /*
    Historical fallback path:
    WMIC is slower and deprecated on newer Windows builds, so keep the old
    parsing code here as a reference but avoid running it in the hot path.
    final memory = await _runProcess(
      state.debug,
      'wmic',
      ['OS', 'get', 'FreePhysicalMemory,TotalVisibleMemorySize', '/Value'],
      label: 'wmic memory',
    );
    state.putIfMissing('Memory', _extractWmicMemory(memory.stdout));

    final disk = await _runProcess(
      state.debug,
      'wmic',
      ['logicaldisk', 'where', "DeviceID='C:'", 'get', 'FreeSpace,Size', '/Value'],
      label: 'wmic disk',
    );
    state.putIfMissing('Disk (C:\\)', _extractWmicDisk(disk.stdout));
    */

    final ip = await _runProcess(
      state.debug,
      'ipconfig',
      [],
      label: 'ipconfig',
    );
    final preferredIp = _extractPreferredIpconfigIPv4(ip.stdout);
    if (preferredIp != null) {
      state.overwrite('Local IP', preferredIp, 'preferred ipconfig adapter');
    }
  }

  static void _ingestTaggedOutput(
    _WindowsFallbackState state,
    String stdout, {
    required String source,
  }) {
    final lines = stdout.split(RegExp(r'\r?\n'));
    var matchedAny = false;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('UPTIME|')) {
        matchedAny = true;
        final raw = line.substring(7).trim();
        final dt = _parseWindowsBootTimestamp(raw);
        state.putIfMissing(
          'Uptime',
          dt != null
              ? _formatDuration(DateTime.now().difference(dt))
              : raw,
        );
      } else if (line.startsWith('CPU|')) {
        matchedAny = true;
        state.putIfMissing('CPU', line.substring(4).trim());
      } else if (line.startsWith('MEM|')) {
        matchedAny = true;
        state.putIfMissing('Memory', line.substring(4).trim());
      } else if (line.startsWith('DISK|')) {
        matchedAny = true;
        state.putIfMissing('Disk (C:\\)', line.substring(5).trim());
      } else if (line.startsWith('NET|')) {
        matchedAny = true;
        final ip = _normalizeIpCandidate(line.substring(4).trim());
        if (ip != null) {
          state.putIfMissing('Local IP', ip);
        }
      }
    }

    if (matchedAny) {
      state.debug.add('Parsed tagged output from $source.');
    } else {
      state.debug.add('No tagged output parsed from $source.');
    }
  }

  static Future<_ProcessTrace> _runProcess(
    _DebugLogBuffer debug,
    String executable,
    List<String> arguments, {
    required String label,
  }) async {
    try {
      final result = await Process.run(executable, arguments, runInShell: true);
      final stdout = result.stdout.toString();
      final stderr = result.stderr.toString();
      debug.add('$label exitCode=${result.exitCode}');
      if (stdout.trim().isEmpty) {
        debug.add('$label stdout is empty.');
      } else {
        debug.add('$label stdout:\n${_clipDebugText(stdout)}');
      }
      if (stderr.trim().isNotEmpty) {
        debug.add('$label stderr:\n${_clipDebugText(stderr)}');
      }
      return _ProcessTrace(
        exitCode: result.exitCode,
        stdout: stdout,
        stderr: stderr,
      );
    } catch (e) {
      debug.add('$label failed: $e');
      return const _ProcessTrace(exitCode: -1, stdout: '', stderr: '');
    }
  }

  static String? _extractNetStatsUptime(String stdout) {
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Statistics since')) {
        final raw = trimmed.substring('Statistics since'.length).trim();
        if (raw.isEmpty) return null;
        final boot = _parseWindowsBootTimestamp(raw);
        return boot != null
            ? _formatDuration(DateTime.now().difference(boot))
            : raw;
      }
    }
    return null;
  }

  static String? _mergeCpuFallback(String cpuNameOutput, String cpuSpeedOutput) {
    final name = _extractRegValue(cpuNameOutput);
    final mhz = _extractRegValue(cpuSpeedOutput);
    if ((name ?? '').isEmpty) return null;

    final cores = Platform.numberOfProcessors;
    final buffer = StringBuffer()..write(name!.trim())..write(' ($cores)');
    final parsedMhz = int.tryParse((mhz ?? '').trim());
    if (parsedMhz != null && parsedMhz > 0) {
      final ghz = (parsedMhz / 1000.0).toStringAsFixed(2);
      buffer.write(' @ $ghz GHz');
    }
    return buffer.toString();
  }

  static String? _extractRegValue(String stdout) {
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('REG_')) {
        final match = RegExp(r'REG_\w+\s+(.*)$').firstMatch(trimmed);
        if (match != null) return match.group(1)?.trim();
      }
    }
    return null;
  }

  static String? _extractWmicMemory(String stdout) {
    final values = _parseKeyValueLines(stdout);
    final freeKiB = int.tryParse(values['FreePhysicalMemory'] ?? '');
    final totalKiB = int.tryParse(values['TotalVisibleMemorySize'] ?? '');
    if (freeKiB == null || totalKiB == null || totalKiB <= 0) return null;
    final usedKiB = totalKiB - freeKiB;
    final usedGiB = usedKiB / (1024.0 * 1024.0);
    final totalGiB = totalKiB / (1024.0 * 1024.0);
    final pct = ((usedKiB / totalKiB) * 100).round();
    return '${usedGiB.toStringAsFixed(2)} GiB / ${totalGiB.toStringAsFixed(2)} GiB ($pct%)';
  }

  static String? _extractWmicDisk(String stdout) {
    final values = _parseKeyValueLines(stdout);
    final freeBytes = int.tryParse(values['FreeSpace'] ?? '');
    final totalBytes = int.tryParse(values['Size'] ?? '');
    if (freeBytes == null || totalBytes == null || totalBytes <= 0) return null;
    final usedBytes = totalBytes - freeBytes;
    final usedGiB = usedBytes / (1024.0 * 1024.0 * 1024.0);
    final totalGiB = totalBytes / (1024.0 * 1024.0 * 1024.0);
    final pct = ((usedBytes / totalBytes) * 100).round();
    return '${usedGiB.toStringAsFixed(2)} GiB / ${totalGiB.toStringAsFixed(2)} GiB ($pct%)';
  }

  static Map<String, String> _parseKeyValueLines(String stdout) {
    final result = <String, String>{};
    for (final line in stdout.split(RegExp(r'\r?\n'))) {
      final index = line.indexOf('=');
      if (index <= 0) continue;
      final key = line.substring(0, index).trim();
      final value = line.substring(index + 1).trim();
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }
    return result;
  }

  static String? _extractIpconfigIPv4(String stdout) {
    final adapters = _parseIpconfigAdapters(stdout);
    for (final adapter in adapters) {
      final ip = _normalizeIpCandidate(adapter.ipv4);
      if (ip != null) return ip;
    }
    return null;
  }

  static String? _extractPreferredIpconfigIPv4(String stdout) {
    final adapters = _parseIpconfigAdapters(stdout);
    _IpconfigAdapter? best;
    int? bestScore;

    for (final adapter in adapters) {
      final ip = _normalizeIpCandidate(adapter.ipv4);
      if (ip == null) continue;

      var score = 1000;
      if (adapter.hasDefaultGateway) score -= 200;
      if (!_looksVirtualOrVpn(adapter.name)) score -= 120;
      if (adapter.name.toLowerCase().contains('ethernet')) {
        score -= 20;
      }

      if (best == null || score < bestScore!) {
        best = adapter;
        bestScore = score;
      }
    }

    return best?.ipv4;
  }

  static List<_IpconfigAdapter> _parseIpconfigAdapters(String stdout) {
    final lines = stdout.split(RegExp(r'\r?\n'));
    final adapters = <_IpconfigAdapter>[];
    _IpconfigAdapter? current;

    for (final rawLine in lines) {
      final trimmed = rawLine.trimRight();
      final headerMatch =
          RegExp(r'^[A-Za-z].* adapter (.+):$').firstMatch(trimmed.trim());
      if (headerMatch != null) {
        current = _IpconfigAdapter(name: headerMatch.group(1)!.trim());
        adapters.add(current);
        continue;
      }

      if (current == null) continue;

      final ipv4Match =
          RegExp(r'IPv4 Address[^\:]*:\s*([0-9.]+)').firstMatch(trimmed);
      if (ipv4Match != null) {
        current.ipv4 = ipv4Match.group(1)!.trim();
      }

      final gatewayMatch =
          RegExp(r'Default Gateway[^\:]*:\s*(.+)$').firstMatch(trimmed);
      if (gatewayMatch != null) {
        final gateway = gatewayMatch.group(1)!.trim();
        current.hasDefaultGateway = gateway.isNotEmpty;
      }
    }

    return adapters;
  }

  static String? _normalizeIpCandidate(String? value) {
    final ip = value?.trim() ?? '';
    if (ip.isEmpty) return null;
    if (!RegExp(r'^(\d{1,3})(?:\.(\d{1,3})){3}$').hasMatch(ip)) return null;
    if (ip.startsWith('127.') || ip.startsWith('169.254.')) return null;
    return ip;
  }

  static bool _looksVirtualOrVpn(String name) {
    final lower = name.toLowerCase();
    const keywords = [
      'radmin',
      'vpn',
      'vmware',
      'vethernet',
      'hyper-v',
      'wsl',
      'virtual',
      'todesk',
      'parsec',
      'gameviewer',
    ];
    return keywords.any(lower.contains);
  }

  static bool _isPrivate172(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    if (parts[0] != '172') return false;
    final second = int.tryParse(parts[1]) ?? -1;
    return second >= 16 && second <= 31;
  }

  static String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final secs = d.inSeconds % 60;
    final buf = StringBuffer();
    if (days > 0) buf.write('$days days, ');
    buf.write('$hours hours, $mins mins');
    buf.write(', $secs secs');
    return buf.toString();
  }

  static DateTime? _parseWindowsBootTimestamp(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final slashMatch = RegExp(
      r'^(\d{1,2})/(\d{1,2})/(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})$',
    ).firstMatch(trimmed);
    if (slashMatch != null) {
      final month = int.tryParse(slashMatch.group(1)!);
      final day = int.tryParse(slashMatch.group(2)!);
      final year = int.tryParse(slashMatch.group(3)!);
      final hour = int.tryParse(slashMatch.group(4)!);
      final minute = int.tryParse(slashMatch.group(5)!);
      final second = int.tryParse(slashMatch.group(6)!);
      if (month != null &&
          day != null &&
          year != null &&
          hour != null &&
          minute != null &&
          second != null) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

    return DateTime.tryParse(trimmed);
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

  static String _clipDebugText(String value, {int maxChars = 2000}) {
    final normalized = value.replaceAll('\r\n', '\n').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}\n...<truncated>';
  }
}

class _IpconfigAdapter {
  final String name;
  String? ipv4;
  bool hasDefaultGateway = false;

  _IpconfigAdapter({
    required this.name,
  });
}

// ── Linux ────────────────────────────────────────────────────────────────────

class _LinuxSystemInfo implements SystemInfoService {
  static Map<String, String>? _cachedInfo;
  static Future<Map<String, String>>? _inFlight;
  static SystemInfoDebugSnapshot _debugSnapshot = const SystemInfoDebugSnapshot(
    platform: 'linux',
    source: 'idle',
    logs: <String>[],
    data: <String, String>{},
  );

  static SystemInfoDebugSnapshot get debugSnapshot => _debugSnapshot;

  @override
  Future<Map<String, String>> getInfo({
    bool forceRefresh = false,
    void Function(String key, String value)? onField,
  }) {
    if (!forceRefresh && _cachedInfo != null) {
      return Future.value(Map<String, String>.from(_cachedInfo!));
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    late final Future<Map<String, String>> future;
    future = Future<Map<String, String>>(() {
      final result = _getInfoSync(onField: onField);
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

  static Map<String, String> _getInfoSync({
    void Function(String key, String value)? onField,
  }) {
    final result = {
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
    for (final entry in result.entries) {
      onField?.call(entry.key, entry.value);
    }
    _debugSnapshot = SystemInfoDebugSnapshot(
      platform: 'linux',
      source: 'dart-io',
      logs: const ['Loaded via Linux dart:io implementation.'],
      data: Map<String, String>.from(result),
    );
    return result;
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
              line.split(':').last.trim().split(' ').first,
            ) ??
            0;
      }
      if (line.startsWith('MemAvailable:')) {
        memAvail = int.tryParse(
              line.split(':').last.trim().split(' ').first,
            ) ??
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
      final result = Process.runSync(
        'df',
        ['-B1', '--output=size,used,avail', mount],
      );
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

// ── Android ──────────────────────────────────────────────────────────────────

class _AndroidSystemInfo implements SystemInfoService {
  static const _channel = MethodChannel('dart_flutter_demo/system_info');
  static Map<String, String>? _cachedInfo;
  static SystemInfoDebugSnapshot _debugSnapshot = const SystemInfoDebugSnapshot(
    platform: 'android',
    source: 'idle',
    logs: <String>[],
    data: <String, String>{},
  );

  static SystemInfoDebugSnapshot get debugSnapshot => _debugSnapshot;

  @override
  Future<Map<String, String>> getInfo({
    bool forceRefresh = false,
    void Function(String key, String value)? onField,
  }) async {
    if (!forceRefresh && _cachedInfo != null) {
      for (final entry in _cachedInfo!.entries) {
        onField?.call(entry.key, entry.value);
      }
      return Map<String, String>.from(_cachedInfo!);
    }
    final result = await _channel.invokeMapMethod<String, String>('getInfo');
    final info = result ?? {};
    _cachedInfo = Map<String, String>.from(info);
    for (final entry in info.entries) {
      onField?.call(entry.key, entry.value);
    }
    _debugSnapshot = SystemInfoDebugSnapshot(
      platform: 'android',
      source: 'method-channel',
      logs: const ['Loaded via Android method channel.'],
      data: Map<String, String>.from(info),
    );
    return Map<String, String>.from(info);
  }
}
