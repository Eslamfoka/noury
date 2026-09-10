import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/features/settings/settings_controller.dart';

class RecordingScheduler implements SchedulerPort {
  final List<SchedulingConfig> calls = [];

  @override
  Future<void> rearm(SchedulingConfig config) async => calls.add(config);
}

const _config = SchedulingConfig(
  geo: GeoConfig.kuwaitCity,
  iqamaOffsets: {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 10, 'isha': 15},
);

void main() {
  test('a re-arm requested before warm-up still happens afterwards', () async {
    // Arming the window takes ~11.7s, so it runs after the first frame. A
    // settings change during that gap must be honoured late, never dropped.
    final ready = Completer<SchedulerPort?>();
    final port = DeferredSchedulerPort(ready.future);
    final real = RecordingScheduler();

    final pending = port.rearm(_config);
    expect(real.calls, isEmpty, reason: 'nothing to forward to yet');

    ready.complete(real);
    await pending;

    expect(real.calls, hasLength(1),
        reason: 'the request was queued, not lost');
    expect(real.calls.single.geo.latitude, closeTo(29.3759, 0.0001));
  });

  test('re-arms after warm-up forward immediately', () async {
    final real = RecordingScheduler();
    final port = DeferredSchedulerPort(Future.value(real));

    await port.rearm(_config);
    await port.rearm(_config);

    expect(real.calls, hasLength(2));
  });

  test('a failed warm-up degrades quietly instead of throwing', () async {
    // If notification setup failed entirely there is no scheduler. Settings
    // must still be editable — the app degrades, it does not break.
    final port = DeferredSchedulerPort(Future.value(null));
    await expectLater(port.rearm(_config), completes);
  });

  test('several queued re-arms all reach the real scheduler', () async {
    final ready = Completer<SchedulerPort?>();
    final port = DeferredSchedulerPort(ready.future);
    final real = RecordingScheduler();

    final pending = [
      port.rearm(_config),
      port.rearm(_config),
      port.rearm(_config),
    ];

    ready.complete(real);
    await Future.wait(pending);

    expect(real.calls, hasLength(3));
  });
}
