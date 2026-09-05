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

  Future<List<int>> pendingIds();

  /// Fires immediately — used by the "send test notification" action.
  Future<void> showNow({
    required String title,
    required String body,
    required String channelId,
  });
}
