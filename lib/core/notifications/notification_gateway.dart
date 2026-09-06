import 'notification_slot.dart';

/// The seam that makes scheduling testable.
///
/// Production uses `LocalNotificationGateway`; tests use a fake that records
/// calls. Everything above this interface — the rolling window, the re-arm
/// logic, the copy — is exercised without touching a platform channel.
abstract class NotificationGateway {
  /// Clears every pending notification. Re-arming always starts from empty so
  /// there is no incremental state to get wrong.
  Future<void> cancelAll();

  Future<void> schedule(ScheduledNotification n);

  /// Cancels one pending notification by id.
  ///
  /// Used when a prayer is logged: the follow-ups asking about it were armed
  /// hours earlier and cannot know they have been answered, so the answer has
  /// to reach back and cancel them. Deterministic ids are what make this
  /// possible without storing anything.
  Future<void> cancel(int id);

  Future<List<int>> pendingIds();

  /// Fires immediately — used by the "send test notification" action.
  Future<void> showNow({
    required String title,
    required String body,
    required String channelId,
  });
}
