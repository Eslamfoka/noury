import 'package:flutter/services.dart';

import 'step_source.dart';

/// The Dart half of the hand-written Kotlin step channel.
///
/// Deliberately thin. Everything that can be reasoned about — the delta
/// arithmetic, the reboot clamp, the calorie estimate — lives in
/// `walk_session.dart`, where it is tested. This class only carries values
/// across the channel, so there is as little untested surface as possible.
/// Same shape as `LocalNotificationGateway`.
class SensorStepSource implements StepSource {
  SensorStepSource();

  static const _method = MethodChannel('com.nouri.nouri/steps');
  static const _events = EventChannel('com.nouri.nouri/steps_stream');

  @override
  Future<bool> isAvailable() async {
    try {
      return await _method.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // No channel at all — a widget test, or a platform this was never built
      // for. Unavailable is the honest answer, not a crash.
      return false;
    }
  }

  @override
  Stream<int> cumulativeSteps() =>
      _events.receiveBroadcastStream().map((e) => (e as num).toInt());

  @override
  void dispose() {
    // The EventChannel unregisters the sensor listener in onCancel when the
    // last subscription is dropped, so there is nothing to release here.
  }
}
