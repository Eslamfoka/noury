import '../../data/db/nouri_database.dart';

/// Repeat rules for a reminder.
///
/// The drift row [Reminder] is used directly as the domain type — there is no
/// second value class mapped from it. The row carries exactly the fields the
/// rules need, and a mapping layer would be one more place for "09:30" to
/// become something else.
///
/// Every date here is **constructed**, never offset. `DateTime(y, m, d + n)`
/// asks the calendar for a day; `add(Duration(days: n))` asks for n × 24
/// hours, which is a different question on a DST boundary and the reason the
/// pay cycle once moved by an hour. A reminder set for 09:30 means 09:30 on
/// the wall clock, every time it comes round.

/// When [r] fires on its own day.
DateTime reminderFireTime(Reminder r) => DateTime(
      r.onDate.year,
      r.onDate.month,
      r.onDate.day,
      r.minutes ~/ 60,
      r.minutes % 60,
    );

/// The same day-and-minute, moved to [day].
DateTime _atMinuteOn(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// Every time [r] comes round within `[from, to]`, inclusive of both days.
///
/// Never yields anything before the reminder's own date: a weekly reminder
/// created on the 20th did not also exist on the 13th.
List<DateTime> occurrencesOf(
  Reminder r, {
  required DateTime from,
  required DateTime to,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
  if (end.isBefore(start)) return const [];

  final first = DateTime(r.onDate.year, r.onDate.month, r.onDate.day);
  final out = <DateTime>[];

  bool keep(DateTime day) {
    if (day.isBefore(first)) return false;
    final at = _atMinuteOn(day, r.minutes);
    if (at.isBefore(start) || at.isAfter(end)) return false;
    out.add(at);
    return true;
  }

  switch (r.repeat) {
    case ReminderRepeat.once:
      keep(first);

    case ReminderRepeat.daily:
      for (var n = 0;; n++) {
        final day = DateTime(first.year, first.month, first.day + n);
        if (day.isAfter(end)) break;
        keep(day);
      }

    case ReminderRepeat.weekly:
      for (var n = 0;; n++) {
        final day = DateTime(first.year, first.month, first.day + 7 * n);
        if (day.isAfter(end)) break;
        keep(day);
      }

    case ReminderRepeat.monthly:
      // DateTime(2026, 2, 31) does not throw — it rolls over to 3 March. That
      // is exactly what must not happen: a reminder set for the 31st would
      // start firing on the 3rd of the following month, a day the user never
      // chose. Constructing it and checking the day came back unchanged is
      // what makes February skipped rather than slid.
      for (var n = 0;; n++) {
        final probe = DateTime(first.year, first.month + n, 1);
        if (probe.isAfter(end)) break;
        final day = DateTime(first.year, first.month + n, first.day);
        if (day.day != first.day) continue;
        keep(day);
      }
  }

  return out;
}

/// The next time [r] fires strictly after [after], or null if it never will.
///
/// A done reminder has no next occurrence — marking it done is how the user
/// says they have dealt with it, and Nouri does not ask twice.
DateTime? nextOccurrence(Reminder r, {required DateTime after}) {
  if (r.done) return null;

  final first = DateTime(r.onDate.year, r.onDate.month, r.onDate.day);

  // A window wide enough for any repeat to come round at least once: a month
  // has at most 31 days, so 400 days covers even a monthly reminder that has
  // to skip several short months on the way.
  final from = after.isBefore(first) ? first : after;
  final to = DateTime(from.year, from.month, from.day + 400);

  for (final at in occurrencesOf(r, from: from, to: to)) {
    if (at.isAfter(after)) return at;
  }
  return null;
}

/// Whether [r] comes round on [day] — the question the calendar asks, once
/// per cell, to decide where to put a dot.
bool occursOn(Reminder r, DateTime day) =>
    occurrencesOf(r, from: day, to: day).isNotEmpty;
