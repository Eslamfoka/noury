import 'package:nouri/core/notifications/notification_gateway.dart';
import 'package:nouri/core/notifications/notification_slot.dart';

/// Records what would have been scheduled, so the whole rolling-window
/// strategy can be tested without a platform channel.
class FakeNotificationGateway implements NotificationGateway {
  final List<ScheduledNotification> scheduled = [];
  final List<String> shown = [];
  int cancelAllCount = 0;

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(ScheduledNotification n) async => scheduled.add(n);

  @override
  Future<List<int>> pendingIds() async => scheduled.map((n) => n.id).toList();

  @override
  Future<void> showNow({
    required String title,
    required String body,
    required String channelId,
  }) async =>
      shown.add(title);

  Iterable<ScheduledNotification> ofSlot(NotificationSlot s) =>
      scheduled.where((n) => n.slot == s);

  Iterable<ScheduledNotification> onDay(int month, int day) => scheduled
      .where((n) => n.when.month == month && n.when.day == day);
}
