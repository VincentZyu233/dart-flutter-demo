import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

final ValueNotifier<int> shellRebuildCountNotifier = ValueNotifier<int>(0);
final ValueNotifier<double> frameFpsNotifier = ValueNotifier<double>(0);

class FrameFpsTracker {
  final List<int> _frameTimestampsMicros = [];
  double _fps = 0;

  double get fps => _fps;

  void addTimings(List<FrameTiming> timings) {
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    for (final timing in timings) {
      _frameTimestampsMicros.add(nowMicros);
    }
    if (_frameTimestampsMicros.length > 180) {
      _frameTimestampsMicros
          .removeRange(0, _frameTimestampsMicros.length - 180);
    }
    final cutoff = nowMicros - const Duration(seconds: 1).inMicroseconds;
    _frameTimestampsMicros.removeWhere((value) => value < cutoff);
    if (_frameTimestampsMicros.isEmpty) {
      _fps = 0;
      frameFpsNotifier.value = _fps;
      return;
    }
    _fps = _frameTimestampsMicros.length.toDouble();
    frameFpsNotifier.value = _fps;
  }
}
