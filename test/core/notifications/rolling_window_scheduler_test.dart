import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

import '../../support/fake_notification_gateway.dart';

void main() {
  late FakeNotificationGateway gateway;
  late RollingWindowScheduler scheduler;

  /// A fixed "now": 2026-09-05 at 06:00 machine-local — after fajr (04:06
  /// Kuwait) and before dhuhr. Freezing the clock is what makes the
  /// "never schedules into the past" assertions meaningful.
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

  test('schedules a full window, one entry per day', () async {
    await scheduler.rearm(config);
    final days = gateway.scheduled
        .map((n) => DateTime(n.when.year, n.when.month, n.when.day))
        .toSet();
    expect(days.length, kWindowDays);
  });

  test('never schedules anything in the past', () async {
    await scheduler.rearm(config);
    for (final n in gateway.scheduled) {
      expect(n.when.isAfter(now), isTrue,
          reason: '${n.slot.name} at ${n.when} is behind now');
    }
  });

  test('today already-passed prayers are skipped, not backdated', () async {
    await scheduler.rearm(config);
    expect(
      gateway.ofSlot(NotificationSlot.adhanFajr).where((n) => n.when.day == 5),
      isEmpty,
      reason: 'fajr passed before 06:00',
    );
    expect(
      gateway.ofSlot(NotificationSlot.adhanDhuhr).where((n) => n.when.day == 5),
      hasLength(1),
      reason: 'dhuhr is still ahead',
    );
  });

  test('re-arming is idempotent — the same IDs, never duplicates', () async {
    await scheduler.rearm(config);
    final first = (await gateway.pendingIds())..sort();

    await scheduler.rearm(config);
    final second = (await gateway.pendingIds())..sort();

    expect(second, equals(first));
    expect(second.toSet().length, second.length, reason: 'duplicate IDs');
  });

  test('a re-arm does not cancel the alarms it is about to rewrite', () async {
    // The cost of a launch, in one assertion.
    //
    // `rearm` used to clear the whole window and then write all of it back:
    // ~265 cancels followed by ~265 schedules, every launch. Each of those
    // crosses a platform channel, and each one also rewrites the plugin's
    // entire boot cache — it loads the whole JSON array, removes or replaces
    // one entry, and saves the array again — so the pass is quadratic in the
    // size of the window. Measured at 42s on a cold emulator and 11.7s on the
    // user's HONOR.
    //
    // Half of it was never needed. Scheduling an id that is already pending
    // replaces it: AlarmManager cancels the alarm held under an equal
    // PendingIntent before setting the new one, and the plugin keys that
    // PendingIntent on the notification id. So cancelling an id the very next
    // loop is about to write is paying twice for one outcome.
    await scheduler.rearm(config);
    final armed = (await gateway.pendingIds()).toSet();
    gateway.cancelled.clear();

    await scheduler.rearm(config);

    expect(gateway.cancelled.where(armed.contains), isEmpty,
        reason: 'cancelled ids the same pass then rewrote');
    expect(gateway.cancelAllCount, 0,
        reason: 'a blanket clear is the thing being removed');
  });

  test('an alarm that drops out of the window is still cancelled', () async {
    // The other half, which is the half that has to keep working. Turning the
    // iqama off must leave nothing behind ringing.
    await scheduler.rearm(config);
    final iqamaIds = gateway
        .ofSlot(NotificationSlot.iqamaAsr)
        .map((n) => n.id)
        .toSet();
    expect(iqamaIds, isNotEmpty);
    gateway.cancelled.clear();

    await scheduler.rearm(config.copyWith(notifyIqama: false));

    expect(gateway.ofSlot(NotificationSlot.iqamaAsr), isEmpty);
    expect(gateway.cancelled.toSet().containsAll(iqamaIds), isTrue,
        reason: 'every dropped iqama alarm must be named and cancelled');
  });

  test('a re-arm clears an alarm it could never have numbered itself',
      () async {
    // The orphan property, restated against `rearm` rather than against the
    // gateway, because `rearm` is now the thing that decides what to cancel.
    //
    // Widening `kSlotsPerDay` renumbers every future alarm. Alarms already in
    // AlarmManager under the old stride would be unreachable if the clear
    // worked by recomputing ids — the app could never name them again, so it
    // could never cancel them, and they would go on firing. It works by
    // enumerating what is *pending* and cancelling anything under the ceiling
    // the new window does not want, whatever its number.
    const orphan = 78000 * 32 + 7;
    const reminder = kOutOfWindowIdBase + 1;
    for (final id in [orphan, reminder]) {
      await gateway.schedule(ScheduledNotification(
        id: id,
        slot: NotificationSlot.adhanFajr,
        when: DateTime(2026, 9, 9),
        title: 't',
        body: 'b',
        channelId: 'adhan_v2',
      ));
    }

    await scheduler.rearm(config);

    expect(gateway.cancelled, contains(orphan));
    expect(gateway.scheduled.map((n) => n.id), contains(reminder),
        reason: 'a reminder lives above the ceiling and must survive');
    expect(gateway.cancelled, isNot(contains(reminder)));
  });

  test('the window stays inside the Android pending-alarm budget', () async {
    // Android caps pending alarms per app at roughly 500. A day costs 19
    // alarms, so the window length is bounded by that budget -- this is the
    // test that fails if someone widens the window without checking.
    await scheduler.rearm(config);
    expect(gateway.scheduled.length, lessThan(400),
        reason: 'leaves headroom below the ~500 cap');
    expect(gateway.scheduled.length, greaterThan(kWindowDays * 15),
        reason: 'every day should be fully populated');
  });

  test('the window still covers 14 distinct days across a DST boundary',
      () async {
    // The regression. Egypt's clocks go back on 30 October 2026, and measured
    // on this machine `DateTime(2026, 10, 29).add(Duration(days: 1))` is
    // 2026-10-29 23:00 — the *same date*. The window loop steps `today + i`,
    // so it visited the 29th twice and never reached the far end: fourteen
    // days of adhan quietly became thirteen, once a year.
    //
    // Zone-dependent by nature, so it asserts the property rather than the
    // dates: whatever zone this runs in, fourteen days means fourteen days.
    final autumn = RollingWindowScheduler(
      gateway: gateway,
      prayerTimes: const PrayerTimesService(),
      clock: () => DateTime(2026, 10, 29, 6, 0),
    );
    await autumn.rearm(config);

    final days = gateway.scheduled
        .map((n) => DateTime(n.when.year, n.when.month, n.when.day))
        .toSet();
    expect(days.length, kWindowDays,
        reason: 'the window lost a day to the clocks going back');
  });

  test('and across the spring boundary too', () async {
    final spring = RollingWindowScheduler(
      gateway: gateway,
      prayerTimes: const PrayerTimesService(),
      clock: () => DateTime(2026, 4, 23, 6, 0),
    );
    await spring.rearm(config);

    final days = gateway.scheduled
        .map((n) => DateTime(n.when.year, n.when.month, n.when.day))
        .toSet();
    expect(days.length, kWindowDays);
  });

  test('every ID in the window is unique', () async {
    await scheduler.rearm(config);
    final ids = await gateway.pendingIds();
    expect(ids.toSet().length, ids.length);
  });

  test('iqama fires exactly the configured offset after the adhan', () async {
    await scheduler.rearm(config);
    final adhan = gateway.ofSlot(NotificationSlot.adhanAsr).first;
    final iqama = gateway
        .ofSlot(NotificationSlot.iqamaAsr)
        .firstWhere((n) => n.when.day == adhan.when.day);
    expect(iqama.when.difference(adhan.when), const Duration(minutes: 15));
  });

  test('disabling iqama removes only iqama notifications', () async {
    await scheduler.rearm(config.copyWith(notifyIqama: false));
    expect(gateway.ofSlot(NotificationSlot.iqamaAsr), isEmpty);
    expect(gateway.ofSlot(NotificationSlot.adhanAsr), isNotEmpty);
  });

  test('disabling adhan still leaves the athkar and wird reminders', () async {
    // `notifyTasks: false` because these two reminders are the *legacy* path
    // — with the task alarms on, the day plan announces the athkar and the
    // wird instead, and arming both meant two rings for one task. See
    // one_sound_per_thing_test.
    await scheduler
        .rearm(config.copyWith(notifyAdhan: false, notifyTasks: false));
    expect(gateway.ofSlot(NotificationSlot.adhanFajr), isEmpty);
    expect(gateway.ofSlot(NotificationSlot.followUpFajr), isEmpty,
        reason: 'the follow-up belongs to the adhan');
    expect(gateway.ofSlot(NotificationSlot.morningAthkar), isNotEmpty);
    expect(gateway.ofSlot(NotificationSlot.quranWird), isNotEmpty);
  });

  test('disabling everything schedules nothing at all', () async {
    await scheduler.rearm(config.copyWith(
      notifyAdhan: false,
      notifyIqama: false,
      notifyAthkar: false,
      notifyWird: false,
      notifyFasting: false,
      notifyWater: false,
      notifyTasks: false,
    ));
    expect(gateway.scheduled, isEmpty);
  });

  test('changing the iqama offset moves the iqama and nothing else', () async {
    await scheduler.rearm(config);
    final before = gateway.ofSlot(NotificationSlot.iqamaMaghrib).first.when;
    final adhanBefore = gateway.ofSlot(NotificationSlot.adhanMaghrib).first.when;

    await scheduler.rearm(config.copyWith(iqamaOffsets: const {
      'fajr': 20,
      'dhuhr': 15,
      'asr': 15,
      'maghrib': 25,
      'isha': 15,
    }));
    final after = gateway.ofSlot(NotificationSlot.iqamaMaghrib).first.when;
    final adhanAfter = gateway.ofSlot(NotificationSlot.adhanMaghrib).first.when;

    expect(after.difference(before), const Duration(minutes: 15));
    expect(adhanAfter, adhanBefore);
  });

  test('changing location reschedules to different times', () async {
    await scheduler.rearm(config);
    final kuwaitFajr = gateway.ofSlot(NotificationSlot.adhanFajr).first.when;

    // Cairo — same timezone family, meaningfully different longitude.
    await scheduler.rearm(config.copyWith(
      geo: const GeoConfig(
        latitude: 30.0444,
        longitude: 31.2357,
        method: 'egyptian',
        madhab: 'shafi',
      ),
    ));
    final cairoFajr = gateway.ofSlot(NotificationSlot.adhanFajr).first.when;
    expect(cairoFajr, isNot(kuwaitFajr));
  });

  test('the follow-up lands after its adhan, not before', () async {
    await scheduler.rearm(config);
    final adhan = gateway.ofSlot(NotificationSlot.adhanAsr).first;
    final followUp = gateway
        .ofSlot(NotificationSlot.followUpAsr)
        .firstWhere((n) => n.when.day == adhan.when.day);
    expect(followUp.when.isAfter(adhan.when), isTrue);
  });

  test('evening athkar ride on maghrib rather than a fixed hour', () async {
    // The legacy reminder, so `notifyTasks: false` — see above. The task
    // alert that replaces it rides maghrib too, by a planner anchor rather
    // than by this subtraction.
    await scheduler.rearm(config.copyWith(notifyTasks: false));
    final maghrib = gateway.ofSlot(NotificationSlot.adhanMaghrib).first;
    final evening = gateway
        .ofSlot(NotificationSlot.eveningAthkar)
        .firstWhere((n) => n.when.day == maghrib.when.day);
    expect(maghrib.when.difference(evening.when), const Duration(minutes: 45));
  });

  test('every scheduled notification carries a channel and a title', () async {
    await scheduler.rearm(config);
    for (final n in gateway.scheduled) {
      expect(n.channelId, isNotEmpty, reason: n.slot.name);
      expect(n.title, isNotEmpty, reason: n.slot.name);
      expect(n.body, isNotEmpty, reason: n.slot.name);
    }
  });

  test('no notification copy contains a punishing word', () async {
    await scheduler.rearm(config);
    const forbidden = ['فاتتك', 'ضيعت', 'فشل', 'خسرت', 'missed', 'failed'];
    for (final n in gateway.scheduled) {
      for (final w in forbidden) {
        expect(n.title.contains(w), isFalse, reason: 'title: ${n.title}');
        expect(n.body.contains(w), isFalse, reason: 'body: ${n.body}');
      }
    }
  });

  test('only follow-ups carry a log payload', () async {
    await scheduler.rearm(config);
    for (final n in gateway.scheduled) {
      final isFollowUp = n.slot.name.startsWith('followUp');
      expect(n.payload?.startsWith('log:') ?? false, isFollowUp,
          reason: '${n.slot.name} payload was ${n.payload}');
    }
  });
}
