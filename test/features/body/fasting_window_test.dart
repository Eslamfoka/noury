import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/body/fasting_window.dart';
import 'package:nouri/features/body/meal.dart';

void main() {
  group('a noon window (12:00-20:00)', () {
    FastingWindow at(int h, [int m = 0]) =>
        FastingWindow.at(DateTime(2026, 9, 8, h, m), startHour: 12);

    test('is eating inside the window', () {
      expect(at(12).isEating, isTrue);
      expect(at(16).isEating, isTrue);
      expect(at(19, 59).isEating, isTrue);
    });

    test('is fasting outside it', () {
      expect(at(20).isEating, isFalse, reason: 'the close is exclusive');
      expect(at(23).isEating, isFalse);
      expect(at(3).isEating, isFalse);
      expect(at(11, 59).isEating, isFalse);
    });

    test('counts down to the close while eating', () {
      expect(at(18).remaining, const Duration(hours: 2));
    });

    test('counts down to the next open while fasting', () {
      expect(at(9).remaining, const Duration(hours: 3));
    });

    test('after the window closes, it points at tomorrow', () {
      final w = at(22);
      expect(w.opens.day, 9, reason: 'the next window is tomorrow');
      expect(w.remaining, const Duration(hours: 14));
    });

    test('the window is eight hours, leaving sixteen to rest', () {
      final w = at(13);
      expect(w.closes.difference(w.opens), const Duration(hours: 8));
    });
  });

  group('a window that crosses midnight (20:00-04:00)', () {
    // An ordinary shape for a night shift, and the case a naive
    // "is now between open and close" check gets wrong.
    FastingWindow at(int day, int h) =>
        FastingWindow.at(DateTime(2026, 9, day, h), startHour: 20);

    test('is still eating after midnight', () {
      expect(at(9, 1).isEating, isTrue,
          reason: 'the window opened at 20:00 the previous day');
      expect(at(9, 3).isEating, isTrue);
    });

    test('closes at 04:00', () {
      expect(at(9, 4).isEating, isFalse);
      expect(at(9, 12).isEating, isFalse);
    });

    test('is eating in the evening of the same day', () {
      expect(at(8, 21).isEating, isTrue);
    });

    test('a window opened yesterday reports yesterday as its open', () {
      final w = at(9, 2);
      expect(w.opens.day, 8);
      expect(w.opens.hour, 20);
    });
  });

  group('across a DST change', () {
    test('the window stays eight wall-clock hours', () {
      // Egypt moves the clock forward on 24 April 2026. Adding an absolute
      // Duration would silently make the window seven or nine hours; building
      // the date keeps it at eight on the clock the user reads.
      final w = FastingWindow.at(
        DateTime(2026, 4, 24, 13),
        startHour: 12,
      );
      expect(w.closes.hour, 20);
      expect(w.opens.hour, 12);
    });
  });

  group('meal patterns', () {
    test('counts symptoms without naming a cause', () {
      final p = patternFrom([
        MealFeeling.good,
        MealFeeling.bloating,
        MealFeeling.good,
        MealFeeling.pain,
      ]);
      expect(p.total, 4);
      expect(p.withSymptoms, 2);
      expect(p.anySymptoms, isTrue);
    });

    test('says nothing from too few meals', () {
      // Two data points are not a pattern, and presenting them as one would
      // invite exactly the self-diagnosis the brief rules out.
      expect(patternFrom([MealFeeling.pain]).hasEnoughToSay, isFalse);
      expect(
        patternFrom([MealFeeling.pain, MealFeeling.pain]).hasEnoughToSay,
        isFalse,
      );
      expect(
        patternFrom([MealFeeling.good, MealFeeling.good, MealFeeling.good])
            .hasEnoughToSay,
        isTrue,
      );
    });

    test('good is not a symptom; everything else is', () {
      expect(MealFeeling.good.isSymptom, isFalse);
      for (final f in [
        MealFeeling.bloating,
        MealFeeling.pain,
        MealFeeling.gas,
      ]) {
        expect(f.isSymptom, isTrue, reason: f.name);
      }
    });

    test('every feeling has an Arabic label', () {
      for (final f in MealFeeling.values) {
        expect(f.arabicLabel, isNotEmpty);
        expect(RegExp(r'[a-zA-Z]').hasMatch(f.arabicLabel), isFalse,
            reason: '${f.name} label leaks English');
      }
    });

    test('the enum order is never rearranged', () {
      // Stored by index. Reordering rewrites the user's medical history.
      expect(MealFeeling.values.map((f) => f.name).toList(),
          ['good', 'bloating', 'pain', 'gas']);
    });
  });
}
