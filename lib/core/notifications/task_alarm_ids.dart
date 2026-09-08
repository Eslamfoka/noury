/// The notification ID spaces the task alarms and their snoozes live in.
///
/// Kept free of any plugin import, like `notification_channels_ids.dart` and
/// `reminder_ids.dart`, so the scheduler and its tests can reason about IDs
/// without pulling in a platform channel.
///
/// There are three disjoint ranges, and which side of `kOutOfWindowIdBase` a
/// thing sits on decides whether a re-arm wipes it:
///
/// | range | from | cleared by a re-arm? |
/// |---|---|---|
/// | the rolling window | ~156,000, climbing | yes — that is the point |
/// | **task alarms** | 500,000,000 | **yes**, deliberately |
/// | reminders | 900,000,000 | no |
/// | **snoozes** | 950,000,000 | **no**, deliberately |
///
/// Task alarms *want* to be cleared: the plan is recomputed on every launch,
/// so yesterday's arrangement must not survive into today's. A snooze must
/// *not* be — the user pressed it deliberately, and opening the app afterwards
/// would otherwise silently take it away.
library;

import 'task_alert.dart';

/// The floor of the task-alarm range.
///
/// The window numbers its alarms `daysSince2020 * 64 + slot`: about 156,000
/// today, climbing ~23,400 a year, so it does not reach this base for some
/// twenty thousand years. Below `kOutOfWindowIdBase`, so `cancelAllBelow`
/// clears these on every re-arm without touching a reminder.
const kTaskAlarmIdBase = 500000000;

/// The floor of the snooze range.
///
/// **Above** the reminder base on purpose, so `cancelAllBelow` spares it. A
/// snooze is one-shot: it fires once and is gone, so nothing has to clean the
/// range up. Leaving it inside the window's range would mean that opening the
/// app after pressing «فكّرني بعد ٥ دقايق» cancelled the very thing just asked
/// for.
const kSnoozeIdBase = 950000000;

/// How many ids one day of task alarms may use.
///
/// Two per alarmable task — the alert and the question that may follow it —
/// with room to double the list before days start overlapping.
const _idsPerDay = 128;

/// A task alarm's id, derived purely from the date and the **task id**.
///
/// Reproducible from those two alone, which is the reliability strategy the
/// whole notification layer uses: re-arming from a cold start lands on exactly
/// the same ids and overwrites rather than duplicating.
///
/// Keyed on the task, **not** on the alert kind. Several tasks share a kind —
/// both meals, and all three faces of knowledge time — so keying on the kind
/// gave أول وجبة and آخر وجبة the same id and the later one silently
/// overwrote the earlier. The first meal of the day was simply never
/// announced. A test now asserts every armed id is distinct.
///
/// Returns null for a task with no place in [alarmableTaskIds], which is how
/// an id from a future version of the app fails safely rather than colliding
/// with something real.
///
/// [ask] distinguishes the «عملتها؟» that follows from the alert itself, so
/// marking a task done can cancel the question without touching the alert.
int? taskAlarmId(DateTime date, String taskId, {bool ask = false}) {
  final index = alarmableTaskIds.indexOf(taskId);
  if (index < 0) return null;

  final days = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(2020, 1, 1))
      .inDays;
  return kTaskAlarmIdBase + days * _idsPerDay + index * 2 + (ask ? 1 : 0);
}

bool isTaskAlarmId(int id) => id >= kTaskAlarmIdBase && id < kSnoozeIdBase;
