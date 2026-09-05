import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/hijri_date.dart';

void main() {
  test('converts a Gregorian date to Hijri', () {
    final h = hijriFor(DateTime(2026, 9, 5));
    expect(h.year, inInclusiveRange(1447, 1448));
    expect(h.day, inInclusiveRange(1, 30));
    expect(h.monthName, isNotEmpty);
  });

  test('month names come back in Arabic', () {
    final h = hijriFor(DateTime(2026, 9, 5));
    expect(RegExp(r'[؀-ۿ]').hasMatch(h.monthName), isTrue,
        reason: 'month name must be Arabic, got "${h.monthName}"');
  });

  test('a positive offset moves the Hijri date forward', () {
    final base = hijriFor(DateTime(2026, 9, 5));
    final plus = hijriFor(DateTime(2026, 9, 5), offsetDays: 1);
    expect(plus.day == base.day + 1 || plus.day == 1, isTrue,
        reason: 'either the next day, or the first of the next month');
  });

  test('a negative offset moves it backward', () {
    final base = hijriFor(DateTime(2026, 9, 5));
    final minus = hijriFor(DateTime(2026, 9, 5), offsetDays: -1);
    expect(minus.day == base.day - 1 || minus.day >= 29, isTrue);
  });

  test('a zero offset changes nothing', () {
    final a = hijriFor(DateTime(2026, 9, 5));
    final b = hijriFor(DateTime(2026, 9, 5), offsetDays: 0);
    expect(b.formatted, a.formatted);
  });

  test('formatted string carries Arabic-Indic digits only', () {
    final f = hijriFor(DateTime(2026, 9, 5)).formatted;
    expect(RegExp(r'[0-9]').hasMatch(f), isFalse, reason: f);
    expect(f, contains('هـ'));
  });

  test('conversion is stable across repeated calls', () {
    // The underlying package keeps locale in a static, so a second call must
    // not drift or pick up a different language.
    final first = hijriFor(DateTime(2026, 9, 5)).formatted;
    final second = hijriFor(DateTime(2026, 9, 5)).formatted;
    expect(second, first);
  });
}
