/// The month-grid maths, kept pure and separate from the widget.
///
/// An off-by-one in the leading blanks is the classic calendar bug and it is
/// invisible in a screenshot — every day simply sits under the wrong heading.
/// So the arithmetic lives here, where it can be tested, and the widget only
/// renders what it is handed.
library;

/// Weekday headings, **Saturday first** — the week as it runs in Egypt and
/// Kuwait, not the Monday-first week Dart's [DateTime.weekday] counts in.
const arabicWeekdayHeadings = <String>['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

const _arabicMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'إبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String arabicMonthName(int month) => _arabicMonths[month - 1];

/// A six-row, seven-column month grid. Cells outside the month are null.
///
/// Always 42 cells, even when the month would fit in five rows. A grid that
/// grew and shrank a row would make the whole screen jump as the user pages
/// through the year.
class MonthGrid {
  const MonthGrid({
    required this.year,
    required this.month,
    required this.cells,
  });

  final int year;
  final int month;

  /// Exactly 42 entries, in reading order for a Saturday-first week.
  final List<DateTime?> cells;

  static const rows = 6;
  static const columns = 7;

  factory MonthGrid.of(int year, int month) {
    final first = DateTime(year, month, 1);

    // Dart counts Monday = 1 … Sunday = 7. Saturday-first means Saturday
    // must map to column 0, Sunday to 1, and Monday to 2:
    //   Saturday  6 -> 0, Sunday 7 -> 1, Monday 1 -> 2 … Friday 5 -> 6.
    final lead = (first.weekday + 1) % 7;

    // Day 0 of the next month is the last day of this one — the standard way
    // to get a month's length without a table or a leap-year rule.
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final cells = List<DateTime?>.filled(rows * columns, null);
    for (var d = 1; d <= daysInMonth; d++) {
      cells[lead + d - 1] = DateTime(year, month, d);
    }
    return MonthGrid(year: year, month: month, cells: cells);
  }

  /// Constructed, not offset: `DateTime(year, month + 1, 1)` rolls the year
  /// over on its own, and December + 1 is January of the next year.
  MonthGrid get next {
    final d = DateTime(year, month + 1, 1);
    return MonthGrid.of(d.year, d.month);
  }

  MonthGrid get previous {
    final d = DateTime(year, month - 1, 1);
    return MonthGrid.of(d.year, d.month);
  }

  String get label => '${arabicMonthName(month)} $year';

  /// The first and last day of the month, for a range query.
  DateTime get firstDay => DateTime(year, month, 1);
  DateTime get lastDay => DateTime(year, month + 1, 0);
}
