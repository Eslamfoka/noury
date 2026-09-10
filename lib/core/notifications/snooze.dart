import 'notification_slot.dart';
import 'task_alarm_ids.dart';
import 'task_alert.dart';

/// How long «فكّرني بعد شوية» puts a task off for.
///
/// Five minutes, as asked: *"i can late it 5 mins many times"*.
const kSnoozeMinutes = 5;

/// The action id on a task notification.
///
/// **This action deliberately does not open the app.** `showsUserInterface:
/// false` routes the tap to a background isolate, which is the only way to
/// snooze without dragging the user into a screen they did not ask for.
///
/// That is also the trap this project has already fallen into once. The
/// «صليت» action was written that way and **no background handler was ever
/// registered**, so the button did nothing at all — see the note in
/// `local_notification_gateway.dart`. The handler is registered this time, and
/// a test asserts the registration exists.
const actionSnooze = 'snooze';

/// When a snooze pressed at [from] should land.
///
/// Computed from *now*, not from the alert's original time, so pressing it
/// twice puts the task off by ten minutes rather than five. "Many times" only
/// means something if they accumulate.
DateTime snoozedTime({required DateTime from}) =>
    from.add(const Duration(minutes: kSnoozeMinutes));

/// The notification id a snoozed task uses, or null for a task Nouri does not
/// number.
///
/// **One per task, with no date in it.** Snoozing the same task again
/// overwrites the pending snooze rather than stacking a second one, which is
/// what "put it off another five minutes" means — two alarms five minutes
/// apart would be the app nagging.
///
/// Sits above [kOutOfWindowIdBase] so `cancelAllBelow` spares it. Opening the
/// app re-arms the whole window, and if a snooze lived below that floor the
/// act of opening Nouri would cancel the very thing the user had just asked
/// for. A snooze is one-shot — it fires once and is gone — so nothing has to
/// clean the range up afterwards.
int? snoozeIdFor(String taskId) {
  final index = alarmableTaskIds.indexOf(taskId);
  return index < 0 ? null : kSnoozeIdBase + index;
}

/// The notification a snooze should schedule, or null when the task is not one
/// Nouri knows how to raise.
///
/// Keeps the task's **own** sound. A snoozed walk that came back as a generic
/// ping would undo the whole point of the exercise — the user would no longer
/// know what was calling without looking.
ScheduledNotification? snoozedNotification({
  required String taskId,
  required DateTime from,
}) {
  final kind = alertKindForTaskId(taskId);
  final id = snoozeIdFor(taskId);
  if (kind == null || id == null) return null;

  return ScheduledNotification(
    id: id,
    // A label only, like the task alarms themselves: the id comes from the
    // snooze range, not from a date and slot.
    slot: NotificationSlot.taskAlert,
    when: snoozedTime(from: from),
    title: kind.title,
    body: kind.body,
    channelId: kind.channelId,
    payload: 'task:$taskId',
  );
}

/// The task id inside a `task:` payload, or null for anything else.
///
/// Never throws on an unrecognised payload. A notification armed by an older
/// build of Nouri can still be sitting in AlarmManager days later, and the
/// background isolate is the worst place to discover an exception.
String? taskIdFromPayload(String? payload) {
  if (payload == null || !payload.startsWith('task:')) return null;
  final id = payload.substring('task:'.length);
  return id.isEmpty ? null : id;
}
