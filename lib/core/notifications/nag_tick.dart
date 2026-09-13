import 'dart:ui' show DartPluginRegistrant;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/tasks/snooze_store.dart';
import 'nag_plan.dart';
import 'nag_store.dart';
import 'notification_channels.dart';

/// The tick behind «فكّرني تاني», and the chain that keeps it ticking.
///
/// **One alarm, re-armed by its own handler.** Not `periodic`: on Android
/// that is `setRepeating`, which has been inexact since KitKat and is
/// deferred wholesale while the phone dozes. A one-shot armed with
/// `setExactAndAllowWhileIdle`, re-armed from inside the tick, is the shape
/// Android honours — with the platform's own floor of one wake per nine
/// minutes in deep doze, which is why five-minute nags are a promise that
/// only holds while the phone is awake, and why the default is ten.
///
/// **Runs in a background isolate** with nothing of `main()` alive, exactly
/// like the snooze handler: plugins have to be registered here, the
/// notifications plugin has to be initialised here, and nothing may throw —
/// a throw out of a background isolate is an opaque platform error the user
/// can do nothing with.
///
/// The decision itself is [decideNag], pure and tested; this is the wiring.
class NagChain {
  /// The alarm-manager id. Its own namespace, unrelated to notification ids.
  static const alarmId = 7001;

  /// Arms the next tick, replacing any pending one.
  static Future<void> arm(Duration interval) async {
    try {
      await AndroidAlarmManager.oneShot(
        interval,
        alarmId,
        nagTick,
        exact: true,
        wakeup: true,
        allowWhileIdle: true,
        rescheduleOnReboot: true,
      );
    } catch (e) {
      debugPrint('Nouri: nag chain not armed: $e');
    }
  }

  static Future<void> cancel() async {
    try {
      await AndroidAlarmManager.cancel(alarmId);
    } catch (e) {
      debugPrint('Nouri: nag chain not cancelled: $e');
    }
  }
}

/// The real [NagPlanSink]: writes the two files, then starts or stops the
/// chain to match the plan.
class FileNagPlanSink implements NagPlanSink {
  const FileNagPlanSink();

  @override
  Future<void> publish(
    NagPlan plan, {
    required DateTime today,
    required Set<String> doneToday,
  }) async {
    final store = await openNagStore();
    await store.writePlan(plan);
    await store.replaceDone(today, doneToday);

    if (plan.active) {
      await NagChain.arm(plan.interval);
    } else {
      await NagChain.cancel();
    }
  }
}

/// One tick. Reads, decides, posts at most one notification, re-arms.
@pragma('vm:entry-point')
Future<void> nagTick() async {
  // Nothing from `main()` is alive here, including the plugin registry.
  DartPluginRegistrant.ensureInitialized();

  NagPlan? plan;
  try {
    final store = await openNagStore();
    plan = await store.readPlan();
    if (plan == null || !plan.active) return;

    final now = DateTime.now();
    final done = await store.readDone(now);
    final snoozed = await (await openSnoozeStore()).read(now: now);

    final decision = decideNag(
      plan: plan,
      done: done,
      snoozedUntil: snoozed,
      now: now,
    );
    if (decision != null) await _post(decision);
  } catch (e) {
    debugPrint('Nouri: nag tick failed: $e');
  } finally {
    // The chain must outlive any one failure: a tick that could not read its
    // files still arms the next, or the feature dies silently on the first
    // bad read and stays dead until the next launch.
    if (plan != null && plan.active) await NagChain.arm(plan.interval);
  }
}

Future<void> _post(NagDecision d) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin.show(
    id: kNagNotificationId,
    title: d.title,
    body: d.body,
    payload: d.payload,
    notificationDetails: NotificationDetails(
      // The task's own channel, so the nag sounds like the task it is about
      // — and so muting one task's channel in system settings mutes its
      // nags with it.
      android: androidDetailsFor(d.channelId),
    ),
  );
}
