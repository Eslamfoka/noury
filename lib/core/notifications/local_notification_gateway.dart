import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_channels.dart';
import 'notification_gateway.dart';
import 'notification_slot.dart';
import 'notification_status.dart';

/// The real Android implementation.
///
/// Everything above this class is tested against a fake; this layer holds only
/// the plugin calls, so there is as little untested surface as possible.
class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway(this._plugin, {required this.mode});

  final FlutterLocalNotificationsPlugin _plugin;

  /// Set from [NotificationStatus]. When the platform refuses exact alarms
  /// this drops to [NotificationMode.inexact] — the app keeps working and the
  /// settings panel states the limitation plainly.
  final NotificationMode mode;

  AndroidScheduleMode get _scheduleMode => mode == NotificationMode.exact
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule(ScheduledNotification n) => _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: tz.TZDateTime.from(n.when, tz.local),
        androidScheduleMode: _scheduleMode,
        payload: n.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            n.channelId,
            n.channelId,
            category: n.channelId == channelAdhan
                ? AndroidNotificationCategory.alarm
                : AndroidNotificationCategory.reminder,
            // Only the follow-up gets an action: logging the prayer straight
            // from the shade, without opening the app.
            actions: (n.payload?.startsWith('log:') ?? false)
                ? const <AndroidNotificationAction>[
                    AndroidNotificationAction(
                      actionLogged,
                      'صليت',
                      showsUserInterface: false,
                      cancelNotification: true,
                    ),
                  ]
                : null,
          ),
        ),
      );

  @override
  Future<List<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests()).map((r) => r.id).toList();

  @override
  Future<void> showNow({
    required String title,
    required String body,
    required String channelId,
  }) =>
      _plugin.show(
        id: testNotificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(channelId, channelId),
        ),
      );
}

/// Action id on the prayer follow-up notification.
const actionLogged = 'logged';

/// Reserved id for the "send test notification" action. Kept far outside the
/// scheduled-ID space so it can never collide with a real alarm.
const testNotificationId = 999999999;
