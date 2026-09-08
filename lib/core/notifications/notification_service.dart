import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_notification_gateway.dart';
import 'adhan_sounds.dart';
import 'notification_channels.dart';
import 'notification_slot.dart';
import 'notification_status.dart';

/// Owns the plugin: initialisation, channels, permissions, and reading the
/// honest status of whether notifications will actually arrive.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  /// Completes once the timezone database is loaded.
  ///
  /// Timezone init is deferred off the startup path (it cost 1.5s of blank
  /// screen), but nothing may schedule before it finishes or every TZDateTime
  /// would resolve against UTC. Scheduling paths await this rather than
  /// assuming it is done.
  Future<void>? _warmUp;

  // ignore: use_setters_to_change_properties
  void attachWarmUp(Future<void> warmUp) => _warmUp = warmUp;

  Future<void> _ensureReady() async {
    final w = _warmUp;
    if (w != null) await w;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Must run before anything is scheduled: without the local timezone set,
  /// every TZDateTime would be computed against UTC and the adhan would fire
  /// at the wrong hour.
  static Future<void> initTimezone() async {
    tzdata.initializeTimeZones();
    final name = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(name.identifier));
  }

  Future<void> init({
    DidReceiveNotificationResponseCallback? onResponse,
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
      // **The half that was missing.** An action declared with
      // `showsUserInterface: false` is delivered to a *background isolate*,
      // not to the running app — and with no handler registered here, the tap
      // goes nowhere at all. That is exactly what happened to the «صليت»
      // action, which was silently dead until it was changed to open the app.
      //
      // «فكّرني بعد ٥ دقايق» must not open the app — being dragged into a
      // screen is the opposite of putting something off — so this time the
      // handler is registered.
      onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
    );

    // Delete superseded channels before creating the current ones, so the
    // settings screen never shows two «الأذان» rows with only one of them live.
    for (final id in retiredChannelIds) {
      await _android?.deleteNotificationChannel(channelId: id);
    }

    for (final channel in nouriChannels) {
      await _android?.createNotificationChannel(channel);
    }
  }

  /// Cancels one pending notification by id.
  ///
  /// Used to silence the follow-ups for a prayer once it has been logged.
  Future<void> cancel(int id) async {
    await _ensureReady();
    await _plugin.cancel(id: id);
  }

  /// Reads the live device state. Nothing here is cached — the settings panel
  /// must show what is true right now, not what was true at launch.
  Future<NotificationStatus> readStatus() async {
    final enabled = await _android?.areNotificationsEnabled() ?? false;
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final batteryExempt =
        await Permission.ignoreBatteryOptimizations.isGranted;

    return NotificationStatus(
      notificationsEnabled: enabled,
      exactAlarmsAllowed: exact,
      batteryOptimised: !batteryExempt,
    );
  }

  Future<void> requestNotificationPermission() async {
    await _android?.requestNotificationsPermission();
  }

  Future<void> requestExactAlarmPermission() async {
    await _android?.requestExactAlarmsPermission();
  }

  Future<void> requestBatteryExemption() async {
    await Permission.ignoreBatteryOptimizations.request();
  }

  /// Fires immediately, so the whole chain can be verified on the real device
  /// in seconds rather than by waiting for a prayer.
  ///
  /// Deliberately sent on the **adhan** channel, not the general one. The
  /// point of a test is to hear what the adhan will actually sound like — its
  /// bundled chime, at alarm volume, with the adhan channel's importance. A
  /// test on the general channel only proves that notifications work at all,
  /// which is the least interesting thing about them, and it was misleading in
  /// practice: it played the plain system beep and looked like the chime had
  /// failed.
  Future<void> sendTestNotification() async {
    await _ensureReady();
    final status = await readStatus();
    final gateway = LocalNotificationGateway(_plugin, mode: status.mode);
    await gateway.showNow(
      title: 'نوري — تجربة الأذان',
      body: 'كده هيبقى شكل تنبيه الأذان وصوته.',
      channelId: adhanChannelFor('dhuhr'),
    );
  }

  /// Schedules a real adhan-style alarm a couple of minutes out.
  ///
  /// This is the only way to honestly test the thing that matters: not
  /// "can the app show a notification while it is open", but "does an alarm
  /// the app scheduled earlier fire while the app is closed". It goes through
  /// the same gateway, the same channel and the same AlarmManager path as a
  /// real adhan — only the time and the wording differ.
  ///
  /// It deliberately does **not** re-arm the window afterwards, so a test can
  /// never disturb the real schedule.
  Future<DateTime> scheduleTestAdhan({
    Duration delay = const Duration(minutes: 2),
  }) async {
    await _ensureReady();
    final status = await readStatus();
    final gateway = LocalNotificationGateway(_plugin, mode: status.mode);
    final when = DateTime.now().add(delay);

    await gateway.schedule(ScheduledNotification(
      id: testAdhanNotificationId,
      slot: NotificationSlot.adhanFajr, // only used for logging
      when: when,
      title: 'نوري — تجربة الأذان',
      body: 'لو سمعت ده والتطبيق مقفول، يبقى الأذان هيوصلك في وقته.',
      channelId: adhanChannelFor('dhuhr'),
    ));

    return when;
  }
}
