import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/notifications/local_notification_gateway.dart';
import 'core/notifications/notification_gateway.dart';
import 'core/notifications/notification_route.dart';
import 'features/reminders/reminder_providers.dart';
import 'features/reminders/reminder_scheduler.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/pending_route_provider.dart';
import 'core/notifications/rolling_window_scheduler.dart';
import 'core/time/geo_config.dart';
import 'core/time/location_service.dart';
import 'core/time/prayer_times_service.dart';
import 'data/db/nouri_database.dart';
import 'features/home/home_providers.dart';
import 'features/settings/settings_controller.dart';
import 'features/settings/settings_screen.dart';

/// Times a startup phase and reports it, so "the app feels slow" becomes a
/// number per phase instead of a guess. Costs nothing in release, where
/// `assert` is stripped.
Future<T> _phase<T>(String name, Future<T> Function() body) async {
  final sw = Stopwatch()..start();
  final result = await body();
  sw.stop();
  assert(() {
    debugPrint('NOURI_STARTUP $name ${sw.elapsedMilliseconds}ms');
    return true;
  }());
  return result;
}

Future<void> main() async {
  final total = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  final db = NouriDatabase();
  final plugin = FlutterLocalNotificationsPlugin();
  final notifications = NotificationService(plugin);

  // Resolves once the scheduler exists. A settings change made before then
  // waits on this rather than being silently dropped.
  final schedulerReady = Completer<SchedulerPort?>();

  // The same deal for reminders. A reminder written in the first seconds
  // after launch must not be saved-but-never-armed, which is the worst
  // failure available here: the row is visibly there and the alarm is not.
  final reminderSchedulerReady = Completer<ReminderSchedulerPort?>();

  // A tap can arrive before the ProviderScope exists — Android launches the
  // app cold straight from the shade — so the first one is held here and
  // handed to the container as its initial value.
  NotificationRoute? launchRoute;
  late final ProviderContainer container;
  var containerReady = false;

  void deliver(NotificationRoute? route) {
    if (route == null) return;
    if (containerReady) {
      container.read(pendingNotificationRouteProvider.notifier).push(route);
    } else {
      launchRoute = route;
    }
  }

  // Only the cheap half runs before the first frame: creating the five
  // channels, measured at ~57ms. Everything expensive is deferred — see
  // [_warmUpInBackground].
  //
  // Notification setup must never stop the app: logging, athkar, the tasbeeh
  // and the wird all work without it, so Nouri degrades rather than refusing
  // to start.
  try {
    await _phase(
      'pluginInit',
      () => notifications.init(
        onResponse: (response) =>
            deliver(NotificationRoute.parse(response.payload)),
      ),
    );
  } catch (e) {
    debugPrint('Nouri: notification setup failed, continuing without it: $e');
  }

  final warmUp = _warmUpInBackground(
    db: db,
    plugin: plugin,
    notifications: notifications,
    schedulerReady: schedulerReady,
    reminderSchedulerReady: reminderSchedulerReady,
    total: total,
  );
  notifications.attachWarmUp(warmUp);

  assert(() {
    debugPrint('NOURI_STARTUP beforeRunApp ${total.elapsedMilliseconds}ms');
    return true;
  }());

  container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(notifications),
      locationPortProvider.overrideWithValue(const GeolocatorLocationPort()),
      schedulerPortProvider
          .overrideWithValue(DeferredSchedulerPort(schedulerReady.future)),
      reminderSchedulerPortProvider.overrideWithValue(
          DeferredReminderSchedulerPort(reminderSchedulerReady.future)),
    ],
  );
  containerReady = true;

  // A tap that launched the app from a cold start does not always reach the
  // response callback, so ask the plugin directly what opened us.
  try {
    final launch = await plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      deliver(NotificationRoute.parse(launch?.notificationResponse?.payload));
    }
  } catch (e) {
    debugPrint('Nouri: could not read launch details: $e');
  }

  final pending = launchRoute;
  if (pending != null) {
    container.read(pendingNotificationRouteProvider.notifier).push(pending);
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NouriApp(),
    ),
  );
}

/// The expensive half of startup, moved off the critical path.
///
/// Measured on a HONOR VNE-N41 before this change: loading the timezone
/// database took 1.5s and arming the 14-day window took **11.7s** — 262
/// sequential platform-channel round-trips — all of it before Flutter was
/// allowed to draw a single pixel. The app took over 20 seconds to appear.
///
/// Nothing here needs to block the UI. The alarms from the previous run are
/// still live in AlarmManager, so there is no window in which the user is
/// unprotected: re-arming refreshes them rather than creating them, and is
/// idempotent by design.
///
/// Started but deliberately not awaited by `main`, so the first frame renders
/// while this runs.
Future<void> _warmUpInBackground({
  required NouriDatabase db,
  required FlutterLocalNotificationsPlugin plugin,
  required NotificationService notifications,
  required Completer<SchedulerPort?> schedulerReady,
  required Completer<ReminderSchedulerPort?> reminderSchedulerReady,
  required Stopwatch total,
}) async {
  try {
    await _phase('timezone', NotificationService.initTimezone);

    final status = await _phase('readStatus', notifications.readStatus);
    final gateway = LocalNotificationGateway(plugin, mode: status.mode);
    final scheduler = RollingWindowScheduler(
      gateway: gateway,
      prayerTimes: const PrayerTimesService(),
      clock: DateTime.now,
    );

    // Unblock anything waiting to re-arm before starting the slow pass.
    schedulerReady.complete(RollingWindowSchedulerPort(scheduler));
    reminderSchedulerReady
        .complete(LiveReminderSchedulerPort(ReminderScheduler(gateway)));

    await _phase('armWindow', () => _armWindow(db, scheduler));

    // Strictly after the window. The window clears its own id range on every
    // re-arm, and while that deliberately spares reminders, arming them second
    // means the order can never matter.
    await _phase('armReminders', () => _armReminders(db, gateway));

    assert(() {
      debugPrint('NOURI_STARTUP warmUpComplete ${total.elapsedMilliseconds}ms');
      return true;
    }());
  } catch (e) {
    debugPrint('Nouri: background warm-up failed: $e');
    if (!schedulerReady.isCompleted) schedulerReady.complete(null);
    if (!reminderSchedulerReady.isCompleted) {
      reminderSchedulerReady.complete(null);
    }
  }
}

/// Arms the next occurrence of every reminder the user has not marked done.
///
/// One alarm per reminder, never one per occurrence: a daily reminder armed
/// for a year would cost 365 of Android's ~500 pending alarms on its own and
/// start pushing adhan alarms out.
Future<void> _armReminders(
  NouriDatabase db,
  NotificationGateway gateway,
) async {
  final active = await db.reminderDao.allActive();
  if (active.isEmpty) return;
  await ReminderScheduler(gateway).arm(active);
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
