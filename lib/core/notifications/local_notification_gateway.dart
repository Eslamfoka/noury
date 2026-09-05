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

  /// Converts an instant to a [tz.TZDateTime] **in UTC**, deliberately.
  ///
  /// The plugin serialises a schedule as a wall-clock string plus a zone name,
  /// and the Android side rebuilds the instant with its own tz database. That
  /// is only safe when both databases agree on that zone's rules for that
  /// date. They frequently do not: OEM images ship stale tzdata, and the
  /// `timezone` package is updated independently. A single DST-rule
  /// disagreement moves the adhan by an hour.
  ///
  /// UTC has no rules to disagree about, so the instant survives the round
  /// trip intact regardless of either side's tzdata. This was observed
  /// concretely: with the device on Africa/Cairo, an alarm computed for 03:07
  /// was scheduled at 04:07 because the two databases disagreed about Egyptian
  /// DST.
  ///
  /// Safe here because every notification is scheduled individually — nothing
  /// uses `matchDateTimeComponents`, which is the one feature that would need
  /// a real local zone.
  static tz.TZDateTime _asUtc(DateTime when) =>
      tz.TZDateTime.from(when, tz.UTC);

  @override
  Future<void> schedule(ScheduledNotification n) => _plugin.zonedSchedule(
        id: n.id,
        title: n.title,
        body: n.body,
        scheduledDate: _asUtc(n.when),
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
