import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/format/arabic_numerals.dart';

void main() {
  group('toArabicDigits', () {
    test('converts every western digit', () {
      expect(toArabicDigits('0123456789'), '٠١٢٣٤٥٦٧٨٩');
    });
    test('preserves separators and letters', () {
      expect(toArabicDigits('1:24:10'), '١:٢٤:١٠');
      expect(toArabicDigits('33 من 100'), '٣٣ من ١٠٠');
    });
    test('is a no-op on text with no digits', () {
      expect(toArabicDigits('الفجر'), 'الفجر');
    });
  });

  group('formatCountdown', () {
    test('renders h:mm:ss in Arabic-Indic digits', () {
      expect(
        formatCountdown(const Duration(hours: 1, minutes: 24, seconds: 10)),
        '١:٢٤:١٠',
      );
    });
    test('pads minutes and seconds', () {
      expect(
        formatCountdown(const Duration(hours: 2, minutes: 5, seconds: 3)),
        '٢:٠٥:٠٣',
      );
    });
    test('clamps a negative duration to zero rather than showing a minus', () {
      expect(formatCountdown(const Duration(seconds: -30)), '٠:٠٠:٠٠');
    });
  });

  group('formatClock', () {
    test('renders 12-hour time in Arabic-Indic digits', () {
      expect(formatClock(DateTime(2026, 9, 5, 15, 15)), '٣:١٥');
      expect(formatClock(DateTime(2026, 9, 5, 4, 21)), '٤:٢١');
      expect(formatClock(DateTime(2026, 9, 5, 0, 5)), '١٢:٠٥');
    });
    test('renders western digits when arabic is false', () {
      expect(formatClock(DateTime(2026, 9, 5, 15, 15), arabic: false), '3:15');
    });
  });
}
