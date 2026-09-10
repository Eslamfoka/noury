import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_route.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

import '../../support/fake_notification_gateway.dart';

void main() {
  group('parsing', () {
    test('routes a follow-up to the log sheet for that prayer', () {
      expect(NotificationRoute.parse('log:asr'), const LogPrayerRoute('asr'));
    });

    test('routes the adhan to the prayer view', () {
      expect(
        NotificationRoute.parse('prayer:maghrib'),
        const PrayerRoute('maghrib'),
      );
    });

    test('routes the daily summary to the review', () {
      expect(NotificationRoute.parse('review:daily'),
          const DailyReviewRoute());
    });

    test('routes athkar and wird', () {
      expect(NotificationRoute.parse('athkar:morning'),
          const AthkarRoute('morning'));
      expect(NotificationRoute.parse('quran'), const QuranRoute());
    });

    test('returns null rather than throwing on anything unrecognised', () {
      // An alarm scheduled by an older version can still be sitting in
      // AlarmManager days after an upgrade. Crashing on tap would be a poor
      // thanks for updating.
      for (final bad in [
        null,
        '',
        'log',
        'log:',
        'review',
        'review:weekly',
        'nonsense',
        ':',
        'prayer:',
      ]) {
        expect(NotificationRoute.parse(bad), isNull, reason: '$bad');
      }
    });

    test('a colon inside the tail is kept intact', () {
      expect(NotificationRoute.parse('athkar:a:b'), const AthkarRoute('a:b'));
    });
  });

  group('every payload the scheduler emits is routable', () {
    test('no scheduled notification has a dead payload', () async {
      // The guard that matters: it is easy to add a notification and forget
      // the route, and the failure is silent — a tap that does nothing.
      final gateway = FakeNotificationGateway();
      final scheduler = RollingWindowScheduler(
        gateway: gateway,
        prayerTimes: const PrayerTimesService(),
        clock: () => DateTime(2026, 9, 7, 0, 30),
      );

      await scheduler.rearm(const SchedulingConfig(
        geo: GeoConfig.kuwaitCity,
        iqamaOffsets: {
          'fajr': 20,
          'dhuhr': 15,
          'asr': 15,
          'maghrib': 10,
          'isha': 15,
        },
      ));

      expect(gateway.scheduled, isNotEmpty);
      for (final n in gateway.scheduled) {
        expect(NotificationRoute.parse(n.payload), isNotNull,
            reason: '${n.slot.name} has payload "${n.payload}"');
      }
    });

    test('the follow-ups and the summary route where they should', () async {
      final gateway = FakeNotificationGateway();
      final scheduler = RollingWindowScheduler(
        gateway: gateway,
        prayerTimes: const PrayerTimesService(),
        clock: () => DateTime(2026, 9, 7, 0, 30),
      );
      await scheduler.rearm(const SchedulingConfig(
        geo: GeoConfig.kuwaitCity,
        iqamaOffsets: {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 10, 'isha': 15},
      ));

      for (final n in gateway.ofSlot(NotificationSlot.followUp2Asr)) {
        expect(NotificationRoute.parse(n.payload), const LogPrayerRoute('asr'));
      }
      for (final n in gateway.ofSlot(NotificationSlot.dailySummary)) {
        expect(NotificationRoute.parse(n.payload), const DailyReviewRoute());
      }
    });
  });
}
