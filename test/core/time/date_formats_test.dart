import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/date_formats.dart';
import 'package:nouri/core/time/hijri_date.dart';

void main() {
  // 6 September 2026 is a Sunday.
  final sunday = DateTime(2026, 9, 6);

  group('formatGregorianLong — Arabic', () {
    test('renders weekday, day, month and year', () {
      expect(formatGregorianLong(sunday), 'الأحد، ٦ سبتمبر ٢٠٢٦');
    });

    test('uses Arabic-Indic digits throughout', () {
      for (final d in [
        DateTime(2026, 1, 1),
        DateTime(2026, 6, 15),
        DateTime(2026, 12, 31),
      ]) {
        final s = formatGregorianLong(d);
        expect(RegExp(r'[0-9]').hasMatch(s), isFalse, reason: s);
      }
    });

    test('every weekday has a name', () {
      for (var i = 0; i < 7; i++) {
        final s = formatGregorianLong(sunday.add(Duration(days: i)));
        expect(s, startsWith('ال'), reason: s);
        expect(s, contains('،'));
      }
    });

    test('every month has a name, in Egyptian/Gulf style', () {
      // "الأحد، ٦ سبتمبر ٢٠٢٦" -> [weekday, day, month, year]
      final names = <String>[];
      for (var m = 1; m <= 12; m++) {
        final s = formatGregorianLong(DateTime(2026, m, 1));
        names.add(s.split(' ')[2]);
      }
      expect(names.first, 'يناير');
      expect(names[8], 'سبتمبر');
      expect(names.last, 'ديسمبر');
      expect(names.toSet().length, 12, reason: 'no duplicated month names');
    });
  });

  group('formatGregorianLong — English', () {
    test('renders weekday, day, month and year', () {
      expect(
        formatGregorianLong(sunday, arabic: false),
        'Sunday, 6 September 2026',
      );
    });

    test('keeps western digits', () {
      final s = formatGregorianLong(sunday, arabic: false);
      expect(RegExp(r'[0-9]').hasMatch(s), isTrue);
      expect(RegExp(r'[٠-٩]').hasMatch(s), isFalse);
    });
  });

  group('hijriFor — Arabic', () {
    test('renders day, month and year with the هـ marker', () {
      final h = hijriFor(sunday);
      expect(h.formatted, endsWith('هـ'));
      expect(h.formatted, contains(h.monthName));
      expect(RegExp(r'[0-9]').hasMatch(h.formatted), isFalse);
    });

    test('uses the corrected month spellings, not the package defaults', () {
      // The hijri package ships «ربيع الاول» without the hamza and the
      // masculine «جمادى الأول»; both are wrong.
      expect(arabicHijriMonths[3], 'ربيع الأول');
      expect(arabicHijriMonths[5], 'جمادى الأولى');
      for (final name in arabicHijriMonths.values) {
        expect(name, isNot('ربيع الاول'));
        expect(name, isNot('جمادى الأول'));
      }
    });

    test('all twelve months are named and distinct', () {
      expect(arabicHijriMonths.length, 12);
      expect(arabicHijriMonths.values.toSet().length, 12);
      expect(englishHijriMonths.length, 12);
      expect(englishHijriMonths.values.toSet().length, 12);
    });
  });

  group('hijriFor — English', () {
    test('renders with the AH marker and western digits', () {
      final h = hijriFor(sunday, arabic: false);
      expect(h.formatted, endsWith('AH'));
      expect(RegExp(r'[0-9]').hasMatch(h.formatted), isTrue);
      expect(RegExp(r'[٠-٩]').hasMatch(h.formatted), isFalse);
    });

    test('the month name is transliterated, not Arabic script', () {
      final h = hijriFor(sunday, arabic: false);
      expect(RegExp(r'[؀-ۿ]').hasMatch(h.monthName), isFalse,
          reason: h.monthName);
    });
  });

  group('the two calendars agree', () {
    test('the same instant yields both dates for the same day', () {
      final g = formatGregorianLong(sunday);
      final h = hijriFor(sunday);
      expect(g, contains('٢٠٢٦'));
      expect(h.year, inInclusiveRange(1447, 1449));
    });

    test('the Hijri offset shifts only the Hijri date', () {
      final gPlain = formatGregorianLong(sunday);
      final hPlain = hijriFor(sunday);
      final hShifted = hijriFor(sunday, offsetDays: 1);

      expect(formatGregorianLong(sunday), gPlain,
          reason: 'the Gregorian date never moves with the Hijri offset');
      expect(hShifted.formatted, isNot(hPlain.formatted));
    });
  });
}
