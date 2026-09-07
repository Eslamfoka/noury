import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/challenges/challenges_panel.dart';

import '../../support/harness.dart';

void main() {
  late NouriDatabase db;

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(
      testApp(
        db: db,
        child: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: ChallengesPanel(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> logDay(DateTime day, PrayerState state) async {
    for (final name in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      await db.prayerDao.upsertLog(
        date: day,
        prayer: name,
        scheduledTime: DateTime(day.year, day.month, day.day, 12),
        state: state,
      );
    }
  }

  testWidgets('offers the catalogue when nothing is joined', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      expect(find.byKey(const ValueKey('no-active-challenges')), findsOneWidget);
      expect(find.byKey(const ValueKey('challenge-available-forty-mosque')),
          findsOneWidget);
      expect(find.text('أربعين يوم في المسجد'), findsOneWidget);
    });
  });

  testWidgets('joining moves it out of the available list', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('challenge-join-forty-mosque')));
      await t.pumpAndSettle();

      expect(await db.challengeDao.active(), hasLength(1));
      expect(find.byKey(const ValueKey('challenge-active-forty-mosque')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('challenge-available-forty-mosque')),
          findsNothing);
    });
  });

  testWidgets('progress counts today when today qualifies', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.challengeDao
          .enroll(challengeId: 'forty-mosque', startedOn: DateTime.now());
      await logDay(DateTime.now(), PrayerState.mosque);
      await pump(t);

      expect(find.byKey(const ValueKey('challenge-progress-forty-mosque')),
          findsOneWidget);
      expect(find.text('١ من ٤٠ يوم'), findsOneWidget);
      expect(find.textContaining('النهاردة تمام'), findsOneWidget);
    });
  });

  testWidgets('a day short of the bar does not count', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.challengeDao
          .enroll(challengeId: 'forty-mosque', startedOn: DateTime.now());
      await logDay(DateTime.now(), PrayerState.congregation);
      await pump(t);

      expect(find.text('٠ من ٤٠ يوم'), findsOneWidget);
    });
  });

  testWidgets('a broken streak reads as an invitation, never a failure',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      final now = DateTime.now();

      // Joined four days ago, kept two, missed the third, nothing today.
      await db.challengeDao.enroll(
        challengeId: 'forty-mosque',
        startedOn: DateTime(now.year, now.month, now.day - 4),
      );
      await logDay(DateTime(now.year, now.month, now.day - 4),
          PrayerState.mosque);
      await logDay(DateTime(now.year, now.month, now.day - 3),
          PrayerState.mosque);

      await pump(t);

      expect(find.textContaining('ابدأ من تاني'), findsOneWidget);
      expect(find.textContaining('اللي فات مش ضايع'), findsOneWidget);
    });
  });

  testWidgets('nothing in the panel is red', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      final now = DateTime.now();
      await db.challengeDao.enroll(
        challengeId: 'forty-mosque',
        startedOn: DateTime(now.year, now.month, now.day - 4),
      );
      await pump(t);

      // There is no failure colour in NouriColors to reach for, and this is
      // the test that keeps it that way.
      for (final text in t.widgetList<Text>(find.byType(Text))) {
        final c = text.style?.color;
        if (c == null) continue;
        expect(c.r > 0.75 && c.g < 0.55 && c.b < 0.55, isFalse,
            reason: 'found a red-ish colour on "${text.data}"');
      }
    });
  });

  testWidgets('leaving a challenge returns it to the available list',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      final id = await db.challengeDao
          .enroll(challengeId: 'forty-mosque', startedOn: DateTime.now());
      await pump(t);

      await t.tap(find.byKey(ValueKey('challenge-leave-$id')));
      await t.pumpAndSettle();

      expect(await db.challengeDao.active(), isEmpty);
      expect(find.byKey(const ValueKey('challenge-available-forty-mosque')),
          findsOneWidget);
      // Kept, not deleted — an abandoned forty days is still something done.
      expect(await db.challengeDao.history(), hasLength(1));
    });
  });

  testWidgets('a cumulative challenge says the days need not be consecutive',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.challengeDao
          .enroll(challengeId: 'morning-athkar-40', startedOn: DateTime.now());
      await pump(t);

      expect(find.textContaining('مش لازم ورا بعض'), findsWidgets);
    });
  });
}
