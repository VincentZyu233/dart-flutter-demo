import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

final ValueNotifier<Duration?> lastRefreshDurationNotifier =
    ValueNotifier<Duration?>(null);

final ValueNotifier<int> shellRebuildCountNotifier = ValueNotifier<int>(0);

class FrameFpsTracker {
  final List<int> _frameTimestampsMicros = [];
  double _fps = 0;

  double get fps => _fps;

  void addTimings(List<FrameTiming> timings) {
    final nowMicros = DateTime.now().microsecondsSinceEpoch;
    for (final timing in timings) {
      _frameTimestampsMicros.add(
        timing.totalSpan.inMicroseconds > 0
            ? nowMicros
            : nowMicros,
      );
    }
    if (_frameTimestampsMicros.length > 180) {
      _frameTimestampsMicros
          .removeRange(0, _frameTimestampsMicros.length - 180);
    }
    final cutoff = nowMicros - const Duration(seconds: 1).inMicroseconds;
    _frameTimestampsMicros.removeWhere((value) => value < cutoff);
    if (_frameTimestampsMicros.isEmpty) {
      _fps = 0;
      return;
    }
    _fps = _frameTimestampsMicros.length.toDouble();
  }
}
