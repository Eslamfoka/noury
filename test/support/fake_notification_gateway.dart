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

  /// Ceilings passed to [cancelAllBelow], in order.
  final List<int> cancelledBelow = [];

  @override
  Future<void> cancelAllBelow(int ceiling) async {
    cancelledBelow.add(ceiling);
    cancelAllCount++;
    scheduled.removeWhere((n) => n.id < ceiling);
  }

  /// Scheduling an id that is already pending **replaces** it, as Android
  /// does.
  ///
  /// Not a convenience: it is the property the rolling window now depends on.
  /// `AlarmManager.setExactAndAllowWhileIdle` cancels any alarm already held
  /// under an equal PendingIntent before setting the new one, and the plugin
  /// builds that PendingIntent from the notification id as its request code
  /// with `FLAG_UPDATE_CURRENT` — so re-arming an id overwrites it rather than
  /// stacking a second alarm beside it. The plugin's own boot cache is keyed
  /// by id too and replaces in the same way.
  ///
  /// A fake that appended would let a re-arm which no longer cancels first
  /// look correct here and be wrong on the device — which is the one kind of
  /// bug this project has learned to be afraid of.
  @override
  Future<void> schedule(ScheduledNotification n) async {
    scheduled.removeWhere((existing) => existing.id == n.id);
    scheduled.add(n);
  }

  /// Ids passed to [cancel], in order.
  final List<int> cancelled = [];

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.removeWhere((n) => n.id == id);
  }

  @override
  Future<List<int>> pendingIds() async => scheduled.map((n) => n.id).toList();

  /// The channel ids passed to [showNow], in order — what الأصوات auditions.
  final List<String> shownOn = [];

  @override
  Future<void> showNow({
    required String title,
    required String body,
    required String channelId,
    bool preview = false,
  }) async {
    shown.add(title);
    shownOn.add(channelId);
  }

  Iterable<ScheduledNotification> ofSlot(NotificationSlot s) =>
      scheduled.where((n) => n.slot == s);

  Iterable<ScheduledNotification> onDay(int month, int day) => scheduled
      .where((n) => n.when.month == month && n.when.day == day);
}
