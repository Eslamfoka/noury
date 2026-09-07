import 'package:flutter/foundation.dart';

import 'exercise.dart';

enum IntervalPhase { ready, work, rest, done }

/// The work/rest state machine behind a workout.
///
/// Driven by [tick] rather than an internal `Timer`, so the whole thing is
/// testable without pumping real time — the widget owns the ticker and this
/// owns the rules. Same split as [AthkarController].
class IntervalTimer extends ChangeNotifier {
  IntervalTimer(this.routine);

  final Routine routine;

  IntervalPhase _phase = IntervalPhase.ready;
  int _index = 0;
  int _doneCount = 0;
  Duration _remaining = Duration.zero;
  Duration _elapsed = Duration.zero;
  bool _paused = false;

  IntervalPhase get phase => _phase;

  /// The exercise being worked, or rested before.
  int get index => _index;

  Exercise get current => routine.exercises[_index.clamp(0, routine.totalCount - 1)];

  /// The exercise a rest is leading into — the whole point of a rest screen.
  Exercise? get upNext => _index + 1 < routine.totalCount
      ? routine.exercises[_index + 1]
      : null;

  int get doneCount => _doneCount;
  int get totalCount => routine.totalCount;
  Duration get remaining => _remaining;

  /// Total time spent in the session, for the persisted row.
  Duration get elapsed => _elapsed;

  bool get isPaused => _paused;
  bool get isRunning =>
      _phase == IntervalPhase.work || _phase == IntervalPhase.rest;

  /// Completed exercises over the total — «٥ من ٢٠» is 0.25.
  double get fraction =>
      totalCount == 0 ? 0 : (_doneCount / totalCount).clamp(0.0, 1.0);

  /// How far through the current interval, for the ring.
  double get phaseFraction {
    final full = _phase == IntervalPhase.work ? routine.work : routine.rest;
    if (full.inMilliseconds <= 0) return 0;
    final gone = full - _remaining;
    return (gone.inMilliseconds / full.inMilliseconds).clamp(0.0, 1.0);
  }

  void start() {
    if (routine.exercises.isEmpty) {
      _phase = IntervalPhase.done;
      notifyListeners();
      return;
    }
    _phase = IntervalPhase.work;
    _index = 0;
    _doneCount = 0;
    _remaining = routine.work;
    _elapsed = Duration.zero;
    _paused = false;
    notifyListeners();
  }

  void pause() {
    _paused = !_paused;
    notifyListeners();
  }

  /// Counts the current exercise as done and moves on.
  ///
  /// Skipping still counts it. The user did the session; whether they held the
  /// last five seconds is not something Nouri is going to argue about, and a
  /// skip that scored nothing would just teach them to sit through the timer.
  void skip() {
    if (_phase == IntervalPhase.done) return;

    if (_phase == IntervalPhase.rest) {
      _advanceToNextWork();
      return;
    }

    _doneCount++;
    if (_doneCount >= totalCount) {
      _phase = IntervalPhase.done;
      _remaining = Duration.zero;
    } else {
      _phase = IntervalPhase.rest;
      _remaining = routine.rest;
    }
    notifyListeners();
  }

  /// Advances the machine by [d].
  ///
  /// Handles a tick longer than the interval by looping rather than clamping:
  /// a backgrounded app resumes with one large tick, and swallowing a whole
  /// rest period would drop the user straight into the next exercise with no
  /// warning.
  void tick(Duration d) {
    if (!isRunning || _paused) return;

    var left = d;
    _elapsed += d;

    while (left > Duration.zero && isRunning) {
      if (_remaining > left) {
        _remaining -= left;
        left = Duration.zero;
      } else {
        left -= _remaining;
        _remaining = Duration.zero;
        _completePhase();
      }
    }
    notifyListeners();
  }

  void _completePhase() {
    if (_phase == IntervalPhase.work) {
      _doneCount++;
      if (_doneCount >= totalCount) {
        // No trailing rest after the last exercise: resting once you have
        // stopped is just standing about.
        _phase = IntervalPhase.done;
        _remaining = Duration.zero;
      } else {
        _phase = IntervalPhase.rest;
        _remaining = routine.rest;
      }
    } else if (_phase == IntervalPhase.rest) {
      _advanceToNextWork();
    }
  }

  void _advanceToNextWork() {
    if (_index + 1 >= totalCount) {
      _phase = IntervalPhase.done;
      _remaining = Duration.zero;
    } else {
      _index++;
      _phase = IntervalPhase.work;
      _remaining = routine.work;
    }
    notifyListeners();
  }
}
