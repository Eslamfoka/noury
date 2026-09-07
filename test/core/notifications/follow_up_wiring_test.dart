import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_channels_ids.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/features/fasting/sunnah_fasting.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

import '../../support/fake_notification_gateway.dart';

/// The follow-up redesign, as actually scheduled.
///
/// The policy itself is covered by follow_up_plan_test. These assert the
/// wiring: that the scheduler uses it, on the right window, with the right
/// channel — the step that was deliberately left undone until the real dhuhr
/// adhan was confirmed on the device.
void main() {
  late FakeNotificationGateway gateway;
  late RollingWindowScheduler scheduler;

  /// Just after midnight, so the whole of day 0 is still ahead and no
  /// assertion depends on which prayers have already passed.
  final now = DateTime(2026, 9, 7, 0, 30);

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

  group('when the first ask lands', () {
    test('after iqama plus the prayer, never at the adhan', () async {
      await scheduler.rearm(config);

      final times = const PrayerTimesService()
          .forDate(DateTime(2026, 9, 7), GeoConfig.kuwaitCity);
      final dhuhr = times.dhuhr;
      final ask = gateway
          .ofSlot(NotificationSlot.followUpDhuhr)
          .firstWhere((n) => n.when.day == 7);

      // iqama is dhuhr + 15, then 10 minutes of prayer and 10 of grace.
      expect(ask.when, dhuhr.add(const Duration(minutes: 35)));

      // The old behaviour asked 25 minutes after the adhan, which on a
      // 15-minute iqama landed 10 minutes into the congregation.
      expect(ask.when, isNot(dhuhr.add(const Duration(minutes: 25))));
      expect(ask.when.isAfter(dhuhr), isTrue);
    });

    test('never before the prayer it asks about', () async {
      await scheduler.rearm(config);
      final times = const PrayerTimesService()
          .forDate(DateTime(2026, 9, 7), GeoConfig.kuwaitCity);

      for (final entry in {
        NotificationSlot.followUpFajr: times.fajr,
        NotificationSlot.followUpDhuhr: times.dhuhr,
        NotificationSlot.followUpAsr: times.asr,
        NotificationSlot.followUpMaghrib: times.maghrib,
        NotificationSlot.followUpIsha: times.isha,
      }.entries) {
        for (final n in gateway.ofSlot(entry.key)) {
          if (n.when.day != 7) continue;
          expect(n.when.isAfter(entry.value), isTrue, reason: entry.key.name);
        }
      }
    });
  });

  group('the second ask', () {
    test('is scheduled, and lands after the first', () async {
      await scheduler.rearm(config);

      final first = gateway
          .ofSlot(NotificationSlot.followUpDhuhr)
          .firstWhere((n) => n.when.day == 7);
      final second = gateway
          .ofSlot(NotificationSlot.followUp2Dhuhr)
          .firstWhere((n) => n.when.day == 7);

      expect(second.when.isAfter(first.when), isTrue);
      expect(second.when.difference(first.when),
          lessThanOrEqualTo(const Duration(minutes: 60)));
    });

    test('never collides with the next adhan', () async {
      await scheduler.rearm(config);
      final times = const PrayerTimesService()
          .forDate(DateTime(2026, 9, 7), GeoConfig.kuwaitCity);

      for (final entry in {
        NotificationSlot.followUp2Fajr: times.dhuhr,
        NotificationSlot.followUp2Dhuhr: times.asr,
        NotificationSlot.followUp2Asr: times.maghrib,
        NotificationSlot.followUp2Maghrib: times.isha,
      }.entries) {
        for (final n in gateway.ofSlot(entry.key)) {
          if (n.when.day != 7) continue;
          expect(n.when.isBefore(entry.value), isTrue,
              reason: '${entry.key.name} must not reach the next adhan');
          expect(entry.value.difference(n.when),
              greaterThanOrEqualTo(const Duration(minutes: 15)),
              reason: '${entry.key.name} must keep clear of the next adhan');
        }
      }
    });

    test('is dropped when there is no room left before the next adhan',
        () async {
      // Maghrib to isha is only about 79 minutes in Kuwait in September. With
      // the default 10-minute iqama there is still room for a capped second
      // ask, but a longer iqama closes the gap — and a question crammed into
      // what is left would be nagging rather than helping.
      await scheduler.rearm(
        config.copyWith(iqamaOffsets: {...config.iqamaOffsets, 'maghrib': 30}),
      );

      final times = const PrayerTimesService()
          .forDate(DateTime(2026, 9, 7), GeoConfig.kuwaitCity);
      final gap = times.isha.difference(times.maghrib);
      expect(gap, lessThan(const Duration(minutes: 90)),
          reason: 'the premise of this test is a short maghrib-isha gap');

      expect(
        gateway
            .ofSlot(NotificationSlot.followUp2Maghrib)
            .where((n) => n.when.day == 7),
        isEmpty,
      );

      // The first ask survives. Dropping the follow-up entirely would be a
      // worse failure than asking once.
      expect(
        gateway
            .ofSlot(NotificationSlot.followUpMaghrib)
            .where((n) => n.when.day == 7),
        isNotEmpty,
      );
    });

    test('carries the log action, like the first', () async {
      await scheduler.rearm(config);
      for (final n in gateway.ofSlot(NotificationSlot.followUp2Dhuhr)) {
        expect(n.payload, 'log:dhuhr');
        expect(n.channelId, channelGeneral);
      }
    });

    test('does not repeat the first ask word for word', () async {
      await scheduler.rearm(config);
      final first = gateway.ofSlot(NotificationSlot.followUpDhuhr).first;
      final second = gateway.ofSlot(NotificationSlot.followUp2Dhuhr).first;
      expect(second.body, isNot(first.body));
    });
  });

  group('the daily summary', () {
    test('is scheduled at the configured hour', () async {
      await scheduler.rearm(config);
      final summaries = gateway.ofSlot(NotificationSlot.dailySummary);
      expect(summaries, isNotEmpty);
      for (final n in summaries) {
        expect(n.when.hour, 22);
        expect(n.payload, 'review:daily');
      }
    });

    test('reads correctly on a day with nothing outstanding', () async {
      // It is armed days ahead and cannot know what will be logged, so it may
      // never assert that something was missed.
      await scheduler.rearm(config);
      final body = gateway.ofSlot(NotificationSlot.dailySummary).first.body;
      for (final word in ['فاتك', 'فاتتك', 'نسيت', 'ضيعت', 'مقصر']) {
        expect(body.contains(word), isFalse, reason: 'accuses: $word');
      }
      expect(body, contains('؟'), reason: 'an invitation, not a verdict');
    });
  });

  group('windows', () {
    test('follow-ups are armed for fewer days than the adhan', () async {
      await scheduler.rearm(config);

      Set<int> daysOf(NotificationSlot s) =>
          gateway.ofSlot(s).map((n) => n.when.day).toSet();

      expect(daysOf(NotificationSlot.adhanDhuhr).length, kWindowDays);
      expect(daysOf(NotificationSlot.followUpDhuhr).length,
          kFollowUpWindowDays);
      expect(daysOf(NotificationSlot.dailySummary).length,
          kFollowUpWindowDays);
      expect(kFollowUpWindowDays, lessThan(kWindowDays));
    });

    test('the adhan still survives a fortnight unopened', () async {
      // The reason the window exists at all. Shortening the follow-up window
      // must not have shortened this one.
      await scheduler.rearm(config);
      final lastAdhan = gateway
          .ofSlot(NotificationSlot.adhanDhuhr)
          .map((n) => n.when)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      expect(lastAdhan.difference(now).inDays, greaterThanOrEqualTo(13));
    });

    test('arms 229 alarms, well inside the pending-alarm cap', () async {
      // 14 days x 14 core alarms (5 adhan, 5 iqama, 3 athkar, 1 wird) = 196,
      // plus 3 days x 11 follow-ups (5 first asks, 5 second, 1 summary) = 33.
      //
      // The exact number is pinned deliberately. Arming every slot for the
      // full fortnight would cost 350, and Android starts dropping alarms
      // somewhere past 500 — silently, which is the worst way to find out.
      //
      // Fasting is excluded here rather than folded in: how many sunnah fasts
      // fall in a fortnight depends on the date, and a count that moved with
      // the calendar could not pin anything. It is bounded in the next test.
      await scheduler.rearm(
          config.copyWith(notifyFasting: false, notifyWater: false));
      expect(gateway.scheduled.length, 229);
    });

    test('the fasting offers add at most a handful on top', () async {
      // Two Mondays and two Thursdays fall in any fortnight, and the three
      // white days fall wholly inside it or not at all. Overlaps count once,
      // and the days fasting is prohibited are dropped — so the ceiling is
      // seven, and the floor is the four weekdays.
      await scheduler.rearm(config.copyWith(notifyWater: false));
      final fasting = gateway.ofSlot(NotificationSlot.fastingEve).length;
      expect(fasting, inInclusiveRange(4, 7));
      expect(gateway.scheduled.length, 229 + fasting);
    });

    test('water rides the short window, not the fortnight', () async {
      // Five a day for three days. Arming them for a fortnight would cost 70
      // alarms out of a budget the adhan has first call on, for nudges nobody
      // needs twelve days ahead.
      await scheduler.rearm(config);
      final water = gateway.scheduled
          .where((n) => n.payload == 'water')
          .length;
      expect(water, lessThanOrEqualTo(5 * kFollowUpWindowDays));
      expect(water, greaterThan(0));
    });

    test('the whole window stays well inside the pending-alarm cap', () async {
      await scheduler.rearm(config);
      expect(gateway.scheduled.length, lessThan(400),
          reason: 'Android drops alarms past ~500, silently');
    });

    test('a fasting day gets no daytime water reminder', () async {
      // The rule that matters: telling a fasting person to drink at noon
      // would be Nouri telling them to break it.
      final fasting = DateTime(2026, 9, 6);
      await scheduler.rearm(config.copyWith(fastingDays: {fasting}));

      final onThatDay = gateway.scheduled.where((n) =>
          n.payload == 'water' &&
          n.when.year == fasting.year &&
          n.when.month == fasting.month &&
          n.when.day == fasting.day);

      for (final n in onThatDay) {
        expect(n.when.hour, greaterThanOrEqualTo(18),
            reason: 'a water nudge at ${n.when} is inside the fast');
      }
    });

    test('every fasting offer lands the evening before its day', () async {
      await scheduler.rearm(config);
      for (final n in gateway.ofSlot(NotificationSlot.fastingEve)) {
        final tomorrow =
            DateTime(n.when.year, n.when.month, n.when.day + 1);
        expect(sunnahFastFor(tomorrow), isNotNull,
            reason: 'an offer on ${n.when} is about a day that is not a fast');
        expect(n.when.hour, 20);
      }
    });
  });
}
