import '../../core/time/prayer_times_service.dart';
import '../../data/db/tables.dart';
import '../prayers/prayer_names.dart';
import 'task_status.dart';

/// The five prayers as **one** line of المهام, at twenty percent each.
///
/// The user asked for exactly this on 13 September 2026:
///
///   «عايز اخلي الصلاه ككل الخمس فروض في قايمة المهام وتنقسم بنسب في المية
///    يعني لو صليت الفجر وعلمت عليها تبقى ٢٠٪ الضهر كمان ٤٠٪ وهكذا لحد
///    العشا ١٠٠٪»
///
/// One line rather than five, because the list is meant to answer "what is
/// left" without becoming the long checklist the brief warns against — and
/// because the day's prayers *are* one thing that fills in through the day.
///
/// **Prayed, not graded.** The percentage counts prayers that happened; the
/// score on Home grades how. A late prayer is twenty percent like any other.
/// «فاتتني» is marked but not prayed, so it moves nothing — a day with one
/// missed prayer ends at eighty, which is the honest number, and its status is
/// «لسه» like every other unfinished task, never a word that names a failure.
///
/// **Derived, never stored.** Everything here is read off the same prayer log
/// Home writes, so there is still exactly one place the truth lives.
class PrayersLine {
  const PrayersLine({
    required this.slots,
    required this.status,
    required this.showAt,
  });

  /// The five, in the order they fall, each with its logged state.
  final List<PrayerSlotState> slots;

  final TaskStatus status;

  /// Where the line sorts among the day's tasks: at fajr, the start of the
  /// day it spans.
  final DateTime showAt;

  /// The id the screen keys on. A prefix no planned task uses.
  static const taskId = 'prayers';

  int get prayed => slots.where((s) => s.prayed).length;

  /// 0, 20, 40, 60, 80 or 100.
  int get percent => prayed * 100 ~/ slots.length;

  double get fraction => prayed / slots.length;

  bool get isDone => status == TaskStatus.done;

  /// The prayer to pray next: the earliest that has entered and has not been
  /// prayed, or null when none has.
  ///
  /// Earliest rather than current, deliberately. A fajr left open at noon is
  /// still the first thing to make up, and pointing at dhuhr instead would be
  /// the list forgetting about it.
  String? get nextToPray {
    for (final s in slots) {
      if (s.entered && !s.prayed) return s.prayer;
    }
    return null;
  }
}

/// One prayer's place on the line.
class PrayerSlotState {
  const PrayerSlotState({
    required this.prayer,
    required this.time,
    required this.state,
    required this.entered,
  });

  final String prayer;
  final DateTime time;
  final PrayerState state;

  /// Whether its time has come.
  final bool entered;

  /// Logged as prayed — in any of the four prayed states. «فاتتني» is logged
  /// but not prayed, and «لسه» is neither.
  bool get prayed => state != PrayerState.none && state != PrayerState.missed;

  String get arabicName => arabicPrayerName(prayer);
}

/// Today's prayers as a line, from the day's times, the log and a clock.
///
/// Pure, like `taskLinesFor` — no database and no providers, so every status
/// below is testable by stating three values.
PrayersLine prayersLineFor({
  required DailyPrayerTimes times,
  required Map<String, PrayerState> logs,
  required DateTime now,
}) {
  final slots = [
    for (final slot in times.ordered)
      PrayerSlotState(
        prayer: slot.name,
        time: slot.time,
        state: logs[slot.name] ?? PrayerState.none,
        entered: !slot.time.isAfter(now),
      ),
  ];

  return PrayersLine(
    slots: slots,
    status: _statusFor(slots, now: now, fajr: times.fajr),
    showAt: times.fajr,
  );
}

TaskStatus _statusFor(
  List<PrayerSlotState> slots, {
  required DateTime now,
  required DateTime fajr,
}) {
  // Done outranks the clock, as it does for every task.
  if (slots.every((s) => s.prayed)) return TaskStatus.done;

  if (now.isBefore(fajr)) return TaskStatus.upcoming;

  // «دلوقتي» while the prayer whose time it is has not been logged at all —
  // the same gold edge a task carries for the length of its own window. A
  // prayer logged as anything, «فاتتني» included, has been answered, and the
  // line stops standing out for it.
  PrayerSlotState? current;
  for (final s in slots) {
    if (s.entered) current = s;
  }
  if (current != null && current.state == PrayerState.none) {
    return TaskStatus.due;
  }

  // Something earlier is still open, or the next prayer has not come yet.
  // Either way: «لسه». The day is not over.
  return TaskStatus.open;
}
