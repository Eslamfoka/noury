import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/hijri_date.dart';
import 'package:nouri/features/fasting/sunnah_fasting.dart';

/// Finds the Gregorian date for a Hijri day, by walking outward from a guess.
///
/// The civil Hijri conversion is not a fixed offset, so the tests cannot hard
/// code Gregorian dates for «13 Dhul-Hijjah» and stay true across years. This
/// searches for the day instead, which keeps the tests about the rule rather
/// than about one particular year's arithmetic.
DateTime gregorianForHijri(int month, int day, {required int fromYear}) {
  var probe = DateTime(fromYear, 1, 1);
  for (var i = 0; i < 400 * 3; i++) {
    final h = hijriFor(probe);
    if (h.month == month && h.day == day) return probe;
    probe = DateTime(probe.year, probe.month, probe.day + 1);
  }
  throw StateError('no Gregorian date found for $month/$day');
}

void main() {
  group('the named days', () {
    test('Monday is a sunnah fast', () {
      final monday = DateTime(2026, 9, 7);
      expect(monday.weekday, DateTime.monday);
      expect(sunnahFastFor(monday)?.kinds, contains(SunnahFastKind.monday));
    });

    test('Thursday is a sunnah fast', () {
      final thursday = DateTime(2026, 9, 10);
      expect(thursday.weekday, DateTime.thursday);
      expect(
          sunnahFastFor(thursday)?.kinds, contains(SunnahFastKind.thursday));
    });

    test('an ordinary Wednesday is not', () {
      final wednesday = DateTime(2026, 9, 9);
      expect(wednesday.weekday, DateTime.wednesday);
      final result = sunnahFastFor(wednesday);
      // Unless it happens to be a white day, which is the next test's job.
      if (result != null) {
        expect(result.kinds, [SunnahFastKind.whiteDay]);
      }
    });

    test('the white days are the 13th, 14th and 15th', () {
      for (final d in [13, 14, 15]) {
        // Rajab: month 7, safely away from both Eids.
        final day = gregorianForHijri(7, d, fromYear: 2026);
        expect(sunnahFastFor(day)?.isWhiteDay, isTrue,
            reason: 'Hijri 7/$d should be a white day');
      }
    });

    test('the 12th and 16th are not white days', () {
      for (final d in [12, 16]) {
        final day = gregorianForHijri(7, d, fromYear: 2026);
        final result = sunnahFastFor(day);
        if (result != null) {
          expect(result.isWhiteDay, isFalse,
              reason: 'Hijri 7/$d is not a white day');
        }
      }
    });

    test('a day can be both, and says so', () {
      // Walk a year looking for a Monday or Thursday that is also a white day.
      var found = false;
      var probe = DateTime(2026, 1, 1);
      for (var i = 0; i < 400; i++) {
        final f = sunnahFastFor(probe);
        if (f != null && f.kinds.length > 1) {
          found = true;
          expect(fastingEveBody(f), contains('و'));
          break;
        }
        probe = DateTime(probe.year, probe.month, probe.day + 1);
      }
      expect(found, isTrue, reason: 'such a day happens several times a year');
    });
  });

  group('the days fasting is prohibited', () {
    test('عيد الفطر is never suggested', () {
      final eid = gregorianForHijri(10, 1, fromYear: 2026);
      expect(isFastingProhibited(eid), isTrue);
      expect(sunnahFastFor(eid), isNull,
          reason: 'even if it falls on a Monday');
    });

    test('عيد الأضحى is never suggested', () {
      final eid = gregorianForHijri(12, 10, fromYear: 2026);
      expect(isFastingProhibited(eid), isTrue);
      expect(sunnahFastFor(eid), isNull);
    });

    test('the three days of التشريق are never suggested', () {
      for (final d in [11, 12, 13]) {
        final day = gregorianForHijri(12, d, fromYear: 2026);
        expect(isFastingProhibited(day), isTrue,
            reason: 'Hijri 12/$d is a day of Tashriq');
        expect(sunnahFastFor(day), isNull);
      }
    });

    test('the 13th of ذو الحجة is excluded despite being a white day', () {
      // The trap this whole guard exists for. A naive "13, 14, 15 every
      // month" would have Nouri suggest a forbidden fast once a year.
      final day = gregorianForHijri(12, 13, fromYear: 2026);
      expect(hijriFor(day).day, 13);
      expect(hijriFor(day).month, 12);
      expect(sunnahFastFor(day), isNull);
    });

    test('the 14th and 15th of ذو الحجة are still white days', () {
      for (final d in [14, 15]) {
        final day = gregorianForHijri(12, d, fromYear: 2026);
        expect(sunnahFastFor(day)?.isWhiteDay, isTrue,
            reason: 'Hijri 12/$d is past Tashriq');
      }
    });

    test('an ordinary day is not prohibited', () {
      expect(isFastingProhibited(gregorianForHijri(7, 14, fromYear: 2026)),
          isFalse);
    });
  });

  group('the wording', () {
    test('offers rather than instructs', () {
      final monday = DateTime(2026, 9, 7);
      final body = fastingEveBody(sunnahFastFor(monday)!);
      expect(body, contains('لو حابب'),
          reason: 'Nouri never obliges, least of all about worship');
      expect(body, contains('بكرة'));
      expect(body, contains('الاتنين'));
    });

    test('names the white days in Arabic digits', () {
      final day = gregorianForHijri(7, 14, fromYear: 2026);
      final body = fastingEveBody(sunnahFastFor(day)!);
      expect(body, contains('الأيام البيض'));
      expect(RegExp(r'[0-9]').hasMatch(body), isFalse);
    });
  });

  group('the Hijri offset', () {
    test('shifts which day counts, as the sighting does', () {
      // The user can nudge the civil calculation by a day in Settings, and the
      // fasting days have to move with it or they would disagree with the
      // date shown in the Home header.
      final day = gregorianForHijri(7, 13, fromYear: 2026);
      expect(sunnahFastFor(day)?.isWhiteDay, isTrue);

      final shifted = sunnahFastFor(day, hijriOffsetDays: 1);
      expect(shifted?.isWhiteDay ?? false, isTrue,
          reason: 'with +1 the day before becomes the 14th, still white');

      final backTwo = sunnahFastFor(day, hijriOffsetDays: -1);
      // 13 - 1 = the 12th, no longer a white day.
      expect(backTwo?.isWhiteDay ?? false, isFalse);
    });
  });
}
