import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

final ValueNotifier<Duration?> lastRefreshDurationNotifier =
    ValueNotifier<Duration?>(null);

final ValueNotifier<int> shellRebuildCountNotifier = ValueNotifier<int>(0);

class FrameFpsTracker {
  final List<int> _frameEndMicros = [];
  double _fps = 0;

  double get fps => _fps;

  void addTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frameEndMicros.add(
        timing.timestampInMicroseconds(FramePhase.rasterFinish),
      );
    }
    if (_frameEndMicros.length > 90) {
      _frameEndMicros.removeRange(0, _frameEndMicros.length - 90);
    }
    if (_frameEndMicros.length < 2) {
      _fps = 0;
      return;
    }
    final spanMicros = _frameEndMicros.last - _frameEndMicros.first;
    if (spanMicros <= 0) {
      _fps = 0;
      return;
    }
    _fps = (_frameEndMicros.length - 1) * 1000000 / spanMicros;
  }
}
