import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

export 'tables.dart';

part 'nouri_database.g.dart';

/// Every date column stores midnight local time, so "the same day" is one row
/// whether it was written at 06:40 or 21:15.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

Map<String, int> decodeIqamaOffsets(String json) =>
    (jsonDecode(json) as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, (v as num).toInt()));

String encodeIqamaOffsets(Map<String, int> offsets) => jsonEncode(offsets);

@DriftDatabase(tables: [SettingsRows, PrayerLogs, AthkarLogs, QuranLogs])
class NouriDatabase extends _$NouriDatabase {
  NouriDatabase() : super(_open());
  NouriDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  late final settingsDao = SettingsDao(this);
  late final prayerDao = PrayerDao(this);
  late final athkarDao = AthkarDao(this);
  late final quranDao = QuranDao(this);

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
