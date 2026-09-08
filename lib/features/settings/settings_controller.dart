import 'package:drift/drift.dart' show Value;

import '../../core/notifications/rolling_window_scheduler.dart';
import '../../core/time/geo_config.dart';
import '../../core/time/location_service.dart';
import '../../data/db/nouri_database.dart';
import '../finance/budget_categories.dart';
import '../finance/budget_nudge.dart';
import '../finance/financial_month.dart';
import '../planner/shift.dart';

/// Anything that can rebuild the alarm window.
///
/// An interface rather than the concrete scheduler so the controller can be
/// tested without a platform channel.
abstract class SchedulerPort {
  Future<void> rearm(SchedulingConfig config);
}

/// A [SchedulerPort] whose real implementation arrives later.
///
/// Arming the alarm window costs ~11.7s on a mid-range device (262 sequential
/// platform-channel calls), so it is deferred until after the first frame. A
/// settings change made during that gap must not be silently dropped, so this
/// simply waits for the real scheduler and then forwards — the re-arm happens
/// a moment late instead of never.
class DeferredSchedulerPort implements SchedulerPort {
  DeferredSchedulerPort(this._ready);

  final Future<SchedulerPort?> _ready;

  @override
  Future<void> rearm(SchedulingConfig config) async {
    final real = await _ready;
    await real?.rearm(config);
  }
}

class RollingWindowSchedulerPort implements SchedulerPort {
  RollingWindowSchedulerPort(this._scheduler);
  final RollingWindowScheduler _scheduler;

  @override
  Future<void> rearm(SchedulingConfig config) => _scheduler.rearm(config);
}

/// Writes settings and keeps the alarm window in step with them.
///
/// The spec's rule: any change to location, calculation method, madhab,
/// timezone, iqama offsets, or notification preferences cancels and rebuilds
/// the rolling window immediately. Changes that cannot affect alarms — the
/// tasbeeh target, the khatma length — deliberately do not.
class SettingsController {
  SettingsController({
    required this.db,
    required this.scheduler,
    this.location,
  });

  final NouriDatabase db;
  final SchedulerPort scheduler;

  /// Null when the platform cannot provide location at all (widget tests).
  final LocationPort? location;

  Future<SettingsRow> read() => db.settingsDao.get();

  /// The re-arm currently running, if any.
  Future<void>? _rearming;

  /// True when a change landed while a re-arm was already in flight.
  bool _rearmAgain = false;

  /// Serialises read-modify-write pairs against the settings row.
  Future<void> _queue = Future<void>.value();

  /// Completes when every requested re-arm has finished.
  ///
  /// Nothing in the app awaits this — the UI deliberately does not wait for
  /// the window. It exists so tests can wait for the background work instead
  /// of sleeping and hoping.
  Future<void> get pendingRearm async {
    while (_rearming != null) {
      await _rearming;
    }
  }

  /// Requests a window rebuild without waiting for it.
  ///
  /// Arming costs ~11.7s (262 sequential platform-channel calls — see
  /// [DeferredSchedulerPort]). Awaiting that before refreshing the screen is
  /// what made the iqama stepper swallow three taps out of four: the row held
  /// its old value for eleven seconds, and every tap in that window recomputed
  /// `shown + 5` from the same stale number and wrote it again.
  ///
  /// Requests arriving while one is running collapse into a single follow-up,
  /// so a burst of taps costs one re-arm *after* the burst rather than one
  /// each — four taps would otherwise be 47 seconds of work for a setting
  /// changed once. The follow-up always reads the row fresh, so the window
  /// ends up matching the final state whatever order the taps landed in.
  void _requestRearm() {
    if (_rearming != null) {
      _rearmAgain = true;
      return;
    }
    _rearming = () async {
      try {
        do {
          _rearmAgain = false;
          await _rearmFromSettings();
        } while (_rearmAgain);
      } catch (_) {
        // Nobody awaits this any more, so a throw here would surface as an
        // unhandled asynchronous error rather than reaching a caller. It can
        // happen for ordinary reasons — the database closed underneath a
        // re-arm still in flight, or the platform channel going away as the
        // app is torn down — and the window is rebuilt from scratch on the
        // next launch regardless, so losing this one costs nothing.
        //
        // Deliberately not silent about *scheduling* failures: those come
        // back through NotificationStatus, which the settings panel reads
        // live and states plainly.
      } finally {
        _rearming = null;
      }
    }();
  }

