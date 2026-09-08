import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
  Future<StepSensorState> state() async {
    if (!await _hasSensor()) return StepSensorState.noSensor;

    // The sensor existing is not enough. ACTIVITY_RECOGNITION has been a
    // runtime permission since Android 10, and without it `registerListener`
    // succeeds and then delivers nothing — a counter stuck at zero with no
    // explanation, which is the one outcome StepSource forbids.
    //
    // Measured on the HONOR VNE-N41: the phone reports an HONOR pedometer on
    // android.sensor.step_counter(19), and Nouri held the permission as
    // granted=false, having never asked.
    final granted = await Permission.activityRecognition.isGranted;
    return granted ? StepSensorState.ready : StepSensorState.needsPermission;
  }

  @override
  Future<bool> requestPermission() async {
    // Asking cannot make hardware appear, and a prompt on a device with no
    // sensor would be a question with no useful answer.
    if (!await _hasSensor()) return false;

    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  Future<bool> _hasSensor() async {
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
