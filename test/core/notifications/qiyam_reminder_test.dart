import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_channels_ids.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/shift.dart';
import 'package:nouri/features/prayers/qiyam.dart';

import '../../support/fake_notification_gateway.dart';

/// قيام الليل — §5.1 of the brief: "a reminder, timed around the user's sleep
/// schedule". It was the one item in the religious pillar with no code at all.
void main() {
  group('when the night allows it', () {
    // isha 20:00, fajr 04:00 — an eight-hour night, so the last third opens at
    // 01:20.
    final isha = DateTime(2026, 9, 8, 20, 0);
    final fajr = DateTime(2026, 9, 9, 4, 0);

    test('it lands inside the last third, not at its opening', () {
      final at = qiyamTimeFor(isha: isha, fajrTomorrow: fajr,
          shift: ShiftType.morning)!;
      expect(at.isAfter(DateTime(2026, 9, 9, 1, 20)), isTrue,
          reason: 'the last third opens at 01:20');
      expect(at.isBefore(fajr), isTrue);
    });

    test('it leaves room before fajr, so it is not a second fajr alarm', () {
      final at = qiyamTimeFor(isha: isha, fajrTomorrow: fajr,
          shift: ShiftType.morning)!;
      expect(fajr.difference(at).inMinutes, greaterThanOrEqualTo(45));
    });

    test('a late isha and an early fajr still leave a usable gap', () {
      // Ramadan-shaped: isha 21:30, fajr 03:20. The last third opens at 01:26
      // and the 45-minute floor bites, so the answer must be the floor rather
      // than something past fajr.
      final at = qiyamTimeFor(
        isha: DateTime(2026, 4, 10, 21, 30),
        fajrTomorrow: DateTime(2026, 4, 11, 3, 20),
        shift: ShiftType.morning,
      )!;
      expect(at.isBefore(DateTime(2026, 4, 11, 3, 20)), isTrue);
      expect(DateTime(2026, 4, 11, 3, 20).difference(at).inMinutes,
          greaterThanOrEqualTo(45));
    });

    test('the date is carried by the night, not by a day step', () {
      // The night crosses midnight. Constructing it from the two prayer times
      // rather than offsetting a date is what keeps it right across DST —
      // measured in this project: 2026-10-29 plus twenty-four hours is the
      // same date on Egypt time.
      final at = qiyamTimeFor(
        isha: DateTime(2026, 10, 29, 18, 0),
        fajrTomorrow: DateTime(2026, 10, 30, 4, 30),
        shift: ShiftType.morning,
      )!;
      expect(at.day, 30);
      expect(at.month, 10);
    });
  });

  group('when it does not', () {
    test('a night shift gets none — duty runs through the whole last third',
        () {
      // 22:00 to 07:00. Every minute of the last third is work, so a
      // reminder there is noise rather than an invitation.
      expect(
        qiyamTimeFor(
          isha: DateTime(2026, 9, 8, 20, 0),
          fajrTomorrow: DateTime(2026, 9, 9, 4, 0),
          shift: ShiftType.night,
        ),
        isNull,
      );
    });

    test('a night too short to divide gets none', () {
      // Nothing sensible to offer when isha and fajr are three hours apart.
      expect(
        qiyamTimeFor(
          isha: DateTime(2026, 6, 21, 22, 30),
          fajrTomorrow: DateTime(2026, 6, 22, 1, 15),
          shift: ShiftType.morning,
        ),
        isNull,
      );
    });
  });

  group('in the window', () {
    late FakeNotificationGateway gateway;
    late RollingWindowScheduler scheduler;
    final now = DateTime(2026, 9, 5, 6, 0);

    const base = SchedulingConfig(
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

    test('off by default — Nouri does not opt anyone into waking at 2am', () {
      expect(base.notifyQiyam, isFalse);
    });

    test('with it off, nothing is armed', () async {
      await scheduler.rearm(base);
      expect(gateway.ofSlot(NotificationSlot.qiyam), isEmpty);
    });

    test('with it on, one per night across the window', () async {
      await scheduler.rearm(base.copyWith(notifyQiyam: true));
      expect(gateway.ofSlot(NotificationSlot.qiyam).length, kWindowDays);
    });

    test('a night shift arms none of them', () async {
      await scheduler.rearm(
        base.copyWith(notifyQiyam: true, shift: ShiftType.night),
      );
      expect(gateway.ofSlot(NotificationSlot.qiyam), isEmpty,
          reason: 'the user is at work through every last third');
    });

    test('it is not an adhan, and does not use the adhan channel', () async {
      await scheduler.rearm(base.copyWith(notifyQiyam: true));
      for (final n in gateway.ofSlot(NotificationSlot.qiyam)) {
        expect(n.channelId, isNot(channelAdhan));
      }
    });

    test('each one falls in the small hours it belongs to', () async {
      await scheduler.rearm(base.copyWith(notifyQiyam: true));
      for (final n in gateway.ofSlot(NotificationSlot.qiyam)) {
        expect(n.when.hour, lessThan(6),
            reason: '${n.when} is not the last third of any night');
      }
    });

    test('it invites, and never accuses', () async {
      await scheduler.rearm(base.copyWith(notifyQiyam: true));
      final n = gateway.ofSlot(NotificationSlot.qiyam).first;
      for (final word in ['فاتتك', 'ضيعت', 'فشل', 'كسلان', 'لازم']) {
        expect('${n.title} ${n.body}'.contains(word), isFalse,
            reason: 'found «$word» in «${n.title} — ${n.body}»');
      }
    });

    test('nothing is armed into the past', () async {
      await scheduler.rearm(base.copyWith(notifyQiyam: true));
      for (final n in gateway.ofSlot(NotificationSlot.qiyam)) {
        expect(n.when.isAfter(now), isTrue);
      }
    });
  });
}