  /// Runs [work] after every write already queued.
  ///
  /// Without this, two taps can both read the settings row before either
  /// writes, and the second write overwrites the first — the same lost update
  /// the delta step exists to prevent, one layer down.
  Future<T> _serialised<T>(Future<T> Function() work) {
    final next = _queue.then((_) => work());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _rearmFromSettings() async {
    final s = await db.settingsDao.get();

    // The days the user has said they are fasting, over the window the water
    // reminders actually cover. Read here rather than in the scheduler so the
    // scheduler stays pure.
    final today = DateTime.now();
    final fasting = await db.waterDao.fastingBetween(
      today,
      DateTime(today.year, today.month, today.day + 14),
    );
    await scheduler.rearm(SchedulingConfig(
      budgetNote: await _budgetNote(today, s.financialMonthStartDay),
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
      // Only قيام reads this: on a night shift the last third is duty time.
      shift: switch (s.shiftType) {
        'evening' => ShiftType.evening,
        'night' => ShiftType.night,
        'off' => ShiftType.off,
        _ => ShiftType.morning,
      },
      fastingDays: {for (final f in fasting) dayOf(f.date)},
      hijriOffsetDays: s.hijriOffsetDays,
    ));
  }

  /// One quiet line about a budget running ahead of the month, or null.
  ///
  /// Read here rather than in the scheduler for the same reason the fasting
  /// days are: the scheduler is pure and knows nothing about the database.
  /// Budget state is not knowable ahead the way a prayer time is, so this is
  /// the numbers as they stand right now — recomputed on every launch and
  /// every settings change, which is when `rearm` runs.
  Future<String?> _budgetNote(DateTime today, int startDay) async {
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

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    required String cityLabel,
  }) async {
    await db.settingsDao.update(SettingsRowsCompanion(
      latitude: Value(latitude),
      longitude: Value(longitude),
      cityLabel: Value(cityLabel),
    ));
    _requestRearm();
  }

  /// Asks the device where it is and stores the result.
  ///
  /// Returns the location actually in use afterwards. A failure is not an
  /// error: Nouri keeps the coordinates it already has (Kuwait by default) and
  /// reports that it fell back, so the UI can say so plainly rather than
  /// pretending the update worked.
  Future<ResolvedLocation> detectLocation() async {
    // Defensive even though GeolocatorLocationPort already swallows its own
    // failures: a location lookup must never be able to take Settings down,
    // whatever port is injected.
    ResolvedLocation? found;
    try {
      found = await location?.current();
    } catch (_) {
      found = null;
    }

    if (found == null) {
      final s = await db.settingsDao.get();
      return ResolvedLocation(
        latitude: s.latitude,
        longitude: s.longitude,
        source: 'fallback',
      );
    }

    await updateLocation(
      latitude: found.latitude,
      longitude: found.longitude,
      cityLabel: 'موقعك الحالي',
    );
    return found;
  }

  Future<void> updateMethod(String method) async {
    await db.settingsDao
        .update(SettingsRowsCompanion(calculationMethod: Value(method)));
    _requestRearm();
  }

  Future<void> updateMadhab(String madhab) async {
    await db.settingsDao.update(SettingsRowsCompanion(madhab: Value(madhab)));
    _requestRearm();
  }

  /// Clamped to ±1 day: the civil calculation never differs from local
  /// sighting by more than that, so a larger value would be a mistake.
  Future<void> updateHijriOffset(int days) async {
    final clamped = days.clamp(-1, 1);
    await db.settingsDao
        .update(SettingsRowsCompanion(hijriOffsetDays: Value(clamped)));
    // Hijri display only — no alarm depends on it.
  }

  Future<void> updateIqamaOffset(String prayer, int minutes) async {
    await _serialised(() async {
      final s = await db.settingsDao.get();
      final offsets = decodeIqamaOffsets(s.iqamaOffsetsJson)
        ..[prayer] = minutes.clamp(0, 120);
      await db.settingsDao.update(
        SettingsRowsCompanion(
            iqamaOffsetsJson: Value(encodeIqamaOffsets(offsets))),
      );
    });
    _requestRearm();
  }

