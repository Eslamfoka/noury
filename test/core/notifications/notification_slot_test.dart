import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_slot.dart';

void main() {
  test('there are fewer slots than the per-day stride', () {
    // The single most consequential invariant in the ID scheme. IDs are
    // `daysSince2020 * kSlotsPerDay + slot.index`, so one slot too many makes
    // the last slot of one day collide with the first slot of the next —
    // silently, and only for whoever's alarm gets overwritten.
    //
    // There are 31 slots against a stride of 32. **There is one left.** Adding
    // two more means raising kSlotsPerDay, and that renumbers every alarm
    // already sitting on a device, so it needs a deliberate re-arm rather than
    // a quiet bump.
    expect(NotificationSlot.values.length, lessThan(kSlotsPerDay),
        reason: 'raise kSlotsPerDay deliberately, and re-arm — see the note '
            'on the enum');
  });

  test('IDs are unique across a full year and every slot', () {
    final seen = <int>{};
    for (var i = 0; i < 365; i++) {
      // Constructed, not offset. Stepping with `add(Duration(days: 1))` makes
      // this test's own correctness depend on the zone it runs in: measured on
      // Egypt time, 2026-10-29 plus twenty-four hours is 2026-10-29 23:00, the
      // same date — which would look like an ID collision that is really a
      // duplicated day in the test.
      final day = DateTime(2026, 1, 1 + i);
      for (final slot in NotificationSlot.values) {
        final id = notificationIdFor(day, slot);
        expect(seen.add(id), isTrue, reason: 'collision on $day / $slot');
      }
    }
  });

  test('the same date and slot always produce the same ID', () {
    final a = notificationIdFor(DateTime(2026, 9, 5), NotificationSlot.adhanAsr);
    final b =
        notificationIdFor(DateTime(2026, 9, 5, 23, 59), NotificationSlot.adhanAsr);
    expect(a, b, reason: 'time of day must not affect the ID');
  });

  test('IDs are reproducible after a restart — no stored state', () {
    // Re-arming from a cold start must land on exactly the same IDs, so alarms
    // are overwritten rather than duplicated.
    final before = [
      for (final s in NotificationSlot.values)
        notificationIdFor(DateTime(2026, 9, 5), s)
    ];
    final after = [
      for (final s in NotificationSlot.values)
        notificationIdFor(DateTime(2026, 9, 5), s)
    ];
    expect(after, before);
  });

  test('IDs stay inside the 32-bit range Android accepts', () {
    for (final d in [DateTime(2026, 1, 1), DateTime(2045, 12, 31)]) {
      for (final slot in NotificationSlot.values) {
        final id = notificationIdFor(d, slot);
        expect(id, greaterThan(0), reason: '$d / $slot');
        expect(id, lessThan(2147483647), reason: '$d / $slot');
      }
    }
  });

  test('consecutive days never overlap in ID space', () {
    final d1 = {
      for (final s in NotificationSlot.values)
        notificationIdFor(DateTime(2026, 9, 5), s)
    };
    final d2 = {
      for (final s in NotificationSlot.values)
        notificationIdFor(DateTime(2026, 9, 6), s)
    };
    expect(d1.intersection(d2), isEmpty);
  });

  test('every prayer has an adhan, an iqama and a follow-up slot', () {
    for (final p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(NotificationSlot.values.any((s) => s.name == 'adhan$p'), isTrue,
          reason: 'adhan$p');
      expect(NotificationSlot.values.any((s) => s.name == 'iqama$p'), isTrue,
          reason: 'iqama$p');
      expect(NotificationSlot.values.any((s) => s.name == 'followUp$p'), isTrue,
          reason: 'followUp$p');
    }
  });

  test('the wird and athkar slots exist', () {
    const expected = [
      NotificationSlot.morningAthkar,
      NotificationSlot.eveningAthkar,
      NotificationSlot.sleepAthkar,
      NotificationSlot.quranWird,
    ];
    for (final s in expected) {
      expect(NotificationSlot.values, contains(s));
    }
  });
}
