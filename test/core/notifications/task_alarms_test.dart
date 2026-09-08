import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_channels_ids.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/notifications/task_alarm_ids.dart';
import 'package:nouri/core/notifications/task_alert.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/shift.dart';

import '../../support/fake_notification_gateway.dart';

/// The planned day, armed.
///
///   «i don't need to open the app to know what i have to do, i need alarms
///    for each task»
void main() {
  late FakeNotificationGateway gateway;
  late RollingWindowScheduler scheduler;

  final now = DateTime(2026, 9, 5, 6, 0);

  const config = SchedulingConfig(
    geo: GeoConfig.kuwaitCity,
    iqamaOffsets: {
      'fajr': 20,
      'dhuhr': 15,
      'asr': 15,
      'maghrib': 10,
      'isha': 15,
    },
  );

  setUp(() {
    gateway = FakeNotificationGateway();
    scheduler = RollingWindowScheduler(
      gateway: gateway,
      prayerTimes: const PrayerTimesService(),
      clock: () => now,
    );
  });

  Iterable<ScheduledNotification> taskAlarms() =>
      gateway.scheduled.where((n) => n.payload?.startsWith('task:') ?? false);
  Iterable<ScheduledNotification> asks() =>
      gateway.scheduled.where((n) => n.payload?.startsWith('taskask:') ?? false);

  test('the day announces itself, task by task', () async {
    await scheduler.rearm(config);
    expect(taskAlarms(), isNotEmpty);
  });

  test('over three days, not the adhan\'s fortnight', () async {
    // The user's instruction: "today + next 2-3 days only". Also the budget:
    // ten tasks over fourteen days would be ~140 alarms out of Android's ~500,
    // which the adhan has first call on.
    await scheduler.rearm(config);
    final days = taskAlarms()
        .map((n) => DateTime(n.when.year, n.when.month, n.when.day))
        .toSet();
    expect(days.length, kTaskAlarmWindowDays);
  });

  test('turning them off arms none', () async {
    await scheduler.rearm(config.copyWith(notifyTasks: false));
    expect(taskAlarms(), isEmpty);
    expect(asks(), isEmpty);
  });

  test('each task carries its own channel, so each sounds different',
      () async {
    await scheduler.rearm(config);
    final channelByPayload = <String, String>{};
    for (final n in taskAlarms()) {
      final seen = channelByPayload[n.payload!];
      if (seen != null) expect(seen, n.channelId);
      channelByPayload[n.payload!] = n.channelId;
    }
    // Two tasks sharing a channel must be the same *kind* of thing. Both
    // meals mean "eat" and all three knowledge faces are one block, so those
    // sharing a sound is right; anything else sharing one would make a sound
    // mean two different things.
    final kindByChannel = <String, String>{};
    for (final entry in channelByPayload.entries) {
      final taskId = entry.key.substring('task:'.length);
      final kind = alertKindForTaskId(taskId)!.name;
      final seen = kindByChannel[entry.value];
      if (seen != null) {
        expect(seen, kind,
            reason: '${entry.value} would mean two different things');
      }
      kindByChannel[entry.value] = kind;
    }
    expect(kindByChannel, isNotEmpty);
  });

  test('no task alarm borrows the adhan channel', () async {
    await scheduler.rearm(config);
    for (final n in taskAlarms()) {
      expect(n.channelId, isNot(channelAdhan), reason: n.payload);
    }
  });

  test('ids sit in the task range, below the reminder floor', () async {
    // Below, so a re-arm clears them — the plan is rebuilt every launch and
    // yesterday's arrangement must not survive into today's.
    await scheduler.rearm(config);
    for (final n in [...taskAlarms(), ...asks()]) {
      expect(isTaskAlarmId(n.id), isTrue, reason: '${n.payload} -> ${n.id}');
      expect(n.id, lessThan(kOutOfWindowIdBase), reason: n.payload);
    }
  });

  test('re-arming twice is indistinguishable from re-arming once', () async {
    await scheduler.rearm(config);
    final first = gateway.scheduled.length;
    await scheduler.rearm(config);
    expect(gateway.scheduled.length, first,
        reason: 'ids are reproducible, so alarms overwrite rather than double');
  });

  test('nothing is armed into the past', () async {
    await scheduler.rearm(config);
    for (final n in gateway.scheduled) {
      expect(n.when.isAfter(now), isTrue, reason: '${n.payload} at ${n.when}');
    }
  });

  test('the whole window stays well inside Android\'s pending-alarm cap',
      () async {
    // Measured on the phone before this slice: 249. The cap is about 500 and
    // the adhan has first call on it.
    await scheduler.rearm(config);
    expect(gateway.scheduled.length, lessThan(400),
        reason: 'armed ${gateway.scheduled.length}');
  });

  group('the follow-up question', () {
    test('the meal is asked about thirty minutes later', () async {
      // «after 30 mins ask me are you ate?»
      await scheduler.rearm(config);
      final meal = taskAlarms().firstWhere((n) => n.payload == 'task:first-meal');
      final ask = asks().firstWhere((n) => n.payload == 'taskask:first-meal');
      expect(ask.when.difference(meal.when), const Duration(minutes: 30));
    });

    test('it is a question, and it arrives softly', () async {
      await scheduler.rearm(config);
      final ask = asks().firstWhere((n) => n.payload == 'taskask:first-meal');
      expect(ask.body, contains('؟'));
      expect(ask.channelId, TaskAlertKind.followUp.channelId,
          reason: 'a question must not arrive at the volume of a summons');
    });

    test('a task with no follow-up is not asked about', () async {
      // وقت الموبايل already reports itself on its card.
      await scheduler.rearm(config);
      expect(asks().where((n) => n.payload == 'taskask:phone-time'), isEmpty);
    });

    test('the ask never collides with the alert it follows', () async {
      await scheduler.rearm(config);
      final ids = [...taskAlarms(), ...asks()].map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  test('a night shift produces its own arrangement, not the morning\'s',
      () async {
    await scheduler.rearm(config);
    final morning = taskAlarms()
        .firstWhere((n) => n.payload == 'task:tasbeeh')
        .when;

    gateway.scheduled.clear();
    await scheduler.rearm(config.copyWith(shift: ShiftType.night));
    final night = taskAlarms()
        .firstWhere((n) => n.payload == 'task:tasbeeh')
        .when;

    expect(night, isNot(morning),
        reason: 'the alarms follow the duty pattern, which is the point');
  });
}