  /// Moves one iqama offset by [delta] minutes and returns where it landed.
  ///
  /// A delta rather than an absolute value, deliberately. The screen used to
  /// compute `shown + 5` and send that, which is only correct while the shown
  /// value is current — and it was not, because the previous tap was still
  /// inside an 11.7-second re-arm. Two taps then wrote the same number twice
  /// and the user saw one move for four presses.
  ///
  /// Resolving the delta against the row itself, inside the write queue, makes
  /// overlapping taps compound. That is what a button pressed twice means.
  Future<int> stepIqamaOffset(String prayer, int delta) async {
    final landed = await _serialised(() async {
      final s = await db.settingsDao.get();
      final offsets = decodeIqamaOffsets(s.iqamaOffsetsJson);
      final next = ((offsets[prayer] ?? 0) + delta).clamp(0, 120);
      offsets[prayer] = next;
      await db.settingsDao.update(
        SettingsRowsCompanion(
            iqamaOffsetsJson: Value(encodeIqamaOffsets(offsets))),
      );
      return next;
    });
    _requestRearm();
    return landed;
  }

  Future<void> toggleChannel(String channel, bool enabled) async {
    final companion = switch (channel) {
      'adhan' => SettingsRowsCompanion(notifyAdhan: Value(enabled)),
      'iqama' => SettingsRowsCompanion(notifyIqama: Value(enabled)),
      'athkar' => SettingsRowsCompanion(notifyAthkar: Value(enabled)),
      'wird' => SettingsRowsCompanion(notifyWird: Value(enabled)),
      'fasting' => SettingsRowsCompanion(notifyFasting: Value(enabled)),
      'water' => SettingsRowsCompanion(notifyWater: Value(enabled)),
      'qiyam' => SettingsRowsCompanion(notifyQiyam: Value(enabled)),
      _ => throw ArgumentError('unknown channel: $channel'),
    };
    await db.settingsDao.update(companion);
    _requestRearm();
  }

  /// Does **not** rearm: the tasbeeh target has no bearing on any alarm.
  Future<void> updateTasbeehTarget(int target) async {
    await db.settingsDao.update(
      SettingsRowsCompanion(tasbeehTarget: Value(target.clamp(1, 10000))),
    );
  }

  /// Does **not** rearm.
  Future<void> updateKhatmaPages(int pages) async {
    await db.settingsDao.update(
      SettingsRowsCompanion(khatmaTotalPages: Value(pages.clamp(1, 2000))),
    );
  }

  /// Does **not** rearm: money has no bearing on any alarm.
  Future<void> updateMonthlyIncome(int fils) => db.settingsDao.update(
        SettingsRowsCompanion(monthlyIncomeFils: Value(fils.clamp(0, 1 << 40))),
      );

  /// Does **not** rearm. Clamped to 1–28 so February always has the day.
  Future<void> updateFinancialMonthStartDay(int day) => db.settingsDao.update(
        SettingsRowsCompanion(
            financialMonthStartDay: Value(day.clamp(1, 28))),
      );

  /// Does **not** rearm: walking has no bearing on any alarm.
  ///
  /// Clamped to a stride a human actually has. A mistyped 5 or 500 would make
  /// every distance the app ever shows wrong, and silently.
  Future<void> updateStrideCm(int cm) => db.settingsDao.update(
        SettingsRowsCompanion(strideCm: Value(cm.clamp(30, 120))),
      );

  /// Does **not** rearm. Off by default and opt-in: a walk that quietly
  /// invented steps on a real phone would be the app lying about the user's
  /// own body.
  Future<void> setAllowSimulatedSteps(bool allow) => db.settingsDao.update(
        SettingsRowsCompanion(allowSimulatedSteps: Value(allow)),
      );

  /// Does **not** rearm: the shift shapes the planned day, not the alarms.
  /// Prayer times come from the sun, and they do not care what shift it is.
  Future<void> updateShift(String shiftType) => db.settingsDao.update(
        SettingsRowsCompanion(shiftType: Value(shiftType)),
      );

  /// Marks a day as a fast, and **rearms**.
  ///
  /// The re-arm is the point. Water reminders for today are already sitting in
  /// AlarmManager by the time the user flips the switch, and they cannot know
  /// they have been overruled — so the answer has to reach back and rebuild
  /// the window, exactly as logging a prayer cancels its follow-ups.
  Future<void> setFastingDay(DateTime date, bool fasting) async {
    await db.waterDao.setFasting(date, fasting);
    _requestRearm();
  }

  Future<void> markOnboardingComplete() => db.settingsDao
      .update(const SettingsRowsCompanion(onboardingComplete: Value(true)));
}
