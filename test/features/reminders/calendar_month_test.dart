import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/reminders/calendar_month.dart';

void main() {
  test('always 42 cells, so the grid never changes height between months', () {
    // A grid that grew a row in some months would make the whole screen jump
    // as the user pages through it.
    for (var m = 1; m <= 12; m++) {
      expect(MonthGrid.of(2026, m).cells, hasLength(42),
          reason: 'month $m');
    }
  });

  test('the week starts on Saturday, as it does in Egypt and Kuwait', () {
    expect(arabicWeekdayHeadings, hasLength(7));
    expect(arabicWeekdayHeadings.first, 'س');
    expect(arabicWeekdayHeadings.last, 'ج');
  });

  test('the first day lands under the right heading', () {
    // 1 September 2026 is a Tuesday. Saturday-first, Tuesday is column 3.
    expect(DateTime(2026, 9, 1).weekday, DateTime.tuesday);
    expect(MonthGrid.of(2026, 9).cells.indexWhere((c) => c?.day == 1), 3);
  });

  test('a month starting on Saturday wastes no leading row', () {
    // 1 August 2026 is a Saturday.
    expect(DateTime(2026, 8, 1).weekday, DateTime.saturday);
    expect(MonthGrid.of(2026, 8).cells.first?.day, 1);
  });

  test('a month starting on Friday takes the whole leading row', () {
    // 1 May 2026 is a Friday — the last column, Saturday-first.
    expect(DateTime(2026, 5, 1).weekday, DateTime.friday);
    expect(MonthGrid.of(2026, 5).cells.indexWhere((c) => c?.day == 1), 6);
  });

  test('leading cells are empty and every day of the month is present', () {
    final g = MonthGrid.of(2026, 9);
    expect(g.cells.take(3).every((c) => c == null), isTrue);
    expect(g.cells.where((c) => c != null), hasLength(30));
    expect(g.cells.whereType<DateTime>().map((c) => c.day).toList(),
        List.generate(30, (i) => i + 1));
  });

  test('February has 29 days in a leap year and 28 otherwise', () {
    expect(MonthGrid.of(2024, 2).cells.where((c) => c != null), hasLength(29));
    expect(MonthGrid.of(2026, 2).cells.where((c) => c != null), hasLength(28));
  });

  test('a 31-day month starting late still fits in six rows', () {
    // The worst case for a Saturday-first grid: 31 days beginning on a Friday
    // needs 6 leading blanks + 31 = 37 cells. Still inside 42.
    final g = MonthGrid.of(2026, 5);
    expect(g.cells.where((c) => c != null), hasLength(31));
    expect(g.cells, hasLength(42));
  });

  test('cells are midnight local, so they compare equal to a constructed day',
      () {
    final c = MonthGrid.of(2026, 9).cells.firstWhere((c) => c != null)!;
    expect(c, DateTime(c.year, c.month, c.day));
    expect(c.hour, 0);
  });

  test('every cell belongs to the month it was asked for', () {
    final g = MonthGrid.of(2026, 9);
    for (final c in g.cells.whereType<DateTime>()) {
      expect(c.year, 2026);
      expect(c.month, 9);
    }
  });

  group('paging', () {
    test('December rolls into January of the next year', () {
      final g = MonthGrid.of(2026, 12).next;
      expect((g.year, g.month), (2027, 1));
    });

    test('January rolls back into December of the previous year', () {
      final g = MonthGrid.of(2026, 1).previous;
      expect((g.year, g.month), (2025, 12));
    });
  });

  test('the month name is Arabic', () {
    expect(arabicMonthName(9), 'سبتمبر');
    expect(arabicMonthName(1), 'يناير');
    expect(arabicMonthName(12), 'ديسمبر');
  });
}
