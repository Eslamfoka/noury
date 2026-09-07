import '../../core/notifications/notification_channels_ids.dart';
import '../../core/notifications/notification_gateway.dart';
import '../../core/notifications/notification_slot.dart';
import '../../data/db/nouri_database.dart';
import 'reminder.dart';
import 'reminder_ids.dart';

/// Arms the reminders the user wrote against days on the calendar.
///
/// Deliberately **not** part of [RollingWindowScheduler]. The window's job is
/// to keep a fortnight of prayer alarms alive without the app being opened;
/// reminders are user-authored, change one at a time, and are numbered in a
/// disjoint ID range so neither can cancel the other.
///
/// Only the *next* occurrence of each reminder is armed, never the whole
/// series. A daily reminder armed for a year would cost 365 alarms on its own
/// and push the app past Android's ~500 pending cap, which would start
/// dropping adhan alarms — the one thing that must never happen. The next
/// occurrence is re-armed whenever the app re-arms, which is every launch and
/// every settings change.
class ReminderScheduler {
  ReminderScheduler(this._gateway);

  final NotificationGateway _gateway;

  /// The body shown when a reminder has no note of its own.
  ///
  /// Never empty: an Android notification with a blank body renders as a bare
  /// title with dead space under it, which reads like a bug.
  static const _defaultBody = 'ده اللي طلبت أفكّرك بيه.';

  /// Arms the next occurrence of every reminder in [reminders].
  ///
  /// Safe to call repeatedly. IDs are derived from the row id, so a second
  /// call overwrites the first rather than stacking a duplicate alarm.
  Future<void> arm(List<Reminder> reminders, {DateTime? now}) async {
    final at = now ?? DateTime.now();

    for (final r in reminders) {
      final next = nextOccurrence(r, after: at);
      if (next == null) continue;

      await _gateway.schedule(ScheduledNotification(
        id: reminderNotificationId(r.id),
        // Reminders live outside the day/slot scheme entirely, so the slot is
        // only ever a label here -- the id does not derive from it.
        slot: NotificationSlot.dailySummary,
        when: next,
        title: r.title,
        body: (r.note == null || r.note!.trim().isEmpty)
            ? _defaultBody
            : r.note!.trim(),
        channelId: channelGeneral,
        payload: 'reminder:${r.id}',
      ));
    }
  }

  /// Silences one reminder — when it is deleted, or marked done.
  Future<void> cancelFor(int rowId) =>
      _gateway.cancel(reminderNotificationId(rowId));
}
