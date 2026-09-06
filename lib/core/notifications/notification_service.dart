import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'local_notification_gateway.dart';
import 'notification_channels.dart';
import 'notification_status.dart';

/// Owns the plugin: initialisation, channels, permissions, and reading the
/// honest status of whether notifications will actually arrive.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

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
  }) async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: onResponse,
    );

    for (final channel in nouriChannels) {
      await _android?.createNotificationChannel(channel);
    }
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
    final status = await readStatus();
    final gateway = LocalNotificationGateway(_plugin, mode: status.mode);
    await gateway.showNow(
      title: 'نوري — تجربة الأذان',
      body: 'كده هيبقى شكل تنبيه الأذان وصوته.',
      channelId: channelAdhan,
    );
  }
}
