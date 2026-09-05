import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/geo_config.dart';
import '../../core/time/prayer_times_service.dart';
import '../../data/db/nouri_database.dart';

/// The app database. Overridden in tests with an in-memory instance.
final databaseProvider = Provider<NouriDatabase>((ref) {
  final db = NouriDatabase();
  ref.onDispose(db.close);
  return db;
});

final prayerTimesServiceProvider =
    Provider<PrayerTimesService>((ref) => const PrayerTimesService());

/// The user's settings row, created with Kuwait defaults on first read.
final settingsProvider = FutureProvider<SettingsRow>(
  (ref) => ref.watch(databaseProvider).settingsDao.get(),
);

/// Where and how to compute prayer times, from settings.
final geoConfigProvider = Provider<AsyncValue<GeoConfig>>((ref) {
  return ref.watch(settingsProvider).whenData(
        (s) => GeoConfig(
          latitude: s.latitude,
          longitude: s.longitude,
          method: s.calculationMethod,
          madhab: s.madhab,
        ),
      );
});

/// Ticks once a second so the next-prayer countdown stays live.
///
/// A stream rather than a timer inside the widget, so it is disposed with the
/// provider and never leaks when the tab is switched away.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

/// Today's prayer times.
final todayPrayerTimesProvider = Provider<AsyncValue<DailyPrayerTimes>>((ref) {
  final geo = ref.watch(geoConfigProvider);
  final service = ref.watch(prayerTimesServiceProvider);
  return geo.whenData((g) => service.forDate(DateTime.now(), g));
});

/// Today's prayer logs, keyed by prayer name.
final todayPrayerLogsProvider =
    FutureProvider<Map<String, PrayerState>>((ref) async {
  final db = ref.watch(databaseProvider);
  final logs = await db.prayerDao.logsForDate(DateTime.now());
  return {for (final l in logs) l.prayer: l.state};
});

/// Today's athkar and wird progress, keyed by type.
final todayAthkarProvider = FutureProvider<Map<String, AthkarLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.athkarDao.forDate(DateTime.now());
  return {for (final r in rows) r.type: r};
});

final todayQuranProvider = FutureProvider<QuranLog?>(
  (ref) => ref.watch(databaseProvider).quranDao.forDate(DateTime.now()),
);

final khatmaTotalPagesProvider = FutureProvider<int>(
  (ref) => ref.watch(databaseProvider).quranDao.totalPages(),
);
