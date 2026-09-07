import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_channels_ids.dart';
import 'package:nouri/core/notifications/notification_route.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/reminders/reminder_ids.dart';
import 'package:nouri/features/reminders/reminder_scheduler.dart';

import '../../support/fake_notification_gateway.dart';

Reminder aReminder({
  int id = 1,
  DateTime? on,
  int minutes = 9 * 60,
  ReminderRepeat repeat = ReminderRepeat.once,
  bool done = false,
  String title = 'كشف',
  String? note,
}) =>
    Reminder(
      id: id,
      onDate: on ?? DateTime(2026, 9, 20),
      minutes: minutes,
      title: title,
      note: note,
      repeat: repeat,
      done: done,
      createdAt: DateTime(2026, 9, 7),
    );

void main() {
  late FakeNotificationGateway gateway;
  late ReminderScheduler scheduler;

  setUp(() {
    gateway = FakeNotificationGateway();
    scheduler = ReminderScheduler(gateway);
  });

  group('arming', () {
    test('arms the next occurrence of each reminder', () async {
      await scheduler.arm([
        aReminder(id: 1, on: DateTime(2026, 9, 20), repeat: ReminderRepeat.daily),
        aReminder(id: 2, on: DateTime(2026, 9, 25)),
      ], now: DateTime(2026, 9, 19, 12));

      expect(gateway.scheduled.map((s) => s.id),
          [reminderNotificationId(1), reminderNotificationId(2)]);
    });

    test('arms one alarm per reminder, not one per occurrence', () async {
      // A daily reminder armed for every day of a year would exhaust the
      // ~500 pending-alarm cap on its own and take the adhan down with it.
      await scheduler.arm(
        [aReminder(id: 1, repeat: ReminderRepeat.daily)],
        now: DateTime(2026, 9, 19),
      );
      expect(gateway.scheduled, hasLength(1));
    });

    test('skips a reminder already marked done', () async {
      await scheduler.arm(
        [aReminder(id: 1, done: true)],
        now: DateTime(2026, 9, 19),
      );
      expect(gateway.scheduled, isEmpty);
    });

    test('skips a one-off whose time has passed', () async {
      await scheduler.arm(
        [aReminder(id: 1, on: DateTime(2026, 9, 20))],
        now: DateTime(2026, 9, 21),
      );
      expect(gateway.scheduled, isEmpty);
    });

    test('rides the general channel, not the adhan', () async {
      // "You asked me to remind you" is not a call to prayer, and must not
      // borrow its importance or its sound.
      await scheduler.arm([aReminder(id: 1)], now: DateTime(2026, 9, 19));
      expect(gateway.scheduled.single.channelId, channelGeneral);
    });

    test('carries a payload that routes back to the reminder', () async {
      await scheduler.arm([aReminder(id: 7)], now: DateTime(2026, 9, 19));
      expect(gateway.scheduled.single.payload, 'reminder:7');
      expect(NotificationRoute.parse('reminder:7'), const ReminderRoute(7));
    });

    test('shows the title, and the note as the body when there is one',
        () async {
      await scheduler.arm([
        aReminder(id: 1, title: 'ميعاد الدكتور', note: 'تاخد التحاليل معاك'),
      ], now: DateTime(2026, 9, 19));

      final n = gateway.scheduled.single;
      expect(n.title, 'ميعاد الدكتور');
      expect(n.body, 'تاخد التحاليل معاك');
    });

    test('falls back to a neutral body rather than an empty one', () async {
      await scheduler.arm([aReminder(id: 1, note: null)],
          now: DateTime(2026, 9, 19));
      expect(gateway.scheduled.single.body.trim(), isNotEmpty);
    });

    test('re-arming replaces rather than duplicating', () async {
      final r = aReminder(id: 1, repeat: ReminderRepeat.daily);
      await scheduler.arm([r], now: DateTime(2026, 9, 19));
      await scheduler.arm([r], now: DateTime(2026, 9, 19));

      final ids = gateway.scheduled.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(1),
          reason: 'the id is derived, so the second arm overwrites the first');
    });
  });

  group('cancelling', () {
    test('uses the same derived id', () async {
      await scheduler.cancelFor(7);
      expect(gateway.cancelled, [reminderNotificationId(7)]);
    });
  });

  group('living beside the adhan', () {
    test('a window re-arm does not delete the reminders', () async {
      // The regression this whole ID split exists to prevent: before
      // cancelAllBelow, any settings change called cancelAll() and silently
      // took every reminder alarm with it.
      await scheduler.arm(
        [aReminder(id: 1, on: DateTime(2026, 9, 20), repeat: ReminderRepeat.daily)],
        now: DateTime(2026, 9, 19),
      );
      expect(gateway.scheduled, hasLength(1));

      await RollingWindowScheduler(
        gateway: gateway,
        prayerTimes: const PrayerTimesService(),
        clock: () => DateTime(2026, 9, 19, 12),
      ).rearm(const SchedulingConfig(
        geo: GeoConfig(
          latitude: 29.3759,
          longitude: 47.9774,
          method: 'kuwait',
          madhab: 'shafi',
        ),
        iqamaOffsets: {
          'fajr': 20,
          'dhuhr': 15,
          'asr': 15,
          'maghrib': 10,
          'isha': 15,
        },
      ));

      final surviving = gateway.scheduled
          .where((n) => isReminderNotificationId(n.id))
          .toList();
      expect(surviving, hasLength(1),
          reason: 're-arming the adhan must not delete a reminder');
      expect(surviving.single.id, reminderNotificationId(1));
    });

    test('the window still clears its own range completely', () async {
      // The other half: sparing reminders must not leave stale adhan alarms.
      final stale = ScheduledNotification(
        id: notificationIdFor(DateTime(2020, 1, 2), NotificationSlot.adhanFajr),
        slot: NotificationSlot.adhanFajr,
        when: DateTime(2020, 1, 2, 5),
        title: 'قديم',
        body: 'قديم',
        channelId: channelAdhan,
      );
      await gateway.schedule(stale);

      await RollingWindowScheduler(
        gateway: gateway,
        prayerTimes: const PrayerTimesService(),
        clock: () => DateTime(2026, 9, 19, 12),
      ).rearm(const SchedulingConfig(
        geo: GeoConfig(
          latitude: 29.3759,
          longitude: 47.9774,
          method: 'kuwait',
          madhab: 'shafi',
        ),
        iqamaOffsets: {
          'fajr': 20,
          'dhuhr': 15,
          'asr': 15,
          'maghrib': 10,
          'isha': 15,
        },
      ));

      expect(gateway.scheduled.where((n) => n.id == stale.id), isEmpty);
      expect(gateway.cancelledBelow, [kReminderIdBase]);
    });
  });
}
