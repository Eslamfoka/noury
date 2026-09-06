import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/follow_up_plan.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

void main() {
  // Today's real Kuwait times, so the cases are the ones the user actually
  // lives through rather than invented ones.
  final dhuhr = PrayerSlot('dhuhr', DateTime(2026, 9, 6, 11, 46));
  final asr = DateTime(2026, 9, 6, 15, 18);
  final maghrib = PrayerSlot('maghrib', DateTime(2026, 9, 6, 18, 4));
  final isha = DateTime(2026, 9, 6, 19, 23);

  group('first ask', () {
    test('lands after iqama plus the prayer itself plus a buffer', () {
      final times = followUpsFor(
        slot: dhuhr,
        iqama: DateTime(2026, 9, 6, 12, 1),
        nextAdhan: asr,
      );
      // 12:01 iqama + 10 prayer + 10 buffer
      expect(times.first, DateTime(2026, 9, 6, 12, 21));
    });

    test('never arrives while the congregation is still praying', () {
      final iqama = DateTime(2026, 9, 6, 12, 1);
      final times = followUpsFor(slot: dhuhr, iqama: iqama, nextAdhan: asr);
      expect(times.first.difference(iqama).inMinutes, greaterThanOrEqualTo(15),
          reason: 'the old flow asked 10 minutes after iqama');
    });

    test('a longer iqama offset pushes the question later', () {
      final short = followUpsFor(
        slot: dhuhr,
        iqama: DateTime(2026, 9, 6, 11, 56),
        nextAdhan: asr,
      );
      final long = followUpsFor(
        slot: dhuhr,
        iqama: DateTime(2026, 9, 6, 12, 11),
        nextAdhan: asr,
      );
      expect(long.first.isAfter(short.first), isTrue);
    });

    test('a user who prays quickly at home can shorten it', () {
      final times = followUpsFor(
        slot: dhuhr,
        iqama: DateTime(2026, 9, 6, 12, 1),
        nextAdhan: asr,
        policy: const FollowUpPolicy(
          prayerDuration: Duration(minutes: 3),
          buffer: Duration(minutes: 2),
        ),
      );
      expect(times.first, DateTime(2026, 9, 6, 12, 6));
    });
  });

  group('second ask', () {
    test('follows an hour later when there is room', () {
      final times = followUpsFor(
        slot: dhuhr,
        iqama: DateTime(2026, 9, 6, 12, 1),
        nextAdhan: asr,
      );
      expect(times.second, DateTime(2026, 9, 6, 13, 21));
    });

    test('is capped short of the next adhan', () {
      // Maghrib 18:04, iqama 18:14 -> first ask 18:34. An hour later is 19:34,
      // which is after isha at 19:23 — it must be pulled back.
      final times = followUpsFor(
        slot: maghrib,
        iqama: DateTime(2026, 9, 6, 18, 14),
        nextAdhan: isha,
      );
      expect(times.second, isNotNull);
      expect(times.second!.isBefore(isha), isTrue);
      expect(isha.difference(times.second!).inMinutes, 15,
          reason: 'stops a guard interval short of the next adhan');
    });

    test('is dropped entirely when the prayers are too close', () {
      // A tight maghrib-to-isha gap leaves no useful room.
      final times = followUpsFor(
        slot: maghrib,
        iqama: DateTime(2026, 9, 6, 18, 14),
        nextAdhan: DateTime(2026, 9, 6, 18, 55),
      );
      expect(times.second, isNull,
          reason: 'better to ask once than to nag twice in half an hour');
      expect(times.all, hasLength(1));
    });

    test('isha has no next adhan, so it simply follows an hour later', () {
      final times = followUpsFor(
        slot: PrayerSlot('isha', isha),
        iqama: DateTime(2026, 9, 6, 19, 38),
        nextAdhan: null,
      );
      expect(times.second, DateTime(2026, 9, 6, 20, 58));
    });
  });

  group('the whole day', () {
    test('every prayer gets at least one ask', () {
      final cases = [
        (dhuhr, DateTime(2026, 9, 6, 12, 1), asr),
        (maghrib, DateTime(2026, 9, 6, 18, 14), isha),
      ];
      for (final (slot, iqama, next) in cases) {
        final times =
            followUpsFor(slot: slot, iqama: iqama, nextAdhan: next);
        expect(times.all, isNotEmpty, reason: slot.name);
      }
    });

    test('no ask ever lands after the next adhan', () {
      final times = followUpsFor(
        slot: maghrib,
        iqama: DateTime(2026, 9, 6, 18, 14),
        nextAdhan: isha,
      );
      for (final t in times.all) {
        expect(t.isBefore(isha), isTrue, reason: '$t is past the next adhan');
      }
    });

    test('asks are always in order', () {
      final times = followUpsFor(
        slot: dhuhr,
        iqama: DateTime(2026, 9, 6, 12, 1),
        nextAdhan: asr,
      );
      expect(times.second!.isAfter(times.first), isTrue);
    });
  });
}
