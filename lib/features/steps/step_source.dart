import 'dart:async';

/// Where step counts come from.
///
/// An interface with two implementations, because the hardware one cannot be
/// exercised anywhere useful: emulator images have no step-counter sensor, and
/// a widget test has no platform channel at all. Everything above this line —
/// the session arithmetic, the screen, the persistence — is tested against
/// [SimulatedStepSource].
/// What is standing between the user and a step count.
///
/// Four states, not two, because each of the middle ones is real and was being
/// reported as the wrong end. Measured on the HONOR VNE-N41: the phone has an
/// HONOR `pedometer` reporting `android.sensor.step_counter(19)`, and Nouri
/// held `ACTIVITY_RECOGNITION: granted=false`. Collapsing that into "no
/// sensor" tells someone with a working pedometer that their phone has none,
/// and hides the one action that would fix it.
enum StepSensorState {
  /// A sensor exists and Nouri may read it.
  ready,

  /// A sensor exists; Nouri has not been allowed to read it yet.
  ///
  /// ACTIVITY_RECOGNITION is a runtime permission on Android 10 and later.
  /// The manifest declaring it is not enough.
  needsPermission,

  /// A sensor exists, and Android will no longer ask on Nouri's behalf.
  ///
  /// Distinct from [needsPermission] because the *remedy* is different, which
  /// is the only reason a state is ever worth splitting. Once the user has
  /// refused twice — or once, with "don't ask again" — `request()` returns
  /// denied immediately and **shows nothing at all**. A screen that answers
  /// that by offering the same «اسمح لنوري» button hands the user a control
  /// that does nothing, forever, and never mentions the one route that still
  /// works: Nouri's own page in system settings.
  permissionBlocked,

  /// This device cannot count steps. Most emulator images.
  noSensor,
}

abstract interface class StepSource {
  /// Whether this device can count steps **for Nouri**, and if not, why.
  ///
  /// Answered honestly, which now includes the permission. A source that
  /// claimed availability and then produced nothing would leave the user
  /// watching a counter stuck at zero with no explanation — and that is
  /// exactly what a sensor-only check did on the real phone.
  Future<StepSensorState> state();

  /// Asks for the permission the sensor needs, returning whether it is now
  /// readable.
  ///
  /// False when refused, and false when there is no sensor to permit — asking
  /// cannot make hardware appear.
  Future<bool> requestPermission();

  /// Opens Nouri's own page in the system settings.
  ///
  /// The only remaining route once the permission is [permissionBlocked]:
  /// Android will not show the prompt again, so the grant has to be made by
  /// hand. Returns whether the screen could be opened.
  Future<bool> openAppSettings();

  /// Steps **since the device booted**, not since the stream was listened to.
  ///
  /// Cumulative because that is what Android's `TYPE_STEP_COUNTER` reports,
  /// and because it is the more useful contract: the OS keeps counting while
  /// the app is backgrounded, so a session can reconcile on resume from the
  /// total rather than losing the steps it did not watch happen.
  ///
  /// Resets to zero on reboot. Callers take the difference against a start
  /// reading and must clamp it — see `walkStats`.
  Stream<int> cumulativeSteps();

  void dispose();
}

/// A deterministic source, for tests and for the emulator.
///
/// Never reachable in a release build unless the user has explicitly turned on
/// `allowSimulatedSteps` in settings, which is off by default. A walk that
/// quietly invented steps on a real phone would be the app lying to the user
/// about their own body.
class SimulatedStepSource implements StepSource {
  SimulatedStepSource({
    this.startAt = 0,
    this.stepsPerTick = 2,
    this.tick = const Duration(milliseconds: 600),
  });

  /// The starting cumulative reading, standing in for "steps since boot".
  final int startAt;
  final int stepsPerTick;
  final Duration tick;

  StreamController<int>? _controller;
  Timer? _timer;

  /// Always ready: it needs no hardware and no permission.
  @override
  Future<StepSensorState> state() async => StepSensorState.ready;

  @override
  Future<bool> requestPermission() async => true;

  /// Nothing to open: this source never needs a permission.
  @override
  Future<bool> openAppSettings() async => false;

  @override
  Stream<int> cumulativeSteps() {
    final c = StreamController<int>(onCancel: dispose);
    _controller = c;

    var total = startAt;
    _timer = Timer.periodic(tick, (_) {
      total += stepsPerTick;
      if (!c.isClosed) c.add(total);
    });

    return c.stream;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    final c = _controller;
    _controller = null;
    if (c != null && !c.isClosed) c.close();
  }
}
