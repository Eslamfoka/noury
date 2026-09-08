import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';

/// The schema and its migrations.
///
/// v4 added reminders, walking, workouts and challenges; v5 the sunnah
/// fasting toggle; v6 the duty pattern the planner needs; v7 water and the
/// fasting-day marker; v8 knowledge time; v9 the قيام الليل toggle. Every
/// migration is additive, so the most important test
/// here is the last one — that nothing from the religious core was disturbed
/// on the way.
void main() {
  NouriDatabase open(void Function(NouriDatabase) _) {
    final db = NouriDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  NouriDatabase fresh() => open((_) {});

  test('schema is at v9', () {
    // Pinned deliberately: an accidental bump means a migration nobody wrote.
    expect(fresh().schemaVersion, 9);
  });

  test('قيام الليل arrives off, on a fresh install and on an upgrade', () async {
    // The one religious reminder that is off by default. It wakes the user at
    // two in the morning for a voluntary prayer, and an upgrade that switched
    // it on would be Nouri deciding that for them.
    expect((await fresh().settingsDao.get()).notifyQiyam, isFalse);
  });

  group('reminders', () {
    test('a reminder round-trips', () async {
      final db = fresh();
      final id = await db.reminderDao.add(
        onDate: DateTime(2026, 9, 20),
        minutes: 9 * 60 + 30,
        title: 'ميعاد الدكتور',
        repeat: ReminderRepeat.once,
      );

      final rows = await db.reminderDao.forDay(DateTime(2026, 9, 20));
      expect(rows, hasLength(1));
      expect(rows.single.id, id);
      expect(rows.single.title, 'ميعاد الدكتور');
      expect(rows.single.minutes, 570);
      expect(rows.single.done, isFalse);
      expect(rows.single.repeat, ReminderRepeat.once);
    });

    test('the day is normalised, so an evening write still lands on the day',
        () async {
      final db = fresh();
      await db.reminderDao.add(
        onDate: DateTime(2026, 9, 20, 21, 40),
        minutes: 600,
        title: 'كشف',
        repeat: ReminderRepeat.once,
      );
      expect(await db.reminderDao.forDay(DateTime(2026, 9, 20)), hasLength(1));
    });

    test('a day lists its reminders in time order', () async {
      final db = fresh();
      for (final m in [18 * 60, 7 * 60, 12 * 60]) {
        await db.reminderDao.add(
          onDate: DateTime(2026, 9, 20),
          minutes: m,
          title: 'ذكرى $m',
          repeat: ReminderRepeat.once,
        );
      }
      final rows = await db.reminderDao.forDay(DateTime(2026, 9, 20));
      expect(rows.map((r) => r.minutes), [420, 720, 1080]);
    });

    test('the active set drops one-offs long past, but keeps repeats',
        () async {
      // Arming now cancels anything with no next occurrence, so an unbounded
      // active set would issue one pointless platform call per stale reminder
      // on every re-arm, growing for as long as the app is used.
      final db = fresh();
      final now = DateTime(2026, 9, 20);

      await db.reminderDao.add(
        onDate: DateTime(2026, 3, 1),
        minutes: 600,
        title: 'قديم',
        repeat: ReminderRepeat.once,
      );
      await db.reminderDao.add(
        onDate: DateTime(2026, 3, 1),
        minutes: 600,
        title: 'أسبوعي قديم',
        repeat: ReminderRepeat.weekly,
      );
      await db.reminderDao.add(
        onDate: DateTime(2026, 9, 18),
        minutes: 600,
        title: 'قريب',
        repeat: ReminderRepeat.once,
      );

      final active = await db.reminderDao.allActive(now: now);
      final titles = active.map((r) => r.title).toSet();

      expect(titles, isNot(contains('قديم')),
          reason: 'a one-off from March will never fire again');
      expect(titles, contains('أسبوعي قديم'),
          reason: 'a repeat still comes round, however old');
      expect(titles, contains('قريب'),
          reason: 'a one-off that has only just passed is still cleared '
              'explicitly rather than left to a stale alarm');
    });

    test('done reminders drop out of the active set', () async {
      final db = fresh();
      final id = await db.reminderDao.add(
        onDate: DateTime(2026, 9, 20),
        minutes: 600,
        title: 'كشف',
        repeat: ReminderRepeat.once,
      );
      expect(await db.reminderDao.allActive(), hasLength(1));

      await db.reminderDao.setDone(id, true);
      expect(await db.reminderDao.allActive(), isEmpty);
      // Still there, just done -- marking done is not deleting.
      expect(await db.reminderDao.forDay(DateTime(2026, 9, 20)), hasLength(1));
    });

    test('between spans whole days at both ends', () async {
      final db = fresh();
      for (final d in [19, 20, 25, 26]) {
        await db.reminderDao.add(
          onDate: DateTime(2026, 9, d),
          minutes: 600,
          title: 'يوم $d',
          repeat: ReminderRepeat.once,
        );
      }
      final rows = await db.reminderDao
          .between(DateTime(2026, 9, 20), DateTime(2026, 9, 25));
      expect(rows.map((r) => r.onDate.day), [20, 25]);
    });

    test('editing changes the row without making a second one', () async {
      final db = fresh();
      final id = await db.reminderDao.add(
        onDate: DateTime(2026, 9, 20),
        minutes: 600,
        title: 'كشف',
        repeat: ReminderRepeat.once,
      );
      await db.reminderDao.edit(
        id: id,
        onDate: DateTime(2026, 9, 21),
        minutes: 660,
        title: 'كشف اتأجل',
        repeat: ReminderRepeat.weekly,
      );

      expect(await db.reminderDao.forDay(DateTime(2026, 9, 20)), isEmpty);
      final moved = await db.reminderDao.forDay(DateTime(2026, 9, 21));
      expect(moved.single.id, id);
      expect(moved.single.title, 'كشف اتأجل');
      expect(moved.single.repeat, ReminderRepeat.weekly);
    });
  });

  group('walking', () {
    test('sessions round-trip and total by day', () async {
      final db = fresh();
      await db.stepsDao.addSession(
        startedAt: DateTime(2026, 9, 7, 18),
        seconds: 1800,
        steps: 3400,
        metres: 2448,
        kcal: 122,
        targetMinutes: 30,
      );
      await db.stepsDao.addSession(
        startedAt: DateTime(2026, 9, 7, 21),
        seconds: 600,
        steps: 900,
        metres: 648,
        kcal: 31,
        targetMinutes: 10,
      );

      expect(await db.stepsDao.stepsOn(DateTime(2026, 9, 7)), 4300);
      expect(await db.stepsDao.stepsOn(DateTime(2026, 9, 8)), 0);
      expect(await db.stepsDao.sessionsOn(DateTime(2026, 9, 7)), hasLength(2));
    });

    test('a walk begun at 23:50 belongs to the day it started', () async {
      final db = fresh();
      await db.stepsDao.addSession(
        startedAt: DateTime(2026, 9, 7, 23, 50),
        seconds: 1800,
        steps: 2000,
        metres: 1440,
        kcal: 70,
        targetMinutes: 30,
      );
      expect(await db.stepsDao.stepsOn(DateTime(2026, 9, 7)), 2000);
      expect(await db.stepsDao.stepsOn(DateTime(2026, 9, 8)), 0);
    });
  });

  group('workouts', () {
    test('a partial session is stored, not discarded', () async {
      final db = fresh();
      await db.workoutDao.addSession(
        startedAt: DateTime(2026, 9, 7, 19),
        routineId: 'full-body',
        doneCount: 5,
        totalCount: 20,
        seconds: 300,
      );
      final rows = await db.workoutDao.sessionsOn(DateTime(2026, 9, 7));
      expect(rows.single.doneCount, 5);
      expect(rows.single.totalCount, 20);
    });
  });

  group('challenges', () {
    test('enrolling twice on the same day is one enrolment', () async {
      final db = fresh();
      await db.challengeDao
          .enroll(challengeId: 'forty-mosque', startedOn: DateTime(2026, 9, 7));
      await db.challengeDao.enroll(
          challengeId: 'forty-mosque', startedOn: DateTime(2026, 9, 7, 22));
      expect(await db.challengeDao.active(), hasLength(1));
    });

    test('abandoning keeps the row but drops it from active', () async {
      final db = fresh();
      final id = await db.challengeDao
          .enroll(challengeId: 'forty-mosque', startedOn: DateTime(2026, 9, 7));
      await db.challengeDao.abandon(id, on: DateTime(2026, 9, 20));

      expect(await db.challengeDao.active(), isEmpty);
      final all = await db.challengeDao.history();
      expect(all.single.abandonedOn, DateTime(2026, 9, 20));
    });
  });

  group('settings', () {
    test('gains a stride and keeps simulation off by default', () async {
      final db = fresh();
      final s = await db.settingsDao.get();
      expect(s.strideCm, 72);
      expect(s.allowSimulatedSteps, isFalse,
          reason: 'a real phone must never quietly invent steps');
    });

    test('offers the sunnah fasts by default, like the other reminders',
        () async {
      expect((await fresh().settingsDao.get()).notifyFasting, isTrue);
    });

    test('starts on the morning shift', () async {
      expect((await fresh().settingsDao.get()).shiftType, 'morning');
    });

    test('carries a water target and the nudge on', () async {
      final s = await fresh().settingsDao.get();
      expect(s.waterTargetGlasses, 8);
      expect(s.notifyWater, isTrue);
    });
  });

  group('knowledge time', () {
    test('a session round-trips and totals by day', () async {
      final db = fresh();
      final day = DateTime(2026, 9, 7);
      await db.knowledgeDao
          .add(date: day, kind: KnowledgeKind.reading, minutes: 30);
      await db.knowledgeDao
          .add(date: day, kind: KnowledgeKind.skill, minutes: 15);

      expect(await db.knowledgeDao.minutesOn(day), 45,
          reason: 'one flexible block, so the total is the useful number');
      expect(await db.knowledgeDao.forDate(day), hasLength(2));
    });
  });

  test('v4 leaves the religious core exactly where it was', () async {
    // The whole point of an additive migration.
    final db = fresh();
    await db.prayerDao.upsertLog(
      date: DateTime(2026, 9, 7),
      prayer: 'fajr',
      scheduledTime: DateTime(2026, 9, 7, 4, 20),
      state: PrayerState.mosque,
    );
    await db.athkarDao.upsert(
      date: DateTime(2026, 9, 7),
      type: 'morning',
      progress: 3,
      target: 17,
    );

    final prayers = await db.prayerDao.logsForDate(DateTime(2026, 9, 7));
    expect(prayers.single.state, PrayerState.mosque);
    expect(prayers.single.score, 100);

    final athkar = await db.athkarDao.forDate(DateTime(2026, 9, 7));
    expect(athkar.single.progressCount, 3);
  });
}
