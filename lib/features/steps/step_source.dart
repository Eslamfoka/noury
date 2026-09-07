import 'dart:async';

/// Where step counts come from.
///
/// An interface with two implementations, because the hardware one cannot be
/// exercised anywhere useful: emulator images have no step-counter sensor, and
/// a widget test has no platform channel at all. Everything above this line —
/// the session arithmetic, the screen, the persistence — is tested against
/// [SimulatedStepSource].
abstract interface class StepSource {
  /// Whether this device can count steps at all.
  ///
  /// Answered honestly. A source that claimed availability and then produced
  /// nothing would leave the user watching a counter stuck at zero with no
  /// explanation.
  Future<bool> isAvailable();

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

  @override
  Future<bool> isAvailable() async => true;

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
