import 'package:flutter/foundation.dart';

/// The circular tasbeeh counter.
///
/// Counting past the target is always allowed — the target is an encouragement,
/// not a ceiling, and Nouri never refuses extra dhikr.
class TasbeehController extends ChangeNotifier {
  TasbeehController({int target = 100, int initial = 0})
      : _target = target < 1 ? 1 : target,
        _count = initial < 0 ? 0 : initial;

  int _count;
  int _target;
  bool _justCompleted = false;

  int get count => _count;
  int get target => _target;
  double get fraction => (_count / _target).clamp(0.0, 1.0);

  /// True only on the tap that crossed the target.
  ///
  /// A one-shot signal: the UI gives a single soft confirmation rather than
  /// celebrating on every subsequent tap.
  bool get justCompleted => _justCompleted;

  bool get isComplete => _count >= _target;

  void increment() {
    final was = _count;
    _count++;
    _justCompleted = was < _target && _count >= _target;
    notifyListeners();
  }

  void reset() {
    _count = 0;
    _justCompleted = false;
    notifyListeners();
  }

  void setTarget(int t) {
    _target = t < 1 ? 1 : t;
    _justCompleted = false;
    notifyListeners();
  }

  /// Restores a persisted count without firing the completion signal.
  void restore({required int count, required int target}) {
    _count = count < 0 ? 0 : count;
    _target = target < 1 ? 1 : target;
    _justCompleted = false;
    notifyListeners();
  }
}
