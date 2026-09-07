import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/water/water_plan.dart';

final prayers = DailyPrayerTimes(
  fajr: DateTime(2026, 9, 7, 4, 8),
  sunrise: DateTime(2026, 9, 7, 5, 31),
  dhuhr: DateTime(2026, 9, 7, 11, 46),
  asr: DateTime(2026, 9, 7, 15, 18),
  maghrib: DateTime(2026, 9, 7, 18, 3),
  isha: DateTime(2026, 9, 7, 19, 22),
);

void main() {
  group('progress', () {
    test('reads as a fraction of the target', () {
      const p = WaterProgress(glasses: 4, target: 8);
      expect(p.fraction, 0.5);
      expect(p.remaining, 4);
      expect(p.isComplete, isFalse);
    });

    test('drinking past the target does not overflow the bar', () {
      const p = WaterProgress(glasses: 12, target: 8);
      expect(p.fraction, 1.0);
      expect(p.remaining, 0);
      expect(p.isComplete, isTrue);
    });

    test('a zero target never divides by zero', () {
      const p = WaterProgress(glasses: 3, target: 0);
      expect(p.fraction, 0);
      expect(p.arabicNote, isEmpty);
    });

    test('the note encourages and never scolds', () {
      const short = WaterProgress(glasses: 2, target: 8);
      expect(short.arabicNote, contains('فاضل'));
      for (final blame in ['فشل', 'قصّرت', 'كسلان', 'ضيعت']) {
        expect(short.arabicNote.contains(blame), isFalse);
      }
      expect(const WaterProgress(glasses: 0, target: 8).arabicNote,
          contains('ابدأ'));
    });

    test('numbers in the note are Arabic-Indic', () {
      const p = WaterProgress(glasses: 2, target: 8);
      expect(RegExp(r'[0-9]').hasMatch(p.arabicNote), isFalse);
    });
  });

  group('the fasting rule', () {
    test('an ordinary day allows a reminder at any hour', () {
      for (final hour in [5, 12, 16, 20]) {
        expect(
          waterReminderAllowed(
            at: DateTime(2026, 9, 7, hour),
            fastingToday: false,
            fajr: prayers.fajr,
            maghrib: prayers.maghrib,
          ),
          isTrue,
          reason: '$hour:00',
        );
      }
    });

    test('a fasting day allows nothing between fajr and maghrib', () {
      // The whole reason the rule exists: telling a fasting person to drink
      // water at noon would be Nouri telling them to break their fast.
      for (final hour in [5, 8, 12, 15, 17]) {
        expect(
          waterReminderAllowed(
            at: DateTime(2026, 9, 7, hour),
            fastingToday: true,
            fajr: prayers.fajr,
            maghrib: prayers.maghrib,
          ),
          isFalse,
          reason: '$hour:00 is inside the fast',
        );
      }
    });

    test('a fasting day still allows before fajr and after maghrib', () {
      expect(
        waterReminderAllowed(
          at: DateTime(2026, 9, 7, 3, 30),
          fastingToday: true,
          fajr: prayers.fajr,
          maghrib: prayers.maghrib,
        ),
        isTrue,
        reason: 'suhoor is before fajr',
      );
      expect(
        waterReminderAllowed(
          at: DateTime(2026, 9, 7, 19),
          fastingToday: true,
          fajr: prayers.fajr,
          maghrib: prayers.maghrib,
        ),
        isTrue,
        reason: 'after maghrib the fast is open',
      );
    });

    test('maghrib itself is allowed — that is when the fast opens', () {
      expect(
        waterReminderAllowed(
          at: prayers.maghrib,
          fastingToday: true,
          fajr: prayers.fajr,
          maghrib: prayers.maghrib,
        ),
        isTrue,
      );
    });
  });

  group('reminder times', () {
    test('one after each prayer on an ordinary day', () {
      final times =
          waterReminderTimes(prayers: prayers, fastingToday: false);
      expect(times, hasLength(5));
      for (var i = 0; i < 5; i++) {
        expect(times[i], prayers.ordered[i].time.add(const Duration(minutes: 25)));
      }
    });

    test('a fasting day keeps only the ones outside the fast', () {
      final times = waterReminderTimes(prayers: prayers, fastingToday: true);
      // Fajr+25 is inside the fast; dhuhr and asr are too. Maghrib+25 and
      // isha+25 are after it opens.
      expect(times, hasLength(2));
      for (final t in times) {
        expect(t.isAfter(prayers.maghrib), isTrue);
      }
    });

    test('the offset keeps clear of the prayer and its iqama', () {
      final times =
          waterReminderTimes(prayers: prayers, fastingToday: false);
      for (var i = 0; i < 5; i++) {
        expect(times[i].difference(prayers.ordered[i].time),
            greaterThanOrEqualTo(const Duration(minutes: 20)));
      }
    });
  });

  group('the wording', () {
    test('says so when the fast has just opened', () {
      expect(waterReminderBody(afterFast: true), contains('فطرت'));
      expect(waterReminderBody(afterFast: false), isNot(contains('فطرت')));
    });

    test('offers rather than instructs', () {
      for (final b in [
        waterReminderBody(afterFast: true),
        waterReminderBody(afterFast: false),
      ]) {
        expect(b.trim(), isNotEmpty);
        for (final blame in ['لازم', 'يجب', 'فشل']) {
          expect(b.contains(blame), isFalse, reason: b);
        }
      }
    });
  });

  group('the database', () {
    NouriDatabase fresh() {
      final db = NouriDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      return db;
    }

    test('glasses accumulate on one row per day', () async {
      final db = fresh();
      final day = DateTime(2026, 9, 7);
      await db.waterDao.add(day, 1, target: 8);
      await db.waterDao.add(day, 1, target: 8);
      await db.waterDao.add(day, 1, target: 8);

      final row = await db.waterDao.forDate(day);
      expect(row!.glasses, 3);
      expect(await db.waterDao.between(day, day), hasLength(1));
    });

    test('a mistap can be taken back, but never below zero', () async {
      final db = fresh();
      final day = DateTime(2026, 9, 7);
      await db.waterDao.add(day, 1, target: 8);
      await db.waterDao.add(day, -1, target: 8);
      await db.waterDao.add(day, -1, target: 8);
      expect((await db.waterDao.forDate(day))!.glasses, 0);
    });

    test('a day with nothing logged has no row rather than a zero', () async {
      expect(await fresh().waterDao.forDate(DateTime(2026, 9, 7)), isNull);
    });

    test('a fasting day is set by the user and can be unset', () async {
      final db = fresh();
      final day = DateTime(2026, 9, 7);
      expect(await db.waterDao.isFasting(day), isFalse,
          reason: 'never inferred — Nouri cannot know');

      await db.waterDao.setFasting(day, true);
      expect(await db.waterDao.isFasting(day), isTrue);

      await db.waterDao.setFasting(day, false);
      expect(await db.waterDao.isFasting(day), isFalse);
    });

    test('marking the same day twice is one row', () async {
      final db = fresh();
      final day = DateTime(2026, 9, 7);
      await db.waterDao.setFasting(day, true);
      await db.waterDao.setFasting(day, true);
      expect(await db.waterDao.fastingBetween(day, day), hasLength(1));
    });

    test('the day is normalised, so an evening tap lands on the day',
        () async {
      final db = fresh();
      await db.waterDao.add(DateTime(2026, 9, 7, 22, 40), 1, target: 8);
      expect((await db.waterDao.forDate(DateTime(2026, 9, 7)))!.glasses, 1);
    });

    test('settings carry a default target and the reminder on', () async {
      final s = await fresh().settingsDao.get();
      expect(s.waterTargetGlasses, kDefaultWaterGlasses);
      expect(s.notifyWater, isTrue);
    });
  });
}
