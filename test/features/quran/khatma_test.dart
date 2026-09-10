import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/quran/khatma.dart';

void main() {
  test('reports a fraction of the full mushaf', () {
    const k = KhatmaProgress(pagesRead: 302, totalPages: 604);
    expect(k.fraction, closeTo(0.5, 0.001));
    expect(k.percentLabel, '٥٠٪');
  });

  test('a fresh khatma is zero, not an error', () {
    const k = KhatmaProgress(pagesRead: 0, totalPages: 604);
    expect(k.fraction, 0.0);
    expect(k.percentLabel, '٠٪');
    expect(k.isComplete, isFalse);
  });

  test('reading beyond a full khatma clamps and reports completion', () {
    const k = KhatmaProgress(pagesRead: 700, totalPages: 604);
    expect(k.fraction, 1.0);
    expect(k.isComplete, isTrue);
    expect(k.percentLabel, '١٠٠٪');
  });

  test('a zero-page mushaf does not divide by zero', () {
    const k = KhatmaProgress(pagesRead: 3, totalPages: 0);
    expect(k.fraction, 0.0);
  });

  test('the percent label carries no western digits', () {
    for (final pages in [0, 1, 57, 302, 604]) {
      final label = KhatmaProgress(pagesRead: pages, totalPages: 604)
          .percentLabel;
      expect(RegExp(r'[0-9]').hasMatch(label), isFalse, reason: label);
    }
  });

  test('a rub is three pages by default', () {
    expect(kDailyWirdPages, 3);
  });

  test('the default mushaf is 604 pages', () {
    expect(kDefaultKhatmaPages, 604);
  });
}
