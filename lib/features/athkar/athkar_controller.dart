import 'package:flutter/foundation.dart';

import '../../data/athkar/athkar_item.dart';

/// Drives a set of athkar as a lightweight mini-tasbeeh.
///
/// A dhikr with a target of *n* requires *n* taps before it advances. Going
/// back is always allowed, and a dhikr already performed stays performed —
/// stepping back never erases work.
class AthkarController extends ChangeNotifier {
  AthkarController(this.items, {List<int>? initialRepeats})
      : assert(items.isNotEmpty, 'an athkar set is never empty'),
        _repeats = initialRepeats != null && initialRepeats.length == items.length
            ? List<int>.from(initialRepeats)
            : List.filled(items.length, 0);

  final List<AthkarItem> items;
  final List<int> _repeats;
  int _index = 0;

  int get currentIndex => _index;
  AthkarItem get current => items[_index];
  int get currentRepeats => _repeats[_index];

  /// Every dhikr has been performed its full number of times.
  bool get isComplete {
    for (var i = 0; i < items.length; i++) {
      if (_repeats[i] < items[i].count) return false;
    }
    return true;
  }

  int get completedItems {
    var n = 0;
    for (var i = 0; i < items.length; i++) {
      if (_repeats[i] >= items[i].count) n++;
    }
    return n;
  }

  /// Total taps done across the whole set, for the progress bar.
  int get totalRepeatsDone => _repeats.fold(0, (a, b) => a + b);

  double get fraction {
    final total = items.fold<int>(0, (a, i) => a + i.count);
    return total == 0 ? 0 : (totalRepeatsDone / total).clamp(0.0, 1.0);
  }

  bool isDoneAt(int i) => _repeats[i] >= items[i].count;

  List<int> get repeatsSnapshot => List.unmodifiable(_repeats);

  /// One recitation of the current dhikr. Advances when the count is met.
  void tap() {
    if (_repeats[_index] < items[_index].count) {
      _repeats[_index]++;
    }

    if (_repeats[_index] >= items[_index].count &&
        _index < items.length - 1) {
      _index++;
    }
    notifyListeners();
  }

  /// Skips ahead without counting the current dhikr as performed.
  void next() {
    if (_index < items.length - 1) {
      _index++;
      notifyListeners();
    }
  }

  void previous() {
    if (_index > 0) {
      _index--;
      notifyListeners();
    }
  }

  void reset() {
    for (var i = 0; i < _repeats.length; i++) {
      _repeats[i] = 0;
    }
    _index = 0;
    notifyListeners();
  }
}
