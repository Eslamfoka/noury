import '../../core/format/arabic_numerals.dart';
import '../../core/time/date_formats.dart';

/// Nouri's month runs from payday, not from the 1st.
///
/// The brief is explicit: the salary lands between the 20th and the 25th, so
/// a calendar month would split every pay cycle in two and make "how much is
/// left" meaningless. A financial month starting on payday answers the
/// question the user actually asks.
class FinancialMonth {
  const FinancialMonth({
    required this.start,
    required this.end,
    required this.startDay,
  });

  /// First day of the cycle, inclusive.
  final DateTime start;

  /// Last day of the cycle, inclusive.
  final DateTime end;

  final int startDay;

  int get totalDays => _daysBetween(start, end) + 1;

  int daysElapsed(DateTime now) =>
      (_daysBetween(start, now) + 1).clamp(1, totalDays);

  int daysRemaining(DateTime now) => totalDays - daysElapsed(now);

  bool contains(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  /// e.g. «٢٥ أغسطس — ٢٤ سبتمبر»
  String get label {
    final s = formatGregorianLong(start).split('، ').last;
    final e = formatGregorianLong(end).split('، ').last;
    // Drop the year from the first half; the two are nearly always adjacent.
    final startShort = s.split(' ').take(2).join(' ');
    final endShort = e.split(' ').take(2).join(' ');
    return toArabicDigits('$startShort — $endShort');
  }

  /// The cycle containing [day].
  ///
  /// [startDay] is clamped to 1–28 so February can never produce a month that
  /// skips or repeats: a start day of 30 would simply not exist in February.
  static FinancialMonth containing(DateTime day, {required int startDay}) {
    final anchor = startDay.clamp(1, 28);
    final d = DateTime(day.year, day.month, day.day);

    // If we are before this month's payday, the cycle began last month.
    final start = d.day >= anchor
        ? DateTime(d.year, d.month, anchor)
        : DateTime(d.year, d.month - 1, anchor);

    // Calendar arithmetic, never Duration arithmetic: subtracting 24 hours
    // across a DST boundary lands on the wrong day. Passing day 0 to DateTime
    // rolls back to the last day of the previous month, which is exactly what
    // "the day before payday" means.
    final nextStart = DateTime(start.year, start.month + 1, anchor);
    final end = DateTime(nextStart.year, nextStart.month, nextStart.day - 1);

    return FinancialMonth(start: start, end: end, startDay: anchor);
  }
}

/// Whole days between two dates, immune to daylight-saving transitions.
///
/// `a.difference(b).inDays` counts 24-hour blocks, so a cycle spanning a DST
/// change is off by one — and Egypt, where this was first run, shifts the
/// clock twice a year. Comparing the dates in UTC removes the hours entirely.
int _daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// What is left, and whether that is on track.
class BudgetStatus {
  const BudgetStatus({
    required this.limit,
    required this.spent,
    required this.month,
    required this.now,
  });

  final int limit;
  final int spent;
  final FinancialMonth month;
  final DateTime now;

  int get remaining => limit - spent;

  double get fraction => limit == 0 ? 0 : (spent / limit).clamp(0.0, 1.0);

  bool get isOver => spent > limit;

  /// What could have been spent by today at an even rate.
  ///
  /// This is what makes an alert useful rather than alarming: spending 60% of
  /// the food budget is fine on day 18 and worth noticing on day 4.
  double get pacedAllowance =>
      limit * (month.daysElapsed(now) / month.totalDays);

  /// Ahead of an even pace, but not yet over the limit.
  bool get isAheadOfPace => !isOver && spent > pacedAllowance;
}
