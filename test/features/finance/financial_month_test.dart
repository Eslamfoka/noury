import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/finance/financial_month.dart';

void main() {
  group('FinancialMonth.containing', () {
    test('after payday, the cycle starts this month', () {
      final m = FinancialMonth.containing(DateTime(2026, 9, 28), startDay: 25);
      expect(m.start, DateTime(2026, 9, 25));
      expect(m.end, DateTime(2026, 10, 24));
    });

    test('before payday, the cycle started last month', () {
      final m = FinancialMonth.containing(DateTime(2026, 9, 6), startDay: 25);
      expect(m.start, DateTime(2026, 8, 25));
      expect(m.end, DateTime(2026, 9, 24));
    });

    test('payday itself begins a new cycle', () {
      final m = FinancialMonth.containing(DateTime(2026, 9, 25), startDay: 25);
      expect(m.start, DateTime(2026, 9, 25));
    });

    test('the day before payday still belongs to the old cycle', () {
      final m = FinancialMonth.containing(DateTime(2026, 9, 24), startDay: 25);
      expect(m.start, DateTime(2026, 8, 25));
      expect(m.end, DateTime(2026, 9, 24));
    });

    test('cycles are contiguous with no gap or overlap', () {
      final a = FinancialMonth.containing(DateTime(2026, 9, 24), startDay: 25);
      final b = FinancialMonth.containing(DateTime(2026, 9, 25), startDay: 25);
      expect(b.start.difference(a.end).inDays, 1);
    });

    test('a December cycle rolls into January correctly', () {
      final m = FinancialMonth.containing(DateTime(2026, 12, 28), startDay: 25);
      expect(m.start, DateTime(2026, 12, 25));
      expect(m.end, DateTime(2027, 1, 24));
    });

    test('a January date before payday reaches back into December', () {
      final m = FinancialMonth.containing(DateTime(2027, 1, 3), startDay: 25);
      expect(m.start, DateTime(2026, 12, 25));
    });

    test('a start day past 28 is clamped so February still works', () {
      // The 30th does not exist in February; without clamping the cycle would
      // silently shift or repeat.
      final m = FinancialMonth.containing(DateTime(2026, 2, 10), startDay: 31);
      expect(m.startDay, 28);
      expect(m.start.day, 28);
    });

    test('every day of the year falls in exactly one cycle', () {
      // Walks calendar dates rather than adding Durations: Egypt shifts the
      // clock twice a year, and 24-hour steps drift across the boundary.
      for (var month = 1; month <= 12; month++) {
        for (var d = 1; d <= 28; d++) {
          final day = DateTime(2026, month, d);
          final m = FinancialMonth.containing(day, startDay: 25);
          expect(m.contains(day), isTrue, reason: '$day');
        }
      }
    });

    test('cycle length survives a daylight-saving transition', () {
      // Egypt's clocks move on 24 April 2026, inside this cycle.
      final m = FinancialMonth.containing(DateTime(2026, 4, 10), startDay: 25);
      expect(m.start, DateTime(2026, 3, 25));
      expect(m.end, DateTime(2026, 4, 24));
      expect(m.totalDays, 31, reason: '25 March to 24 April inclusive');
    });

    test('the label names both ends in Arabic-Indic digits', () {
      final m = FinancialMonth.containing(DateTime(2026, 9, 6), startDay: 25);
      expect(RegExp(r'[0-9]').hasMatch(m.label), isFalse, reason: m.label);
      expect(m.label, contains('أغسطس'));
      expect(m.label, contains('سبتمبر'));
    });
  });

  group('days elapsed and remaining', () {
    final month = FinancialMonth.containing(DateTime(2026, 9, 6), startDay: 25);

    test('the first day counts as one, not zero', () {
      expect(month.daysElapsed(DateTime(2026, 8, 25)), 1);
    });

    test('elapsed and remaining always sum to the cycle length', () {
      for (final d in [
        DateTime(2026, 8, 25),
        DateTime(2026, 9, 6),
        DateTime(2026, 9, 24),
      ]) {
        expect(month.daysElapsed(d) + month.daysRemaining(d), month.totalDays);
      }
    });

    test('a date outside the cycle clamps rather than going negative', () {
      expect(month.daysElapsed(DateTime(2026, 12, 1)), month.totalDays);
      expect(month.daysRemaining(DateTime(2026, 12, 1)), 0);
    });
  });

  group('BudgetStatus', () {
    final month = FinancialMonth.containing(DateTime(2026, 9, 6), startDay: 25);

    BudgetStatus status(int limit, int spent, DateTime now) =>
        BudgetStatus(limit: limit, spent: spent, month: month, now: now);

    test('reports what is left', () {
      final s = status(100, 30, DateTime(2026, 9, 6));
      expect(s.remaining, 70);
      expect(s.isOver, isFalse);
    });

    test('going over is reported without clamping the fraction past one', () {
      final s = status(100, 130, DateTime(2026, 9, 6));
      expect(s.isOver, isTrue);
      expect(s.remaining, -30);
      expect(s.fraction, 1.0);
    });

    test('the same spend reads differently early and late in the cycle', () {
      // 60% spent is worth flagging on day 4 and unremarkable on day 25.
      final early = status(100, 60, DateTime(2026, 8, 28));
      final late = status(100, 60, DateTime(2026, 9, 20));
      expect(early.isAheadOfPace, isTrue);
      expect(late.isAheadOfPace, isFalse);
    });

    test('a category over its limit is not also flagged as merely ahead', () {
      final s = status(100, 200, DateTime(2026, 8, 28));
      expect(s.isOver, isTrue);
      expect(s.isAheadOfPace, isFalse,
          reason: 'over the limit is a stronger statement than ahead of pace');
    });

    test('a zero limit does not divide by zero', () {
      final s = status(0, 50, DateTime(2026, 9, 6));
      expect(s.fraction, 0);
      expect(s.isOver, isTrue);
    });
  });
}
