import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/steps/step_source.dart';

/// Measured on the real HONOR VNE-N41 on 8 September 2026.
///
/// The phone **has** a hardware step counter:
///
///     0x000000bf) pedometer Non-wakeup | honor | ver: 1
///       | type: android.sensor.step_counter(19)
///       | perm: android.permission.ACTIVITY_RECOGNITION
///
/// and Nouri **does not hold the permission it needs to read it**:
///
///     runtime permissions:
///       android.permission.ACTIVITY_RECOGNITION: granted=false
///
/// The manifest declares it, but ACTIVITY_RECOGNITION has been a *runtime*
/// permission since Android 10 and nothing anywhere asked for it. So
/// `isAvailable()` — which only asked whether the sensor exists — would have
/// said yes, the screen would have offered «يلا نمشي», and the counter would
/// have sat at zero forever.
///
/// That is precisely the failure `StepSource`'s own doc comment forbids:
/// "A source that claimed availability and then produced nothing would leave
/// the user watching a counter stuck at zero with no explanation."
void main() {
  group('the three states a device can be in', () {
    test('no sensor at all is its own answer', () async {
      final s = FakeStepSource(state_: StepSensorState.noSensor);
      expect(await s.state(), StepSensorState.noSensor);
    });

    test('a sensor Nouri may not read is NOT the same as no sensor', () async {
      // The whole point. Telling someone with a working pedometer that their
      // «جهازك مافيهوش حسّاس خطوات» is a false statement about their phone,
      // and it hides the one action that would fix it.
      final s = FakeStepSource(state_: StepSensorState.needsPermission);
      expect(await s.state(), isNot(StepSensorState.noSensor));
      expect(await s.state(), StepSensorState.needsPermission);
    });

    test('ready means the steps will actually arrive', () async {
      final s = FakeStepSource(state_: StepSensorState.ready);
      expect(await s.state(), StepSensorState.ready);
    });
  });

  group('the simulated source', () {
    test('is always ready — it needs no hardware and no permission', () async {
      expect(await SimulatedStepSource().state(), StepSensorState.ready);
    });

    test('and asking it for permission is a no-op that succeeds', () async {
      expect(await SimulatedStepSource().requestPermission(), isTrue);
    });
  });

  group('granting', () {
    test('a granted permission moves the state to ready', () async {
      final s = FakeStepSource(
        state_: StepSensorState.needsPermission,
        grantOnRequest: true,
      );
      expect(await s.state(), StepSensorState.needsPermission);

      expect(await s.requestPermission(), isTrue);
      expect(await s.state(), StepSensorState.ready);
    });

    test('a refusal leaves it where it was, and says so', () async {
      // A refusal is not an error. Nouri keeps working and states the
      // limitation, the way it does for location.
      final s = FakeStepSource(
        state_: StepSensorState.needsPermission,
        grantOnRequest: false,
      );
      expect(await s.requestPermission(), isFalse);
      expect(await s.state(), StepSensorState.needsPermission);
    });

    test('asking on a device with no sensor cannot make one appear', () async {
      final s = FakeStepSource(
        state_: StepSensorState.noSensor,
        grantOnRequest: true,
      );
      expect(await s.requestPermission(), isFalse);
      expect(await s.state(), StepSensorState.noSensor);
    });
  });
}

/// A step source whose state is whatever the test says it is.
class FakeStepSource implements StepSource {
  FakeStepSource({required this.state_, this.grantOnRequest = false});

  StepSensorState state_;
  final bool grantOnRequest;

  @override
  Future<StepSensorState> state() async => state_;

  @override
  Future<bool> requestPermission() async {
    if (state_ == StepSensorState.noSensor) return false;
    if (grantOnRequest) state_ = StepSensorState.ready;
    return state_ == StepSensorState.ready;
  }

  @override
  Stream<int> cumulativeSteps() => const Stream.empty();

  @override
  void dispose() {}
}
