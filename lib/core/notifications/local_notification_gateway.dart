import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_channels.dart';
import 'notification_gateway.dart';
import 'notification_slot.dart';
import 'snooze.dart';
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
  Future<void> cancelAllBelow(int ceiling) async {
    // One cancel per pending alarm rather than the plugin's single cancelAll.
    // The window already pays ~230 zonedSchedule calls to re-arm, each of
    // which registers an AlarmManager entry, so the extra cancels are a small
    // fraction of an operation that only runs at startup and on a settings
    // change -- and they are what keeps reminders alive across it.
    for (final id in await pendingIds()) {
      if (id < ceiling) await _plugin.cancel(id: id);
    }
  }

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
          android: androidDetailsFor(
            n.channelId,
            actions: _actionsFor(n),
          ),
        ),
      );

  /// The buttons on a notification.
  ///
  /// Two shapes, and the difference matters. The prayer follow-up's «صليت»
  /// **opens the app**, because logging a prayer means saying *how* it was
  /// prayed and Nouri will not guess that. The task alert's snooze
  /// **must not**: being dragged into a screen is the opposite of putting
  /// something off, so it is handled in a background isolate.
  static List<AndroidNotificationAction>? _actionsFor(
      ScheduledNotification n) {
    final payload = n.payload;
    if (payload == null) return null;

    if (payload.startsWith('task:')) {
      return const <AndroidNotificationAction>[
        AndroidNotificationAction(
          actionSnooze,
          'فكّرني بعد ٥ دقايق',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ];
    }

    if (payload.startsWith('log:')) {
      return const <AndroidNotificationAction>[
        // Only the follow-up gets this one: logging the prayer straight
        // from the shade, without opening the app.
        //
        // It was once `showsUserInterface: false`, meaning to write the log
        // straight from the shade — but that routes the tap to a background
        // isolate, and no handler was registered, so the button did nothing
        // at all. Opening the app is the honest version here: one extra tap,
        // and it lets the user say *how* they prayed rather than having a
        // quality guessed on their behalf.
        AndroidNotificationAction(
          actionLogged,
          'صليت',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ];
    }

    return null;
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

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
          android: androidDetailsFor(channelId),
        ),
      );
}

/// Action id on the prayer follow-up notification.
const actionLogged = 'logged';

/// Reserved ids for the two test actions. Both sit far outside the
/// scheduled-ID space so they can never collide with a real alarm.
const testNotificationId = 999999999;
const testAdhanNotificationId = 999999998;
