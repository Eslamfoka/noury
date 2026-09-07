import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/geo_config.dart';
import '../../core/time/prayer_times_service.dart';
import '../../data/db/nouri_database.dart';
import '../../data/tips/daily_tip.dart';
import '../planner/daily_tasks.dart';
import '../planner/day_plan.dart';
import '../planner/day_planner.dart';
import '../planner/shift.dart';

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

/// A coarse clock, for anything that only cares about the minute.
///
/// Prayer times have minute resolution, so "has this prayer passed?" gains
/// nothing from a per-second tick and pays for it in rebuilds and allocations.
/// The per-second [clockProvider] stays for the next-prayer countdown, which
/// genuinely displays seconds.
final coarseClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

/// The calendar day, as a value that changes only at midnight.
///
/// Every day-scoped query in the app watches this rather than calling
/// `DateTime.now()` itself. Without it they each read the date once, cached it,
/// and never looked again — so an app left open past midnight went on showing
/// yesterday's prayer times, yesterday's plan and yesterday's logs until
/// something unrelated happened to invalidate them.
///
/// That is not an edge case here. The brief's user works night shifts, so
/// being awake with Nouri open as the date turns is most of his nights.
///
/// A plain [Provider] over the coarse clock: Riverpod only notifies dependents
/// when the value actually changes, and a `DateTime` compares by value — so
/// this fires **once a day**, not once every thirty seconds.
final currentDayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(coarseClockProvider).value ?? DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Today's prayer times.
final todayPrayerTimesProvider = Provider<AsyncValue<DailyPrayerTimes>>((ref) {
  final geo = ref.watch(geoConfigProvider);
  final service = ref.watch(prayerTimesServiceProvider);
  return geo.whenData((g) => service.forDate(ref.watch(currentDayProvider), g));
});

/// Today's prayer logs, keyed by prayer name.
final todayPrayerLogsProvider =
    FutureProvider<Map<String, PrayerState>>((ref) async {
  final db = ref.watch(databaseProvider);
  final logs = await db.prayerDao.logsForDate(ref.watch(currentDayProvider));
  return {for (final l in logs) l.prayer: l.state};
});

/// Today's athkar and wird progress, keyed by type.
final todayAthkarProvider = FutureProvider<Map<String, AthkarLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.athkarDao.forDate(ref.watch(currentDayProvider));
  return {for (final r in rows) r.type: r};
});

final todayQuranProvider = FutureProvider<QuranLog?>(
  (ref) => ref
      .watch(databaseProvider)
      .quranDao
      .forDate(ref.watch(currentDayProvider)),
);

final khatmaTotalPagesProvider = FutureProvider<int>(
  (ref) => ref.watch(databaseProvider).quranDao.totalPages(),
);

final tipRepositoryProvider = Provider<TipRepository>((ref) => TipRepository());

/// Today's rotating deen/body/wealth line.
///
/// Loaded lazily, after the first frame: the Home header and ring render
/// immediately and the line appears when the three small JSON files are read.
/// It can never delay startup.
final dailyTipProvider = FutureProvider<Tip?>((ref) async {
  final sets = await ref.watch(tipRepositoryProvider).loadAll();
  return tipForDay(ref.watch(currentDayProvider), sets);
});

/// Today's plan, built by the real planner.
///
/// Replaces the hand-written preview: the tasks, their times and the blocks
/// they sit in are all decided by `planDay`.
///
/// It does **not** watch the clock. The plan is the day's shape and does not
/// change as the hours pass — the UI decides which block is current. Rebuilding
/// it every thirty seconds also churned the whole Home list for nothing.
final todayPlanProvider = Provider<AsyncValue<DayPlan>>((ref) {
  final settings = ref.watch(settingsProvider);
  final times = ref.watch(todayPrayerTimesProvider);
  final today = ref.watch(currentDayProvider);

  if (!settings.hasValue || !times.hasValue) {
    return const AsyncValue.loading();
  }

  final s = settings.requireValue;
  final shift = ShiftPattern.fromName(s.shiftType);

  return AsyncValue.data(planDay(
    date: today,
    shift: shift,
    prayers: times.requireValue,
    tasks: dailyTasksFor(
      date: today,
      shift: shift,
      eatingWindowStartHour: s.eatingWindowStartHour,
    ),
  ));
});
