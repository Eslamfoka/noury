import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/athkar/athkar_item.dart';
import 'package:nouri/features/athkar/athkar_controller.dart';
import 'package:nouri/features/athkar/tasbeeh_controller.dart';

AthkarItem item(String id, int count) =>
    AthkarItem(id: id, text: 'نص $id', count: count, source: 'رواه البخاري');

void main() {
  group('AthkarController', () {
    test('a single-repeat dhikr advances on one tap', () {
      final c = AthkarController([item('a', 1), item('b', 1)]);
      expect(c.currentIndex, 0);
      c.tap();
      expect(c.currentIndex, 1);
    });

    test('a three-repeat dhikr needs three taps', () {
      final c = AthkarController([item('a', 3), item('b', 1)]);
      c.tap();
      expect(c.currentIndex, 0, reason: 'still on the first dhikr');
      expect(c.currentRepeats, 1);
      c.tap();
      expect(c.currentIndex, 0);
      expect(c.currentRepeats, 2);
      c.tap();
      expect(c.currentIndex, 1, reason: 'the third tap advances');
    });

    test('a new dhikr starts at zero repeats', () {
      final c = AthkarController([item('a', 2), item('b', 3)]);
      c.tap();
      c.tap();
      expect(c.currentIndex, 1);
      expect(c.currentRepeats, 0);
    });

    test('going back shows the previous dhikr still fully counted', () {
      final c = AthkarController([item('a', 2), item('b', 3)]);
      c.tap();
      c.tap();
      c.previous();
      expect(c.currentIndex, 0);
      expect(c.currentRepeats, 2, reason: 'a finished dhikr stays finished');
      expect(c.isDoneAt(0), isTrue);
    });

    test('previous on the first dhikr does nothing', () {
      final c = AthkarController([item('a', 1)]);
      c.previous();
      expect(c.currentIndex, 0);
    });

    test('the set completes after the last repetition of the last dhikr', () {
      final c = AthkarController([item('a', 1), item('b', 2)]);
      c.tap();
      c.tap();
      expect(c.isComplete, isFalse);
      c.tap();
      expect(c.isComplete, isTrue);
      expect(c.completedItems, 2);
    });

    test('tapping past completion never overflows the index', () {
      final c = AthkarController([item('a', 1)]);
      c.tap();
      c.tap();
      c.tap();
      expect(c.currentIndex, 0);
      expect(c.isComplete, isTrue);
      expect(c.currentRepeats, 1, reason: 'the count is capped at the target');
    });

    test('skipping forward marks nothing as done', () {
      final c = AthkarController([item('a', 3), item('b', 1)]);
      c.next();
      expect(c.currentIndex, 1);
      expect(c.completedItems, 0, reason: 'skipped, not performed');
    });

    test('fraction tracks total taps across the whole set', () {
      final c = AthkarController([item('a', 2), item('b', 2)]);
      expect(c.fraction, 0.0);
      c.tap();
      expect(c.fraction, closeTo(0.25, 0.001));
      c.tap();
      c.tap();
      c.tap();
      expect(c.fraction, 1.0);
    });

    test('restores from a persisted snapshot', () {
      final c = AthkarController(
        [item('a', 3), item('b', 1)],
        initialRepeats: [3, 0],
      );
      expect(c.completedItems, 1);
      expect(c.isDoneAt(0), isTrue);
    });

    test('reset clears everything back to the start', () {
      final c = AthkarController([item('a', 2), item('b', 1)]);
      c.tap();
      c.tap();
      c.reset();
      expect(c.currentIndex, 0);
      expect(c.completedItems, 0);
      expect(c.isComplete, isFalse);
    });
  });

  group('TasbeehController', () {
    test('starts at zero against the default target of 100', () {
      final c = TasbeehController();
      expect(c.count, 0);
      expect(c.target, 100);
      expect(c.fraction, 0.0);
    });

    test('increments and reports a fraction', () {
      final c = TasbeehController()..increment();
      expect(c.count, 1);
      expect(c.fraction, closeTo(0.01, 0.0001));
    });

    test('counting past the target is allowed and the fraction clamps', () {
      final c = TasbeehController(target: 3);
      for (var i = 0; i < 5; i++) {
        c.increment();
      }
      expect(c.count, 5, reason: 'extra dhikr is never refused');
      expect(c.fraction, 1.0);
    });

    test('justCompleted fires once, on the crossing only', () {
      final c = TasbeehController(target: 2);
      c.increment();
      expect(c.justCompleted, isFalse);
      c.increment();
      expect(c.justCompleted, isTrue);
      c.increment();
      expect(c.justCompleted, isFalse, reason: 'it is a one-shot signal');
    });

    test('reset returns to zero without touching the target', () {
      final c = TasbeehController(target: 33)
        ..increment()
        ..increment();
      c.reset();
      expect(c.count, 0);
      expect(c.target, 33);
    });

    test('the target can be raised and the count is kept', () {
      final c = TasbeehController(target: 100, initial: 40);
      c.setTarget(300);
      expect(c.target, 300);
      expect(c.count, 40);
    });

    test('the target can never be set below one', () {
      final c = TasbeehController();
      c.setTarget(0);
      expect(c.target, greaterThanOrEqualTo(1));
      c.setTarget(-5);
      expect(c.target, greaterThanOrEqualTo(1));
    });

    test('restoring a persisted count does not fire the completion signal', () {
      final c = TasbeehController(target: 100);
      c.restore(count: 100, target: 100);
      expect(c.count, 100);
      expect(c.isComplete, isTrue);
      expect(c.justCompleted, isFalse,
          reason: 'reopening the app must not re-celebrate');
    });
  });
}
