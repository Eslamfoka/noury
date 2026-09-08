import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
import 'tables_v4.dart';

export 'tables.dart';
export 'tables_v4.dart';

part 'nouri_database.g.dart';

/// Every date column stores midnight local time, so "the same day" is one row
/// whether it was written at 06:40 or 21:15.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

Map<String, int> decodeIqamaOffsets(String json) =>
    (jsonDecode(json) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));

String encodeIqamaOffsets(Map<String, int> offsets) => jsonEncode(offsets);

@DriftDatabase(
  tables: [
    SettingsRows,
    PrayerLogs,
    AthkarLogs,
    QuranLogs,
    Expenses,
    Budgets,
    Meals,
    Weights,
    Reminders,
    WalkSessions,
    WorkoutSessions,
    ChallengeEnrollments,
    WaterLogs,
    FastingDays,
    KnowledgeLogs,
    PhoneSessions,
  ],
)
class NouriDatabase extends _$NouriDatabase {
  NouriDatabase() : super(_open());
  NouriDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v2 adds the financial pillar. Existing prayer, athkar and wird
          // rows are untouched -- an upgrade must never cost the user data.
          if (from < 2) {
            await m.createTable(expenses);
            await m.createTable(budgets);
            await m.addColumn(
                settingsRows, settingsRows.financialMonthStartDay);
            await m.addColumn(settingsRows, settingsRows.monthlyIncomeFils);
          }

          // v3 adds the physical pillar. Same rule: additive only.
          if (from < 3) {
            await m.createTable(meals);
            await m.createTable(weights);
            await m.addColumn(
                settingsRows, settingsRows.eatingWindowStartHour);
            await m.addColumn(settingsRows, settingsRows.targetWeightGrams);
          }

          // v4 adds reminders, walking, workouts and challenges. Additive
          // only, like every migration before it -- an upgrade must never
          // cost the user a row.
          if (from < 4) {
            await m.createTable(reminders);
            await m.createTable(walkSessions);
            await m.createTable(workoutSessions);
            await m.createTable(challengeEnrollments);
            await m.addColumn(settingsRows, settingsRows.strideCm);
            await m.addColumn(settingsRows, settingsRows.allowSimulatedSteps);
          }

          // v5 adds the sunnah fasting reminder toggle. Additive only.
          if (from < 5) {
            await m.addColumn(settingsRows, settingsRows.notifyFasting);
          }

          // v6 adds the duty pattern the planner needs. Additive only.
          if (from < 6) {
            await m.addColumn(settingsRows, settingsRows.shiftType);
          }

          // v7 adds water and the fasting-day marker. Additive only.
          if (from < 7) {
            await m.createTable(waterLogs);
            await m.createTable(fastingDays);
            await m.addColumn(settingsRows, settingsRows.waterTargetGlasses);
            await m.addColumn(settingsRows, settingsRows.notifyWater);
          }

          // v8 adds knowledge time — the self-development pillar. Additive.
          if (from < 8) {
            await m.createTable(knowledgeLogs);
          }

          // v9 adds the قيام الليل toggle. Additive only, and it arrives off,
          // which is also what an existing install gets.
          if (from < 9) {
            await m.addColumn(settingsRows, settingsRows.notifyQiyam);
          }

          // v10 adds phone/social time and its cap. Additive only.
          if (from < 10) {
            await m.createTable(phoneSessions);
            await m.addColumn(settingsRows, settingsRows.phoneCapMinutes);
          }

          // v11 adds the task-alarm switch. Additive, and it arrives on —
          // an upgrade gets the feature rather than having to find it.
          if (from < 11) {
            await m.addColumn(settingsRows, settingsRows.notifyTasks);
          }
        },
      );

  late final settingsDao = SettingsDao(this);
  late final prayerDao = PrayerDao(this);
  late final athkarDao = AthkarDao(this);
  late final quranDao = QuranDao(this);
  late final financeDao = FinanceDao(this);
  late final phoneDao = PhoneDao(this);
  late final bodyDao = BodyDao(this);
  late final reminderDao = ReminderDao(this);
  late final stepsDao = StepsDao(this);
  late final workoutDao = WorkoutDao(this);
  late final challengeDao = ChallengeDao(this);
  late final waterDao = WaterDao(this);
  late final knowledgeDao = KnowledgeDao(this);

  static QueryExecutor _open() => LazyDatabase(() async {
        final dir = await getApplicationDocumentsDirectory();
        return NativeDatabase.createInBackground(
          File(p.join(dir.path, 'nouri.sqlite')),
        );
      });
}

