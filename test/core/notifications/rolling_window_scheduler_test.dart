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
    expect(gateway.cancelAllCount, 2, reason: 'each rearm clears first');
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
    await scheduler.rearm(config.copyWith(notifyAdhan: false));
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
    await scheduler.rearm(config);
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
