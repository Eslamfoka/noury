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
  ],
)
class NouriDatabase extends _$NouriDatabase {
  NouriDatabase() : super(_open());
  NouriDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

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
        },
      );

  late final settingsDao = SettingsDao(this);
  late final prayerDao = PrayerDao(this);
  late final athkarDao = AthkarDao(this);
  late final quranDao = QuranDao(this);
  late final financeDao = FinanceDao(this);
  late final bodyDao = BodyDao(this);
  late final reminderDao = ReminderDao(this);
  late final stepsDao = StepsDao(this);
  late final workoutDao = WorkoutDao(this);
  late final challengeDao = ChallengeDao(this);

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

  /// Everything not yet marked done — the set the scheduler re-arms from.
  Future<List<Reminder>> allActive() => (_db.select(_db.reminders)
        ..where((t) => t.done.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.onDate)]))
      .get();

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
