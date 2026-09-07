import 'package:drift/drift.dart' show Value;

import '../../core/notifications/rolling_window_scheduler.dart';
import '../../core/time/geo_config.dart';
import '../../core/time/location_service.dart';
import '../../data/db/nouri_database.dart';

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

  Future<void> _rearmFromSettings() async {
    final s = await db.settingsDao.get();
    await scheduler.rearm(SchedulingConfig(
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
      hijriOffsetDays: s.hijriOffsetDays,
    ));
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
    await _rearmFromSettings();
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
    await _rearmFromSettings();
  }

  Future<void> updateMadhab(String madhab) async {
    await db.settingsDao.update(SettingsRowsCompanion(madhab: Value(madhab)));
    await _rearmFromSettings();
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
    final s = await db.settingsDao.get();
    final offsets = decodeIqamaOffsets(s.iqamaOffsetsJson)
      ..[prayer] = minutes.clamp(0, 120);
    await db.settingsDao.update(
      SettingsRowsCompanion(iqamaOffsetsJson: Value(encodeIqamaOffsets(offsets))),
    );
    await _rearmFromSettings();
  }

  Future<void> toggleChannel(String channel, bool enabled) async {
    final companion = switch (channel) {
      'adhan' => SettingsRowsCompanion(notifyAdhan: Value(enabled)),
      'iqama' => SettingsRowsCompanion(notifyIqama: Value(enabled)),
      'athkar' => SettingsRowsCompanion(notifyAthkar: Value(enabled)),
      'wird' => SettingsRowsCompanion(notifyWird: Value(enabled)),
      'fasting' => SettingsRowsCompanion(notifyFasting: Value(enabled)),
      _ => throw ArgumentError('unknown channel: $channel'),
    };
    await db.settingsDao.update(companion);
    await _rearmFromSettings();
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

  Future<void> markOnboardingComplete() => db.settingsDao
      .update(const SettingsRowsCompanion(onboardingComplete: Value(true)));
}
