import 'notification_slot.dart';
import 'task_alarm_ids.dart';

/// What the device is *actually* holding, read back rather than assumed.
///
/// **Why this exists.** On 10 September 2026 the user's phone held 137 alarms
/// with nothing at all armed for the following four days — no adhan, no iqama
/// — and every screen in Nouri looked completely normal. The app could tell
/// him whether the permissions were granted and could not tell him that the
/// thing those permissions exist for had gone missing. The cause is fixed; the
/// blindness is what this addresses, because the next cause will be different.
///
/// **Reach is the wrong thing to measure.** His window still ran to the 23rd.
/// The hole was at the near end, which is where an interrupted cancel pass
/// leaves one. So the question worth asking is not "how far does it go" but
/// "is there a day between here and there with nothing in it".
class ArmedWindow {
  const ArmedWindow({required this.count, required this.days});

  /// How many rolling-window alarms are armed.
  ///
  /// Reminders, snoozes and task alarms are deliberately excluded: they live
  /// in their own id ranges, cover different spans, and counting them would
  /// let a handful of reminders make a gutted prayer window look populated.
  final int count;

  /// The days those alarms fall on, midnight local.
  final Set<DateTime> days;

  /// The last day anything is armed for, or null when nothing is.
  DateTime? get coversThrough {
    if (days.isEmpty) return null;
    return days.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// How many days past [today] the window still reaches.
  ///
  /// Never negative: a window left entirely in the past reaches zero days
  /// ahead, which is the true statement. "Minus four" would be arithmetic
  /// leaking into a sentence a person has to read.
  int daysAhead(DateTime today) {
    final last = coversThrough;
    if (last == null) return 0;
    final t = DateTime(today.year, today.month, today.day);
    final diff = last.difference(t).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Days between tomorrow and [coversThrough] that hold nothing at all.
  ///
  /// **Tomorrow, not today.** Today's alarms are consumed as the day passes,
  /// so by the evening today legitimately holds none of its own — treating
  /// that as a fault would put a warning in front of every user every night.
  ///
  /// **Bounded by what is armed.** A window that stops at the 16th has no gap
  /// on the 17th; it simply does not reach that far, which is a different and
  /// milder statement. Inventing gaps past the end would turn "you have a
  /// week armed" into an alarming list of eight dates.
  List<DateTime> gapsAfter(DateTime today) {
    final last = coversThrough;
    if (last == null) return const [];

    final out = <DateTime>[];
    // Constructed, never offset — `add(Duration(days: 1))` is 24 hours, which
    // lands on the same date across a DST boundary and would report a
    // phantom gap once a year.
    for (var d = DateTime(today.year, today.month, today.day + 1);
        !d.isAfter(last);
        d = DateTime(d.year, d.month, d.day + 1)) {
      if (!days.contains(d)) out.add(d);
    }
    return out;
  }
}

/// Reads [ids] — what the plugin reports as pending — back into a window.
///
/// Pure, so the whole reading can be tested without a device. The ids carry
/// their own dates: the window numbers an alarm `daysSince2020 * kSlotsPerDay
/// + slot`, which is the same property that lets a re-arm land on exactly the
/// same ids after a reboot with no stored state.
ArmedWindow armedWindowFrom(Iterable<int> ids) {
  final days = <DateTime>{};
  var count = 0;

  for (final id in ids) {
    // Everything at or above the task base belongs to another range —
    // task alarms, reminders, snoozes. See `task_alarm_ids.dart` for the map.
    if (id < 0 || id >= kTaskAlarmIdBase) continue;
    count++;
    days.add(dateOfNotificationId(id));
  }

  return ArmedWindow(count: count, days: days);
}
