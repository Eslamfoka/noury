import '../day_plan.dart';
import '../shift.dart';

/// The parts of a day the AI plan may not put a task in.
///
/// 13 September 2026, after the first real plan came back: «لاحظت ان الخطة
/// لا بتحسب عدد ساعات النوم ولا عدد ساعات الدوام يعني مممكن كل التاسكات في
/// الأوقات بتاع النوم او الدوام». The model had been told the shift as a
/// word and the sleep as a number; it needed the hours, and a rule.
///
/// Two kinds of window, because the brief distinguishes them: **sleep and
/// work are closed** — nothing goes there; **the commute is light-only** —
/// athkar, a lecture by ear, the wird, as §2 of the brief says and as
/// `planDay` already does. Both are stated to the model in the prompt, and
/// both are enforced on the reply in `build_plan.dart`: a task the model
/// puts in a closed window is removed, a heavy task in the commute is
/// removed, and the sheet says how many. Telling the model is a courtesy;
/// checking is the guarantee.
class LockedWindow {
  const LockedWindow({
    required this.label,
    required this.start,
    required this.end,
    this.lightOnly = false,
  });

  /// النوم · الدوام · المواصلات — what the prompt calls it.
  final String label;
  final DateTime start;
  final DateTime end;

  /// True for the commute: a light task may ride it, a heavy one may not.
  final bool lightOnly;

  bool contains(DateTime at) => !at.isBefore(start) && at.isBefore(end);
}

/// The locked windows of one planned day, from the same plan the alarms use.
///
/// The work and commute edges come from the [ShiftPattern] the day was
/// planned with; the sleep from the plan itself, which sized it backwards
/// from the next wake. A day off has no work and no commute; a night shift
/// has its work block crossing midnight, expressed as one window that ends
/// on the next date.
List<LockedWindow> lockedWindowsFor(DayPlan plan) {
  final out = <LockedWindow>[];
  final day = plan.date;
  final shift = plan.shift;
  final midnight = DateTime(day.year, day.month, day.day);

  // The small hours belong to the night before. On a day that starts with a
  // wake, everything from midnight to that wake is last night's sleep — the
  // first real plan put a wird at 02:00, which no window below covered. On
  // a night shift they are last night's duty, still running.
  if (shift.crossesMidnight) {
    final workEnd = shift.workEnd?.on(day);
    final home = shift.homeAgain?.on(day);
    if (workEnd != null && workEnd.isAfter(midnight)) {
      out.add(LockedWindow(label: 'الدوام', start: midnight, end: workEnd));
      if (home != null && home.isAfter(workEnd)) {
        out.add(LockedWindow(
          label: 'المواصلات',
          start: workEnd,
          end: home,
          lightOnly: true,
        ));
      }
    }
  } else if (plan.blocks.isNotEmpty && plan.blocks.first.start.isAfter(midnight)) {
    out.add(LockedWindow(
      label: 'النوم',
      start: midnight,
      end: plan.blocks.first.start,
    ));
  }

  final sleep = plan.sleep;
  if (sleep != null) {
    out.add(LockedWindow(label: 'النوم', start: sleep.start, end: sleep.end));
  }

  final workStart = shift.workStart?.on(day);
  final workEndClock = shift.workEnd;
  if (workStart != null && workEndClock != null) {
    // Tonight's duty, for a night shift; today's, for the others.
    final workEnd = shift.crossesMidnight
        ? workEndClock.on(DateTime(day.year, day.month, day.day + 1))
        : workEndClock.on(day);
    out.add(LockedWindow(label: 'الدوام', start: workStart, end: workEnd));

    final leave = shift.leaveHome?.on(day);
    if (leave != null && leave.isBefore(workStart)) {
      out.add(LockedWindow(
        label: 'المواصلات',
        start: leave,
        end: workStart,
        lightOnly: true,
      ));
    }
    final home = shift.homeAgain?.on(shift.crossesMidnight
        ? DateTime(day.year, day.month, day.day + 1)
        : day);
    if (home != null && home.isAfter(workEnd)) {
      out.add(LockedWindow(
        label: 'المواصلات',
        start: workEnd,
        end: home,
        lightOnly: true,
      ));
    }
  }

  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// Why a task the model proposed was not kept.
enum RemovedReason { inSleep, inWork, heavyInCommute }

/// One proposed task that was removed, and why.
class RemovedTask {
  const RemovedTask({required this.id, required this.at, required this.reason});

  final String id;
  final DateTime at;
  final RemovedReason reason;
}

/// Whether a task at [at] may stand, given the day's windows and whether
/// the task is heavy. Null when it may; the reason when it may not.
RemovedReason? violationFor(
  DateTime at, {
  required List<LockedWindow> windows,
  required bool heavy,
}) {
  for (final w in windows) {
    if (!w.contains(at)) continue;
    if (!w.lightOnly) {
      return w.label == 'النوم' ? RemovedReason.inSleep : RemovedReason.inWork;
    }
    if (heavy) return RemovedReason.heavyInCommute;
  }
  return null;
}