class SettingsDao {
  SettingsDao(this._db);
  final NouriDatabase _db;

  /// Returns the single settings row, creating it with defaults on first call.
  Future<SettingsRow> get() async {
    final existing = await (_db.select(_db.settingsRows)
          ..where((t) => t.id.equals(1)))
        .getSingleOrNull();
    if (existing != null) return existing;

    await _db
        .into(_db.settingsRows)
        .insert(const SettingsRowsCompanion(id: Value(1)));
    return (_db.select(_db.settingsRows)..where((t) => t.id.equals(1)))
        .getSingle();
  }

  Future<void> update(SettingsRowsCompanion changes) async {
    await get(); // guarantee the row exists
    await (_db.update(_db.settingsRows)..where((t) => t.id.equals(1)))
        .write(changes);
  }
}

class PrayerDao {
  PrayerDao(this._db);
  final NouriDatabase _db;

  Future<void> upsertLog({
    required DateTime date,
    required String prayer,
    required DateTime scheduledTime,
    required PrayerState state,
  }) async {
    final row = PrayerLogsCompanion.insert(
      date: dayOf(date),
      prayer: prayer,
      scheduledTime: scheduledTime,
      state: state,
      score: state.score,
      // Nothing was logged, so there is no log time.
      loggedAt: Value(state == PrayerState.none ? null : DateTime.now()),
    );

    // The conflict target must be named explicitly. insertOnConflictUpdate
    // targets the primary key, and `id` is auto-increment — so it would never
    // see the (date, prayer) collision and SQLite would raise 2067 instead of
    // updating.
    await _db.into(_db.prayerLogs).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: [_db.prayerLogs.date, _db.prayerLogs.prayer],
          ),
        );
  }

  Future<List<PrayerLog>> logsForDate(DateTime date) =>
      (_db.select(_db.prayerLogs)..where((t) => t.date.equals(dayOf(date))))
          .get();

  Future<List<PrayerLog>> logsBetween(DateTime from, DateTime to) =>
      (_db.select(_db.prayerLogs)
            ..where((t) => t.date.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();
}

class AthkarDao {
  AthkarDao(this._db);
  final NouriDatabase _db;

  Future<void> upsert({
    required DateTime date,
    required String type,
    required int progress,
    required int target,
  }) async {
    final day = dayOf(date);
    final existing = await (_db.select(_db.athkarLogs)
          ..where((t) => t.date.equals(day) & t.type.equals(type)))
        .getSingleOrNull();

    // completedAt is stamped once, on the first crossing of the target, and
    // never moves again — extra taps past the target must not shift it.
    final completedAt =
        existing?.completedAt ?? (progress >= target ? DateTime.now() : null);

    final row = AthkarLogsCompanion.insert(
      date: day,
      type: type,
      targetCount: target,
      progressCount: Value(progress),
      completedAt: Value(completedAt),
    );

    await _db.into(_db.athkarLogs).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: [_db.athkarLogs.date, _db.athkarLogs.type],
          ),
        );
  }

  Future<List<AthkarLog>> forDate(DateTime date) =>
      (_db.select(_db.athkarLogs)..where((t) => t.date.equals(dayOf(date))))
          .get();

  Future<List<AthkarLog>> between(DateTime from, DateTime to) =>
      (_db.select(_db.athkarLogs)
            ..where((t) => t.date.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();
}

class QuranDao {
  QuranDao(this._db);
  final NouriDatabase _db;

  Future<void> upsert({required DateTime date, required int pages}) async {
    final row = QuranLogsCompanion.insert(
      date: dayOf(date),
      pagesRead: pages,
      completedAt: Value(pages > 0 ? DateTime.now() : null),
    );

    await _db.into(_db.quranLogs).insert(
          row,
          onConflict: DoUpdate((_) => row, target: [_db.quranLogs.date]),
        );
  }

  Future<QuranLog?> forDate(DateTime date) =>
      (_db.select(_db.quranLogs)..where((t) => t.date.equals(dayOf(date))))
          .getSingleOrNull();

  Future<List<QuranLog>> between(DateTime from, DateTime to) =>
      (_db.select(_db.quranLogs)
            ..where((t) => t.date.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  Future<int> totalPages() async {
    final rows = await _db.select(_db.quranLogs).get();
    return rows.fold<int>(0, (a, r) => a + r.pagesRead);
  }
}

class FinanceDao {
  FinanceDao(this._db);
  final NouriDatabase _db;

  Future<void> addExpense({
    required DateTime date,
    required String category,
    required int amountFils,
    String? note,
  }) =>
      _db.into(_db.expenses).insert(ExpensesCompanion.insert(
            date: dayOf(date),
            category: category,
            amountFils: amountFils,
            note: Value(note),
          ));

  Future<void> deleteExpense(int id) =>
      (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();

  Future<List<Expense>> expensesBetween(DateTime from, DateTime to) =>
      (_db.select(_db.expenses)
            ..where((t) => t.date.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();

  /// Total spent per category within the range, in fils.
  Future<Map<String, int>> spendByCategory(DateTime from, DateTime to) async {
    final rows = await expensesBetween(from, to);
    final totals = <String, int>{};
    for (final r in rows) {
      totals[r.category] = (totals[r.category] ?? 0) + r.amountFils;
    }
    return totals;
  }

  Future<void> setBudget({
    required DateTime monthStart,
    required String category,
    required int limitFils,
  }) async {
    final row = BudgetsCompanion.insert(
      monthStart: dayOf(monthStart),
      category: category,
      limitFils: limitFils,
    );
    await _db.into(_db.budgets).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: [_db.budgets.monthStart, _db.budgets.category],
          ),
        );
  }

  Future<Map<String, int>> budgetsFor(DateTime monthStart) async {
    final rows = await (_db.select(_db.budgets)
          ..where((t) => t.monthStart.equals(dayOf(monthStart))))
        .get();
    return {for (final r in rows) r.category: r.limitFils};
  }
}

/// Meals and weight readings.
class BodyDao {
  BodyDao(this._db);
  final NouriDatabase _db;

  Future<void> addMeal({
    required DateTime at,
    required MealFeeling feeling,
    String? description,
  }) =>
      _db.into(_db.meals).insert(MealsCompanion.insert(
            at: at,
            feeling: feeling,
            description: Value(description),
          ));

  Future<void> deleteMeal(int id) =>
      (_db.delete(_db.meals)..where((t) => t.id.equals(id))).go();

  /// Meals logged on the calendar day containing [day].
  ///
  /// Stored with the full timestamp, not the date alone: when a meal happened
  /// is the whole point of the log, and rounding it to a day would throw away
  /// the pattern the user wants to show a doctor.
  Future<List<Meal>> mealsOn(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    return (_db.select(_db.meals)
          ..where((t) => t.at.isBiggerOrEqualValue(from))
          ..where((t) => t.at.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.at)]))
        .get();
  }

  /// The most recent meals, newest first — the window the pattern reading uses.
  Future<List<Meal>> recentMeals({int limit = 7}) => (_db.select(_db.meals)
        ..orderBy([(t) => OrderingTerm.desc(t.at)])
        ..limit(limit))
      .get();

  Future<void> addWeight({required DateTime at, required int grams}) =>
      _db.into(_db.weights).insert(WeightsCompanion.insert(at: at, grams: grams));

  Future<Weight?> latestWeight() => (_db.select(_db.weights)
        ..orderBy([(t) => OrderingTerm.desc(t.at)])
        ..limit(1))
      .getSingleOrNull();

  Future<List<Weight>> recentWeights({int limit = 30}) =>
      (_db.select(_db.weights)
            ..orderBy([(t) => OrderingTerm.desc(t.at)])
            ..limit(limit))
          .get();
}

/// Reminders the user wrote against a day on the calendar.
class ReminderDao {
  ReminderDao(this._db);
  final NouriDatabase _db;

  /// Returns the new row's id, which is also what the notification id derives
  /// from — see `lib/features/reminders/reminder_ids.dart`.
  Future<int> add({
    required DateTime onDate,
    required int minutes,
    required String title,
    required ReminderRepeat repeat,
    String? note,
  }) =>
      _db.into(_db.reminders).insert(RemindersCompanion.insert(
            onDate: dayOf(onDate),
            minutes: minutes,
            title: title,
            repeat: repeat,
            note: Value(note),
            createdAt: DateTime.now(),
          ));

  Future<void> edit({
    required int id,
    required DateTime onDate,
    required int minutes,
    required String title,
    required ReminderRepeat repeat,
    String? note,
  }) =>
      (_db.update(_db.reminders)..where((t) => t.id.equals(id))).write(
        RemindersCompanion(
          onDate: Value(dayOf(onDate)),
          minutes: Value(minutes),
          title: Value(title),
          repeat: Value(repeat),
          note: Value(note),
        ),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.reminders)..where((t) => t.id.equals(id))).go();

  Future<void> setDone(int id, bool done) =>
      (_db.update(_db.reminders)..where((t) => t.id.equals(id)))
          .write(RemindersCompanion(done: Value(done)));

  /// Reminders whose own day is [day].
  ///
  /// Deliberately not "reminders that occur on [day]" — a repeat occurring
  /// today is computed by [occurrencesOf], not by the database, because the
  /// repeat rules are domain logic and belong where they can be tested
  /// without SQLite.
  Future<List<Reminder>> forDay(DateTime day) => (_db.select(_db.reminders)
        ..where((t) => t.onDate.equals(dayOf(day)))
        ..orderBy([(t) => OrderingTerm.asc(t.minutes)]))
      .get();

  Future<List<Reminder>> between(DateTime from, DateTime to) =>
      (_db.select(_db.reminders)
            ..where((t) => t.onDate.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([
              (t) => OrderingTerm.asc(t.onDate),
              (t) => OrderingTerm.asc(t.minutes),
            ]))
          .get();

  /// The set the scheduler re-arms from: everything not done, minus the
  /// one-offs whose day is long gone.
  ///
  /// Bounded on purpose. A one-off from last March will never fire again, and
  /// arming now *cancels* anything with no next occurrence — so an unbounded
  /// query would issue one pointless platform call per stale reminder on every
  /// re-arm, growing for as long as the app is used. Repeats are always
  /// included, however old, because they still come round.
  ///
  /// The grace window is a few days rather than zero so that a one-off which
  /// has only just passed is still explicitly cleared rather than left to a
  /// stale alarm.
  Future<List<Reminder>> allActive({DateTime? now}) {
    final today = now ?? DateTime.now();
    final cutoff = DateTime(today.year, today.month, today.day - 7);

    return (_db.select(_db.reminders)
          ..where((t) =>
              t.done.equals(false) &
              (t.onDate.isBiggerOrEqualValue(cutoff) |
                  t.repeat.equals(ReminderRepeat.daily.index) |
                  t.repeat.equals(ReminderRepeat.weekly.index) |
                  t.repeat.equals(ReminderRepeat.monthly.index)))
          ..orderBy([(t) => OrderingTerm.asc(t.onDate)]))
        .get();
  }

  Future<List<Reminder>> all() => _db.select(_db.reminders).get();
}

/// Walking sessions.
class StepsDao {
  StepsDao(this._db);
  final NouriDatabase _db;

  Future<int> addSession({
    required DateTime startedAt,
    required int seconds,
    required int steps,
    required int metres,
    required int kcal,
    required int targetMinutes,
  }) =>
      _db.into(_db.walkSessions).insert(WalkSessionsCompanion.insert(
            startedAt: startedAt,
            seconds: seconds,
            steps: steps,
            metres: metres,
            kcal: kcal,
            targetMinutes: targetMinutes,
          ));

  /// Sessions that *started* on [day]. A walk begun at 23:50 counts as that
  /// day's walk even if it ends after midnight — it is the day the user set
  /// out, which is how they will remember it.
  Future<List<WalkSession>> sessionsOn(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    return (_db.select(_db.walkSessions)
          ..where((t) => t.startedAt.isBiggerOrEqualValue(from))
          ..where((t) => t.startedAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<int> stepsOn(DateTime day) async {
    final rows = await sessionsOn(day);
    return rows.fold<int>(0, (a, r) => a + r.steps);
  }

  Future<List<WalkSession>> between(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day + 1);
    return (_db.select(_db.walkSessions)
          ..where((t) => t.startedAt.isBiggerOrEqualValue(start))
          ..where((t) => t.startedAt.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
        .get();
  }

  Future<List<WalkSession>> recentSessions({int limit = 10}) =>
      (_db.select(_db.walkSessions)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(limit))
          .get();
}

/// Workout sessions, complete and partial alike.
class WorkoutDao {
  WorkoutDao(this._db);
  final NouriDatabase _db;

  Future<int> addSession({
    required DateTime startedAt,
    required String routineId,
    required int doneCount,
    required int totalCount,
    required int seconds,
  }) =>
      _db.into(_db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
            startedAt: startedAt,
            routineId: routineId,
            doneCount: doneCount,
            totalCount: totalCount,
            seconds: seconds,
          ));

  Future<List<WorkoutSession>> sessionsOn(DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final to = DateTime(day.year, day.month, day.day + 1);
    return (_db.select(_db.workoutSessions)
          ..where((t) => t.startedAt.isBiggerOrEqualValue(from))
          ..where((t) => t.startedAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
        .get();
  }

  Future<List<WorkoutSession>> recentSessions({int limit = 10}) =>
      (_db.select(_db.workoutSessions)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(limit))
          .get();
}

/// Challenge enrolments. Progress itself is never stored — it is derived from
/// the prayer, athkar and walk logs on every read.
class ChallengeDao {
  ChallengeDao(this._db);
  final NouriDatabase _db;

  Future<int> enroll({
    required String challengeId,
    required DateTime startedOn,
  }) {
    final row = ChallengeEnrollmentsCompanion.insert(
      challengeId: challengeId,
      startedOn: dayOf(startedOn),
    );
    return _db.into(_db.challengeEnrollments).insert(
          row,
          onConflict: DoUpdate(
            (_) => row,
            target: [
              _db.challengeEnrollments.challengeId,
              _db.challengeEnrollments.startedOn,
            ],
          ),
        );
  }

  /// Steps away from a challenge without deleting it — an abandoned forty days
  /// is still something the user did.
  Future<void> abandon(int id, {DateTime? on}) =>
      (_db.update(_db.challengeEnrollments)..where((t) => t.id.equals(id)))
          .write(ChallengeEnrollmentsCompanion(
        abandonedOn: Value(dayOf(on ?? DateTime.now())),
      ));

  Future<List<ChallengeEnrollment>> active() =>
      (_db.select(_db.challengeEnrollments)
            ..where((t) => t.abandonedOn.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedOn)]))
          .get();

  Future<List<ChallengeEnrollment>> history() =>
      (_db.select(_db.challengeEnrollments)
            ..orderBy([(t) => OrderingTerm.desc(t.startedOn)]))
          .get();
}

/// Water, and the days the user says they are fasting.
class WaterDao {
  WaterDao(this._db);
  final NouriDatabase _db;

  Future<WaterLog?> forDate(DateTime date) =>
      (_db.select(_db.waterLogs)..where((t) => t.date.equals(dayOf(date))))
          .getSingleOrNull();

  /// Adds [glasses] to the day, never below zero.
  ///
  /// Clamped rather than guarded at the call site: the minus button is there
  /// for a mistap, and a negative count of glasses is not a thing.
  Future<void> add(DateTime date, int glasses, {required int target}) async {
    final day = dayOf(date);
    final existing = await forDate(day);
    final next = ((existing?.glasses ?? 0) + glasses).clamp(0, 100);

    final row = WaterLogsCompanion.insert(
      date: day,
      targetGlasses: target,
      glasses: Value(next),
    );
    await _db.into(_db.waterLogs).insert(
          row,
          onConflict: DoUpdate((_) => row, target: [_db.waterLogs.date]),
        );
  }

  Future<List<WaterLog>> between(DateTime from, DateTime to) =>
      (_db.select(_db.waterLogs)
            ..where((t) => t.date.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  Future<bool> isFasting(DateTime date) async {
    final row = await (_db.select(_db.fastingDays)
          ..where((t) => t.date.equals(dayOf(date))))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> setFasting(DateTime date, bool fasting) async {
    final day = dayOf(date);
    if (!fasting) {
      await (_db.delete(_db.fastingDays)..where((t) => t.date.equals(day)))
          .go();
      return;
    }
    // The conflict target must be named. DoNothing() targets the primary key,
    // and `id` is auto-increment — so it would never see the `date` collision
    // and SQLite would raise 2067 instead of doing nothing. The same trap
    // PrayerDao documents.
    await _db.into(_db.fastingDays).insert(
          FastingDaysCompanion.insert(date: day),
          onConflict: DoNothing(target: [_db.fastingDays.date]),
        );
  }

  Future<List<FastingDay>> fastingBetween(DateTime from, DateTime to) =>
      (_db.select(_db.fastingDays)
            ..where((t) => t.date.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();
}

/// Knowledge time — the self-development pillar.
class KnowledgeDao {
  KnowledgeDao(this._db);
  final NouriDatabase _db;

  Future<int> add({
    required DateTime date,
    required KnowledgeKind kind,
    required int minutes,
    String? note,
  }) =>
      _db.into(_db.knowledgeLogs).insert(KnowledgeLogsCompanion.insert(
            date: dayOf(date),
            kind: kind,
            minutes: minutes,
            note: Value(note),
            loggedAt: DateTime.now(),
          ));

  Future<void> delete(int id) =>
      (_db.delete(_db.knowledgeLogs)..where((t) => t.id.equals(id))).go();

  Future<List<KnowledgeLog>> forDate(DateTime date) =>
      (_db.select(_db.knowledgeLogs)
            ..where((t) => t.date.equals(dayOf(date)))
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .get();

  Future<List<KnowledgeLog>> between(DateTime from, DateTime to) =>
      (_db.select(_db.knowledgeLogs)
            ..where((t) => t.date.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  /// Minutes on [date], across all three kinds — the brief treats them as one
  /// block, so the useful number is the total.
  Future<int> minutesOn(DateTime date) async {
    final rows = await forDate(date);
    return rows.fold<int>(0, (a, r) => a + r.minutes);
  }
}

class PhoneDao {
  PhoneDao(this._db);
  final NouriDatabase _db;

  Future<int> log({required DateTime date, required int minutes}) =>
      _db.into(_db.phoneSessions).insert(PhoneSessionsCompanion.insert(
            date: dayOf(date),
            minutes: minutes,
            loggedAt: DateTime.now(),
          ));

  Future<void> delete(int id) =>
      (_db.delete(_db.phoneSessions)..where((t) => t.id.equals(id))).go();

  Future<List<PhoneSession>> forDate(DateTime date) =>
      (_db.select(_db.phoneSessions)
            ..where((t) => t.date.equals(dayOf(date)))
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .get();

  Future<List<PhoneSession>> between(DateTime from, DateTime to) =>
      (_db.select(_db.phoneSessions)
            ..where((t) => t.date.isBetweenValues(dayOf(from), dayOf(to)))
            ..orderBy([(t) => OrderingTerm.asc(t.date)]))
          .get();

  /// Minutes on [date]. Several sittings in a day add up — the cap is on the
  /// day, not on one sitting.
  Future<int> minutesOn(DateTime date) async {
    final rows = await forDate(date);
    return rows.fold<int>(0, (a, r) => a + r.minutes);
  }
}
