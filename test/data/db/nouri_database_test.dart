import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';

void main() {
  late NouriDatabase db;

  setUp(() => db = NouriDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('settings row is created with Kuwait defaults on first read', () async {
    final s = await db.settingsDao.get();
    expect(s.latitude, closeTo(29.3759, 0.0001));
    expect(s.longitude, closeTo(47.9774, 0.0001));
    expect(s.calculationMethod, 'kuwait');
    expect(s.madhab, 'shafi');
    expect(s.tasbeehTarget, 100);
    expect(s.khatmaTotalPages, 604);
    expect(s.locale, 'ar');
  });

  test('reading settings twice does not create a second row', () async {
    await db.settingsDao.get();
    await db.settingsDao.get();
    final rows = await db.select(db.settingsRows).get();
    expect(rows, hasLength(1));
  });

  test('iqama offsets parse into a usable map', () async {
    final s = await db.settingsDao.get();
    final offsets = decodeIqamaOffsets(s.iqamaOffsetsJson);
    expect(offsets['fajr'], 20);
    expect(offsets['dhuhr'], 15);
    expect(offsets['asr'], 15);
    expect(offsets['maghrib'], 10);
    expect(offsets['isha'], 15);
  });

  test('prayer log upsert is idempotent per (date, prayer)', () async {
    final d = DateTime(2026, 9, 5);
    await db.prayerDao.upsertLog(
      date: d,
      prayer: 'asr',
      scheduledTime: DateTime(2026, 9, 5, 15, 15),
      state: PrayerState.onTime,
    );
    await db.prayerDao.upsertLog(
      date: d,
      prayer: 'asr',
      scheduledTime: DateTime(2026, 9, 5, 15, 15),
      state: PrayerState.mosque,
    );

    final logs = await db.prayerDao.logsForDate(d);
    expect(logs, hasLength(1));
    expect(logs.single.state, PrayerState.mosque);
    expect(logs.single.score, 100);
  });

  test('an unlogged prayer scores nothing and is never negative', () async {
    final d = DateTime(2026, 9, 5);
    await db.prayerDao.upsertLog(
      date: d,
      prayer: 'fajr',
      scheduledTime: DateTime(2026, 9, 5, 4, 21),
      state: PrayerState.none,
    );
    final logs = await db.prayerDao.logsForDate(d);
    expect(logs.single.score, 0);
    expect(logs.single.loggedAt, isNull,
        reason: 'nothing was logged, so there is no log time');
  });

  test('logsBetween returns the range inclusive, ordered by date', () async {
    for (final day in [3, 4, 5]) {
      await db.prayerDao.upsertLog(
        date: DateTime(2026, 9, day),
        prayer: 'fajr',
        scheduledTime: DateTime(2026, 9, day, 4, 21),
        state: PrayerState.mosque,
      );
    }
    final logs = await db.prayerDao.logsBetween(
      DateTime(2026, 9, 3),
      DateTime(2026, 9, 5),
    );
    expect(logs, hasLength(3));
    expect(logs.first.date.day, 3);
    expect(logs.last.date.day, 5);
  });

  test('athkar progress is stored per date and type', () async {
    final d = DateTime(2026, 9, 5);
    await db.athkarDao.upsert(date: d, type: 'tasbeeh', progress: 33, target: 100);
    await db.athkarDao.upsert(date: d, type: 'tasbeeh', progress: 47, target: 100);
    final rows = await db.athkarDao.forDate(d);
    expect(rows, hasLength(1));
    expect(rows.single.progressCount, 47);
    expect(rows.single.completedAt, isNull);
  });

  test('reaching the target stamps completedAt exactly once', () async {
    final d = DateTime(2026, 9, 5);
    await db.athkarDao.upsert(date: d, type: 'tasbeeh', progress: 100, target: 100);
    final first = (await db.athkarDao.forDate(d)).single.completedAt;
    expect(first, isNotNull);

    await db.athkarDao.upsert(date: d, type: 'tasbeeh', progress: 120, target: 100);
    final second = (await db.athkarDao.forDate(d)).single.completedAt;
    expect(second, first,
        reason: 'completion time must not drift on extra taps');
  });

  test('a time of day on the date does not split the row', () async {
    // Dates are normalised to midnight, so logging at 06:40 and at 21:15 on
    // the same day must land on one row, not two.
    await db.athkarDao.upsert(
        date: DateTime(2026, 9, 5, 6, 40), type: 'morning', progress: 1, target: 15);
    await db.athkarDao.upsert(
        date: DateTime(2026, 9, 5, 21, 15), type: 'morning', progress: 9, target: 15);
    final rows = await db.athkarDao.forDate(DateTime(2026, 9, 5));
    expect(rows, hasLength(1));
    expect(rows.single.progressCount, 9);
  });

  test('quran pages accumulate into a running khatma total', () async {
    await db.quranDao.upsert(date: DateTime(2026, 9, 4), pages: 3);
    await db.quranDao.upsert(date: DateTime(2026, 9, 5), pages: 3);
    expect(await db.quranDao.totalPages(), 6);
  });

  test('re-logging the same day replaces rather than adds pages', () async {
    await db.quranDao.upsert(date: DateTime(2026, 9, 5), pages: 3);
    await db.quranDao.upsert(date: DateTime(2026, 9, 5), pages: 6);
    expect(await db.quranDao.totalPages(), 6);
  });
}
