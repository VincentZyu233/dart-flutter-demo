import 'dart:io';

import 'package:flutter/services.dart';

/// Unified system info interface.
/// Follows FlClash CoreInterface pattern — platform-specific implementations
/// behind a common contract.
abstract class SystemInfoService {
  Future<Map<String, String>> getInfo();
}

/// Factory to create platform-specific implementation.
SystemInfoService createSystemInfoService() {
  if (Platform.isWindows) return _WindowsSystemInfo();
  if (Platform.isLinux) return _LinuxSystemInfo();
  if (Platform.isAndroid) return _AndroidSystemInfo();
  throw UnsupportedError('Platform not supported');
}

// ── Windows (C++ MethodChannel) ──────────────────────────────────────────────

class _WindowsSystemInfo implements SystemInfoService {
  static const _channel = MethodChannel('flutter_showcase/system_info');

  @override
  Future<Map<String, String>> getInfo() async {
    final result = await _channel.invokeMapMethod<String, String>('getInfo');
    return result ?? {};
  }
}

// ── Linux (C MethodChannel) ──────────────────────────────────────────────────

class _LinuxSystemInfo implements SystemInfoService {
  static const _channel = MethodChannel('flutter_showcase/system_info');

  @override
  Future<Map<String, String>> getInfo() async {
    final result = await _channel.invokeMapMethod<String, String>('getInfo');
    return result ?? {};
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
