import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/completed_tasks.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/data/db/nouri_database.dart';

import '../../support/fake_notification_gateway.dart';

/// Nouri does not ask about something it can already see happened.
///
/// The «عملتها؟» half an hour after a task is useful when the answer is
/// unknown and is nagging when it is not. Everything here is **derived** from
/// logs the user was already keeping — there is no `task_completions` table,
/// for the same reason challenge progress has none: two records of one fact
/// drift apart.
void main() {
  late NouriDatabase db;
  final day = DateTime(2026, 9, 8);

  setUp(() => db = NouriDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  group('what the logs already say', () {
    test('an untouched day has nothing done', () async {
      expect(await completedTaskIdsFor(db, day), isEmpty);
    });

    test('completed morning athkar count as done', () async {
      await db.athkarDao.upsert(
        date: day,
        type: 'morning',
        progress: 17,
        target: 17,
      );
      expect(await completedTaskIdsFor(db, day), contains('morning-athkar'));
    });

    test('athkar started but not finished do not', () async {
      // completedAt is the record, not progress. Half the morning athkar is
      // not the morning athkar.
      await db.athkarDao.upsert(
        date: day,
        type: 'morning',
        progress: 4,
        target: 17,
      );
      expect(
        await completedTaskIdsFor(db, day),
        isNot(contains('morning-athkar')),
      );
    });

    test('a logged walk counts', () async {
      await db.stepsDao.addSession(
        startedAt: DateTime(2026, 9, 8, 16, 0),
        seconds: 1800,
        steps: 3000,
        metres: 2200,
        kcal: 90,
        targetMinutes: 30,
      );
      expect(await completedTaskIdsFor(db, day), contains('walk'));
    });

    test("yesterday's walk does not count for today", () async {
      await db.stepsDao.addSession(
        startedAt: DateTime(2026, 9, 7, 16, 0),
        seconds: 1800,
        steps: 3000,
        metres: 2200,
        kcal: 90,
        targetMinutes: 30,
      );
      expect(await completedTaskIdsFor(db, day), isNot(contains('walk')));
    });

    test('one meal answers the first meal, not the last', () async {
      await db.bodyDao.addMeal(at: DateTime(2026, 9, 8, 13, 0), feeling: MealFeeling.good);
      final done = await completedTaskIdsFor(db, day);
      expect(done, contains('first-meal'));
      expect(done, isNot(contains('last-meal')),
          reason: 'one meal is one meal');
    });

    test('two meals answer both', () async {
      await db.bodyDao.addMeal(at: DateTime(2026, 9, 8, 13, 0), feeling: MealFeeling.good);
      await db.bodyDao.addMeal(at: DateTime(2026, 9, 8, 19, 0), feeling: MealFeeling.good);
      final done = await completedTaskIdsFor(db, day);
      expect(done, contains('first-meal'));
      expect(done, contains('last-meal'));
    });

    test('any knowledge session answers the whole block', () async {
      // The planner rotates the three faces and treats them as one thing, so
      // a reading session answers what a "learn a skill" reminder would ask.
      await db.knowledgeDao.add(
        date: day,
        kind: KnowledgeKind.reading,
        minutes: 30,
      );
      final done = await completedTaskIdsFor(db, day);
      expect(done, contains('knowledge-read'));
      expect(done, contains('knowledge-skill'));
      expect(done, contains('knowledge-listen'));
    });

    test('the wird counts once a page is read', () async {
      await db.quranDao.upsert(date: day, pages: 3);
      expect(await completedTaskIdsFor(db, day), contains('quran-wird'));
    });

    test('مكالمات is never claimed as done', () async {
      // Nouri does not read the call log, so it cannot know. It has no
      // follow-up at all rather than guessing.
      expect(await completedTaskIdsFor(db, day), isNot(contains('calls')));
    });
  });

  group('in the window', () {
    late FakeNotificationGateway gateway;
    late RollingWindowScheduler scheduler;
    final now = DateTime(2026, 9, 8, 6, 0);

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

    test('a task already done is not rung about today', () async {
      await scheduler.rearm(config.copyWith(completedTaskIds: {'walk'}));

      final today = gateway.scheduled.where((n) =>
          n.payload == 'task:walk' &&
          n.when.day == 8 &&
          n.when.month == 9);
      expect(today, isEmpty);
    });

    test('and is not asked about either', () async {
      await scheduler.rearm(config.copyWith(completedTaskIds: {'first-meal'}));

      final asks = gateway.scheduled.where((n) =>
          n.payload == 'taskask:first-meal' && n.when.day == 8);
      expect(asks, isEmpty, reason: 'the log already answered the question');
    });

    test('but tomorrow is still armed — nothing is done yet on a day that '
        'has not happened', () async {
      await scheduler.rearm(config.copyWith(completedTaskIds: {'walk'}));

      final tomorrow = gateway.scheduled
          .where((n) => n.payload == 'task:walk' && n.when.day == 9);
      expect(tomorrow, isNotEmpty);
    });

    test('an empty completed set changes nothing', () async {
      await scheduler.rearm(config);
      final all = gateway.scheduled.length;

      gateway.scheduled.clear();
      await scheduler.rearm(config.copyWith(completedTaskIds: const {}));
      expect(gateway.scheduled.length, all);
    });

    test('finishing everything silences today but not the fortnight',
        () async {
      // The adhan is untouched by any of this: it is not a task and is never
      // in the completed set.
      await scheduler.rearm(config.copyWith(completedTaskIds: {
        'morning-athkar',
        'evening-athkar',
        'sleep-athkar',
        'tasbeeh',
        'quran-wird',
        'first-meal',
        'last-meal',
        'walk',
        'knowledge-read',
        'knowledge-listen',
        'knowledge-skill',
        'phone-time',
        'calls',
      }));

      final adhan = gateway.scheduled
          .where((n) => n.payload?.startsWith('prayer:') ?? false);
      expect(adhan, isNotEmpty, reason: 'the adhan is not a task');
    });
  });
}
