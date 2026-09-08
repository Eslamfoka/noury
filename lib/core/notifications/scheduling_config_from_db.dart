import '../../data/db/nouri_database.dart';
import '../../features/finance/budget_categories.dart';
import '../../features/finance/budget_nudge.dart';
import '../../features/finance/financial_month.dart';
import '../../features/planner/shift.dart';
import '../time/geo_config.dart';
import 'completed_tasks.dart';
import 'rolling_window_scheduler.dart';

/// The single place a [SchedulingConfig] is built from stored settings.
///
/// **There used to be two**, and they drifted. `main.dart` armed the window on
/// every launch and `SettingsController` armed it on every settings change,
/// each assembling its own config from the same rows. قيام الليل and the
/// budget note were added to the settings one and not the other — so the
/// launch re-arm quietly rebuilt the window *without* them, overwriting what
/// the settings path had just armed. Turning قيام on and reopening the app
/// left no قيام alarm at all.
///
/// That was not caught by any unit test, because both call sites were
/// individually correct about the fields they knew about. It was caught by
/// counting alarms on the emulator. `scheduling_config_source_test` now fails
/// the build if a second call site appears.
///
/// Pure apart from the reads: give it [now] to make it deterministic.
Future<SchedulingConfig> schedulingConfigFromDb(
  NouriDatabase db, {
  DateTime? now,
}) async {
  final s = await db.settingsDao.get();
  final today = now ?? DateTime.now();

  // The days the user has said they are fasting, over the window the water
  // reminders actually cover. Read here rather than in the scheduler so the
  // scheduler stays pure.
  //
  // Constructed, never offset: `add(Duration(days: 14))` is 336 hours, which
  // lands on the wrong date across a DST boundary.
  final fasting = await db.waterDao.fastingBetween(
    today,
    DateTime(today.year, today.month, today.day + 14),
  );

  return SchedulingConfig(
    geo: GeoConfig(
      latitude: s.latitude,
      longitude: s.longitude,
      method: s.calculationMethod,
      madhab: s.madhab,
    ),
    iqamaOffsets: decodeIqamaOffsets(s.iqamaOffsetsJson),
    notifyAdhan: s.notifyAdhan,
    notifyIqama: s.notifyIqama,
    notifyAthkar: s.notifyAthkar,
    notifyWird: s.notifyWird,
    notifyFasting: s.notifyFasting,
    notifyWater: s.notifyWater,
    notifyQiyam: s.notifyQiyam,
    // Only قيام reads this: on a night shift the whole last third is duty
    // time, so there is nothing to offer.
    shift: switch (s.shiftType) {
      'evening' => ShiftType.evening,
      'night' => ShiftType.night,
      'off' => ShiftType.off,
      _ => ShiftType.morning,
    },
    budgetNote: await _budgetNote(db, today, s.financialMonthStartDay),
    // Derived from the logs the user already keeps, so Nouri stops ringing
    // about something it can see happened.
    completedTaskIds: await completedTaskIdsFor(db, today),
    fastingDays: {for (final f in fasting) dayOf(f.date)},
    hijriOffsetDays: s.hijriOffsetDays,
  );
}

/// One quiet line about a budget running ahead of the month, or null.
///
/// Budget state is not knowable ahead the way a prayer time is, so this is the
/// numbers as they stand right now — recomputed every time the window is
/// armed, which is every launch and every settings change.
Future<String?> _budgetNote(
  NouriDatabase db,
  DateTime today,
  int startDay,
) async {
  final month = FinancialMonth.containing(today, startDay: startDay);
  final limits = await db.financeDao.budgetsFor(month.start);
  if (limits.isEmpty) return null;

  final spent = await db.financeDao.spendByCategory(month.start, month.end);

  final statuses = <BudgetCategory, BudgetStatus>{};
  for (final entry in limits.entries) {
    final category = categoryFromName(entry.key);
    if (category == null) continue;
    statuses[category] = BudgetStatus(
      limit: entry.value,
      spent: spent[entry.key] ?? 0,
      month: month,
      now: today,
    );
  }
  return budgetNudgeFor(statuses);
}
