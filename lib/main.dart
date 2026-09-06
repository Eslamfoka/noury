import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/local_notification_gateway.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/rolling_window_scheduler.dart';
import 'core/time/geo_config.dart';
import 'core/time/location_service.dart';
import 'core/time/prayer_times_service.dart';
import 'data/db/nouri_database.dart';
import 'features/home/home_providers.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = NouriDatabase();
  final plugin = FlutterLocalNotificationsPlugin();
  final notifications = NotificationService(plugin);

  RollingWindowScheduler? scheduler;

  // Notification setup must never stop the app: logging, athkar, the tasbeeh
  // and the wird all work without it, so Nouri degrades rather than refusing
  // to start.
  try {
    await NotificationService.initTimezone();
    await notifications.init();

    final status = await notifications.readStatus();
    scheduler = RollingWindowScheduler(
      gateway: LocalNotificationGateway(plugin, mode: status.mode),
      prayerTimes: const PrayerTimesService(),
      clock: DateTime.now,
    );

    await _armWindow(db, scheduler);
  } catch (e) {
    debugPrint('Nouri: notification setup failed, continuing without it: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
        locationPortProvider
            .overrideWithValue(const GeolocatorLocationPort()),
        if (scheduler != null)
          schedulerPortProvider
              .overrideWithValue(RollingWindowSchedulerPort(scheduler)),
      ],
      child: const NouriApp(),
    ),
  );
}

/// Builds the rolling window from current settings.
///
/// This is the app-resume arm of the three-trigger strategy; the other two are
/// the boot receiver in the manifest and the scheduler's own idempotence,
/// which makes re-arming safe to repeat.
Future<void> _armWindow(NouriDatabase db, RollingWindowScheduler s) async {
  final settings = await db.settingsDao.get();
  await s.rearm(SchedulingConfig(
    geo: GeoConfig(
      latitude: settings.latitude,
      longitude: settings.longitude,
      method: settings.calculationMethod,
      madhab: settings.madhab,
    ),
    iqamaOffsets: decodeIqamaOffsets(settings.iqamaOffsetsJson),
    notifyAdhan: settings.notifyAdhan,
    notifyIqama: settings.notifyIqama,
    notifyAthkar: settings.notifyAthkar,
    notifyWird: settings.notifyWird,
  ));
}
