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
        final fallback = _getInfoFallback();
        final merged = Map<String, String>.from(fallback);
        merged.addAll(result);
        _cachedInfo = Map<String, String>.from(merged);
        for (final entry in merged.entries) {
          onField?.call(entry.key, entry.value);
        }
        _debugSnapshot = SystemInfoDebugSnapshot(
          platform: 'macos',
          source: 'method-channel+fallback',
          logs: const ['Loaded via macOS method channel and merged fallback values.'],
          data: Map<String, String>.from(merged),
        );
        return Map<String, String>.from(merged);
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
    result['Kernel'] = _getKernel();
    result['Uptime'] = _getUptime();
    result['CPU'] = _getCPU();
    result['Memory'] = _getMemory();
    result['Disk'] = _getDisk('/');
    result['Local IP'] = _getLocalIP();
    result['Locale'] = Platform.localeName;
    _debugSnapshot = SystemInfoDebugSnapshot(
      platform: 'macos',
      source: 'fallback',
      logs: const ['Using macOS dart:io fallback.'],
      data: Map<String, String>.from(result),
    );
    return result;
  }

  String _getKernel() {
    final release = _runCommand('sysctl', ['-n', 'kern.osrelease']);
    return release.isEmpty
        ? 'Darwin ${Platform.operatingSystemVersion}'
        : 'Darwin $release';
  }

  String _getCPU() {
    final brand = _runCommand('sysctl', ['-n', 'machdep.cpu.brand_string']);
    final cores = _runCommand('sysctl', ['-n', 'hw.logicalcpu']);
    if (brand.isNotEmpty && cores.isNotEmpty) {
      return '$brand ($cores)';
    }
    return '${Platform.numberOfProcessors} cores';
  }

  String _getUptime() {
    final bootTime = _readMacBootTime();
    if (bootTime == null) return 'unavailable';
    return _formatDuration(DateTime.now().difference(bootTime));
  }

  String _getMemory() {
    final totalBytes = int.tryParse(_runCommand('sysctl', ['-n', 'hw.memsize'])) ?? 0;
    if (totalBytes <= 0) return 'unavailable';

    final pageSize = int.tryParse(_runCommand('sysctl', ['-n', 'hw.pagesize'])) ?? 4096;
    final vmStat = _runCommand('vm_stat', const []);
    final freePages = _extractVmStatPages(vmStat, 'Pages free');
    final speculativePages = _extractVmStatPages(vmStat, 'Pages speculative');
    final fileBackedPages = _extractVmStatPages(vmStat, 'File-backed pages');
    final cachedPages = fileBackedPages >= 0 ? fileBackedPages : 0;
    final usableFreePages = (freePages >= 0 ? freePages : 0) - (speculativePages >= 0 ? speculativePages : 0);
    final usedBytes = totalBytes - ((usableFreePages + cachedPages) * pageSize);
    final clampedUsedBytes = usedBytes < 0 ? 0 : usedBytes;
    final usedGiB = clampedUsedBytes / (1024.0 * 1024.0 * 1024.0);
    final totalGiB = totalBytes / (1024.0 * 1024.0 * 1024.0);
    final pct = totalBytes > 0 ? ((clampedUsedBytes / totalBytes) * 100).round() : 0;
    return '${usedGiB.toStringAsFixed(2)} GiB / ${totalGiB.toStringAsFixed(2)} GiB ($pct%)';
  }

  String _getDisk(String mountPoint) {
    final result = Process.runSync('df', ['-k', mountPoint], runInShell: false);
    if (result.exitCode != 0) return 'unavailable';

    final lines = result.stdout.toString().trim().split(RegExp(r'\r?\n'));
    if (lines.length < 2) return 'unavailable';
    final parts = lines[1].trim().split(RegExp(r'\s+'));
    if (parts.length < 6) return 'unavailable';
    final totalBlocks = int.tryParse(parts[1]) ?? 0;
    final usedBlocks = int.tryParse(parts[2]) ?? 0;
    if (totalBlocks <= 0) return 'unavailable';
    final usedGiB = usedBlocks / (1024.0 * 1024.0);
    final totalGiB = totalBlocks / (1024.0 * 1024.0);
    final pct = ((usedBlocks / totalBlocks) * 100).round();
    return '${usedGiB.toStringAsFixed(2)} GiB / ${totalGiB.toStringAsFixed(2)} GiB ($pct%)';
  }

  String _getLocalIP() {
    final route = _runCommand('route', ['-n', 'get', 'default']);
    final ifaceMatch = RegExp(r'interface:\s+(\S+)').firstMatch(route);
    final preferredIf = ifaceMatch?.group(1);
    if (preferredIf != null && preferredIf.isNotEmpty) {
      final ip = _runCommand('ipconfig', ['getifaddr', preferredIf]);
      if (ip.isNotEmpty) return ip;
    }

    for (final iface in const ['en0', 'en1', 'en2', 'en3']) {
      final ip = _runCommand('ipconfig', ['getifaddr', iface]);
      if (ip.isNotEmpty) return ip;
    }

    final ifconfig = _runCommand('ifconfig', const []);
    for (final line in ifconfig.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      final match = RegExp(r'inet\s+([0-9.]+)').firstMatch(trimmed);
      if (match != null) {
        final ip = match.group(1)!;
        if (!ip.startsWith('127.')) return ip;
      }
    }
    return 'unavailable';
  }

  String _runCommand(String executable, List<String> args) {
    try {
      final result = Process.runSync(executable, args, runInShell: false);
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
    } catch (_) {}
    return '';
  }

  DateTime? _readMacBootTime() {
    final output = _runCommand('sysctl', ['-n', 'kern.boottime']);
    final unixMatch = RegExp(r'sec\s*=\s*(\d+)').firstMatch(output);
    if (unixMatch != null) {
      final seconds = int.tryParse(unixMatch.group(1)!);
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return null;
  }

  int _extractVmStatPages(String vmStat, String label) {
    for (final line in vmStat.split(RegExp(r'\r?\n'))) {
      final match = RegExp('${RegExp.escape(label)}:\\s*(\\d+)\\.?').firstMatch(line);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? -1;
      }
    }
    return -1;
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final secs = d.inSeconds % 60;
    final buf = StringBuffer();
    if (days > 0) buf.write('$days days, ');
    buf.write('$hours hours, $mins mins, $secs secs');
    return buf.toString();
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
      final dylib = _openWindowsFfiLibrary(debug);
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
      result['OS'] = _normalizeWindowsOsLabel(
        result['OS'] ?? '',
        kernel: result['Kernel'],
      );
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
    result['OS'] = _normalizeWindowsOsLabel(
      result['OS'] ?? '',
      kernel: result['Kernel'],
    );

    final state = _WindowsFallbackState(debug, result, onField: onField);
    for (final entry in result.entries) {
      onField?.call(entry.key, entry.value);
    }
    debug.add('Entering fallback chain.');
    await _tryNativeCommands(state);
    if (_needsSlowWindowsFallback(state.result)) {
      debug.add(
        'Fast fallback left gaps in Windows fields. Trying slower fallbacks for missing values.',
      );
      await _tryStandalonePs1(state);
      if (_needsSlowWindowsFallback(state.result)) {
        await _tryInlinePowerShell(state);
      }
    }
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

  static DynamicLibrary _openWindowsFfiLibrary(_DebugLogBuffer debug) {
    final attempts = <String>[];

    try {
      debug.add('Trying FFI via DynamicLibrary.process().');
      return DynamicLibrary.process();
    } catch (e) {
      attempts.add('process(): $e');
    }

    final executablePath = Platform.resolvedExecutable;
    try {
      debug.add('Trying FFI via resolved executable: $executablePath');
      return DynamicLibrary.open(executablePath);
    } catch (e) {
      attempts.add('resolvedExecutable: $e');
    }

    final exeName = executablePath.split(Platform.pathSeparator).last;
    try {
      debug.add('Trying FFI via executable filename: $exeName');
      return DynamicLibrary.open(exeName);
    } catch (e) {
      attempts.add('exeName: $e');
    }

    throw ArgumentError(
      'Failed to load Windows FFI library. Attempts: ${attempts.join(' | ')}',
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

    final slashYearFirstMatch = RegExp(
      r'^(\d{4})/(\d{1,2})/(\d{1,2})\s+(\d{1,2}):(\d{2}):(\d{2})$',
    ).firstMatch(trimmed);
    if (slashYearFirstMatch != null) {
      final year = int.tryParse(slashYearFirstMatch.group(1)!);
      final month = int.tryParse(slashYearFirstMatch.group(2)!);
      final day = int.tryParse(slashYearFirstMatch.group(3)!);
      final hour = int.tryParse(slashYearFirstMatch.group(4)!);
      final minute = int.tryParse(slashYearFirstMatch.group(5)!);
      final second = int.tryParse(slashYearFirstMatch.group(6)!);
      if (month != null &&
          day != null &&
          year != null &&
          hour != null &&
          minute != null &&
          second != null) {
        return DateTime(year, month, day, hour, minute, second);
      }
    }

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

  static String _normalizeWindowsOsLabel(String os, {String? kernel}) {
    final trimmed = os.trim();
    if (trimmed.isEmpty || !trimmed.contains('Windows 10')) return trimmed;

    final build =
        _extractWindowsBuildNumber(kernel) ?? _extractWindowsBuildNumber(trimmed);
    if (build == null || build < 22000) return trimmed;

    return trimmed.replaceFirst('Windows 10', 'Windows 11');
  }

  static int? _extractWindowsBuildNumber(String? text) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) return null;

    final dotted = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(value);
    if (dotted != null) {
      return int.tryParse(dotted.group(3)!);
    }

    final buildTagged =
        RegExp(r'Build\s+(\d+)', caseSensitive: false).firstMatch(value);
    if (buildTagged != null) {
      return int.tryParse(buildTagged.group(1)!);
    }

    return null;
  }

  static String _clipDebugText(String value, {int maxChars = 2000}) {
    final normalized = value.replaceAll('\r\n', '\n').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}\n...<truncated>';
  }

  static bool _needsSlowWindowsFallback(Map<String, String> result) {
    const keys = ['Uptime', 'Memory', 'Disk (C:\\)', 'Local IP'];
    for (final key in keys) {
      final value = result[key]?.trim() ?? '';
      if (value.isEmpty || value == 'unknown' || value == 'unavailable') {
        return true;
      }
    }
    return false;
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
    future = _getInfoAsync(onField: onField).then((result) {
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
    final result = {
      'OS': _getOS(),
      'Host': _getHostname(),
      'Kernel': _getKernel(),
      'Uptime': _getUptime(),
      'CPU': _getCPU(),
      'Memory': _getMemory(),
      'Disk (/)': _getDisk('/'),
      'Local IP': await _getLocalIP(),
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

  static Future<String> _getLocalIP() async {
    try {
      final route = Process.runSync('ip', ['-4', 'route', 'get', '1']);
      if (route.exitCode == 0) {
        final match = RegExp(r'src\s+(\d+\.\d+\.\d+\.\d+)')
            .firstMatch(route.stdout.toString());
        if (match != null) {
          final normalized = _normalizeLinuxIpv4(match.group(1)!);
          if (normalized != null) return normalized;
        }
      }
    } catch (_) {}

    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final normalized = _normalizeLinuxIpv4(addr.address);
          if (normalized != null) return normalized;
        }
      }
    } catch (_) {}

    try {
      final result = Process.runSync('hostname', ['-I']);
      if (result.exitCode == 0) {
        final ips = result.stdout.toString().trim().split(RegExp(r'\s+'));
        for (final ip in ips) {
          final normalized = _normalizeLinuxIpv4(ip);
          if (normalized != null) return normalized;
        }
      }
    } catch (_) {}

    try {
      final addr = Process.runSync('ip', ['-4', 'addr', 'show', 'scope', 'global']);
      if (addr.exitCode == 0) {
        final match = RegExp(r'inet\s+(\d+\.\d+\.\d+\.\d+)')
            .firstMatch(addr.stdout.toString());
        if (match != null) {
          final normalized = _normalizeLinuxIpv4(match.group(1)!);
          if (normalized != null) return normalized;
        }
      }
    } catch (_) {}

    return 'unknown';
  }

  static String? _normalizeLinuxIpv4(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('127.')) return null;
    if (value.startsWith('169.254.')) return null;
    final match = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').firstMatch(value);
    if (match == null) return null;
    return value;
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
    final localIp = info['Local IP']?.trim() ?? '';
    if (localIp.isEmpty ||
        localIp == 'unknown' ||
        localIp == 'unavailable') {
      final fallbackIp = await _getDartLocalIPFallback();
      if (fallbackIp.isNotEmpty) {
        info['Local IP'] = fallbackIp;
      }
    }
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

  static Future<String> _getDartLocalIPFallback() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      final sorted = List<NetworkInterface>.from(interfaces)
        ..sort((a, b) {
          int score(NetworkInterface iface) {
            final name = iface.name.toLowerCase();
            if (name.contains('wlan') || name.contains('wifi')) return 0;
            if (name.contains('eth')) return 1;
            if (name.contains('rmnet') ||
                name.contains('ccmni') ||
                name.contains('pdp')) {
              return 2;
            }
            return 3;
          }

          final byScore = score(a).compareTo(score(b));
          if (byScore != 0) return byScore;
          return a.name.compareTo(b.name);
        });

      for (final iface in sorted) {
        final addresses = List<InternetAddress>.from(iface.addresses)
          ..sort((a, b) {
            final aIsIpv4 = a.type == InternetAddressType.IPv4;
            final bIsIpv4 = b.type == InternetAddressType.IPv4;
            if (aIsIpv4 && !bIsIpv4) return -1;
            if (!aIsIpv4 && bIsIpv4) return 1;
            return 0;
          });
        for (final address in addresses) {
          final value = address.address.trim();
          if (value.isNotEmpty &&
              !value.startsWith('127.') &&
              !value.startsWith('169.254.')) {
            return value;
          }
        }
      }
    } catch (_) {}
    return '';
  }
}
