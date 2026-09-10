import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_gateway.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

import '../../support/fake_notification_gateway.dart';

/// Answering a prayer has to reach back and silence the questions about it.
///
/// Both follow-ups are armed hours in advance and cannot learn they have been
/// answered. Deterministic ids are what make the fix cheap: the alarm for a
/// date and slot is derivable, so it can be cancelled without having stored
/// anything about it.
void main() {
  late FakeNotificationGateway gateway;
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

  setUp(() async {
    gateway = FakeNotificationGateway();
    await RollingWindowScheduler(
      gateway: gateway,
      prayerTimes: const PrayerTimesService(),
      clock: () => now,
    ).rearm(config);
  });

  int idFor(NotificationSlot slot) =>
      notificationIdFor(DateTime(2026, 9, 7), slot);

  test('cancelling both asr follow-ups leaves the asr adhan armed', () async {
    expect(await gateway.pendingIds(), contains(idFor(NotificationSlot.adhanAsr)));

    await gateway.cancel(idFor(NotificationSlot.followUpAsr));
    await gateway.cancel(idFor(NotificationSlot.followUp2Asr));

    final pending = await gateway.pendingIds();
    expect(pending, isNot(contains(idFor(NotificationSlot.followUpAsr))));
    expect(pending, isNot(contains(idFor(NotificationSlot.followUp2Asr))));

    // The adhan is not a question and is never silenced by an answer.
    expect(pending, contains(idFor(NotificationSlot.adhanAsr)));
    expect(pending, contains(idFor(NotificationSlot.iqamaAsr)));
  });

  test('answering one prayer does not silence another', () async {
    await gateway.cancel(idFor(NotificationSlot.followUpAsr));
    await gateway.cancel(idFor(NotificationSlot.followUp2Asr));

    final pending = await gateway.pendingIds();
    for (final slot in [
      NotificationSlot.followUpFajr,
      NotificationSlot.followUpDhuhr,
      NotificationSlot.followUpMaghrib,
      NotificationSlot.followUpIsha,
    ]) {
      expect(pending, contains(idFor(slot)), reason: slot.name);
    }
  });

  test('a cancelled id is the one the scheduler actually armed', () async {
    // The whole scheme rests on both sides deriving the same number. If the
    // id space ever drifts, the cancel silently misses and the user is asked
    // about a prayer they already logged.
    final armed = gateway
        .ofSlot(NotificationSlot.followUp2Dhuhr)
        .firstWhere((n) => n.when.day == 7);
    expect(armed.id, idFor(NotificationSlot.followUp2Dhuhr));
  });

  test('cancelling twice is harmless', () async {
    // A prayer can be logged, cleared and logged again.
    final id = idFor(NotificationSlot.followUpAsr);
    await gateway.cancel(id);
    await gateway.cancel(id);
    expect(await gateway.pendingIds(), isNot(contains(id)));
  });

  test('the daily summary survives answering a single prayer', () async {
    // It reviews the whole day, so one answer must not remove it.
    await gateway.cancel(idFor(NotificationSlot.followUpAsr));
    expect(await gateway.pendingIds(),
        contains(idFor(NotificationSlot.dailySummary)));
  });

  test('every follow-up slot has a distinct id', () async {
    final ids = <int>{};
    for (final slot in NotificationSlot.values) {
      expect(ids.add(idFor(slot)), isTrue, reason: '${slot.name} collides');
    }
  });

  test('the gateway contract includes cancel', () {
    expect(gateway, isA<NotificationGateway>());
  });
}
