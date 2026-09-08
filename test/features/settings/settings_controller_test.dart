import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/location_service.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/settings/settings_controller.dart';

/// Records how often the window was rebuilt, and with what.
class RecordingScheduler implements SchedulerPort {
  int rearmCount = 0;
  SchedulingConfig? last;

  @override
  Future<void> rearm(SchedulingConfig config) async {
    rearmCount++;
    last = config;
  }
}

/// Returns whatever it is told to, including nothing.
class StubLocation implements LocationPort {
  StubLocation(this.result);
  final ResolvedLocation? result;
  int calls = 0;

  @override
  Future<ResolvedLocation?> current() async {
    calls++;
    return result;
  }
}

/// Every failure mode of the real port surfaces as null, so one throwing stub
/// covers permission denial, services off, and timeouts alike.
class ThrowingLocation implements LocationPort {
  @override
  Future<ResolvedLocation?> current() async => throw StateError('no gps');
}

void main() {
  late NouriDatabase db;
  late RecordingScheduler scheduler;
  late SettingsController controller;

  setUp(() {
    db = NouriDatabase.forTesting(NativeDatabase.memory());
    scheduler = RecordingScheduler();
    controller = SettingsController(db: db, scheduler: scheduler);
  });
  tearDown(() async => db.close());

  test('changing the calculation method reschedules the window', () async {
    await controller.updateMethod('ummAlQura');
    await controller.pendingRearm;
    expect(scheduler.rearmCount, 1);
    expect((await db.settingsDao.get()).calculationMethod, 'ummAlQura');
    expect(scheduler.last!.geo.method, 'ummAlQura');
  });

  test('changing the madhab reschedules the window', () async {
    await controller.updateMadhab('hanafi');
    await controller.pendingRearm;
    expect(scheduler.rearmCount, 1);
    expect(scheduler.last!.geo.madhab, 'hanafi');
  });

  test('changing an iqama offset reschedules the window', () async {
    await controller.updateIqamaOffset('maghrib', 25);
    await controller.pendingRearm;
    expect(scheduler.rearmCount, 1);
    final offsets = decodeIqamaOffsets(
      (await db.settingsDao.get()).iqamaOffsetsJson,
    );
    expect(offsets['maghrib'], 25);
    expect(offsets['fajr'], 20, reason: 'other offsets are untouched');
  });

  test('changing location reschedules the window', () async {
    await controller.updateLocation(
      latitude: 25.2048,
      longitude: 55.2708,
      cityLabel: 'دبي',
    );
    await controller.pendingRearm;
    expect(scheduler.rearmCount, 1);
    expect(scheduler.last!.geo.latitude, closeTo(25.2048, 0.0001));
    expect((await db.settingsDao.get()).cityLabel, 'دبي');
  });

  test('toggling a notification channel reschedules the window', () async {
    await controller.toggleChannel('iqama', false);
    await controller.pendingRearm;
    expect(scheduler.rearmCount, 1);
    expect((await db.settingsDao.get()).notifyIqama, isFalse);
    expect(scheduler.last!.notifyIqama, isFalse);
  });

  test('every channel can be toggled independently', () async {
    await controller.toggleChannel('adhan', false);
    await controller.toggleChannel('athkar', false);
    final s = await db.settingsDao.get();
    expect(s.notifyAdhan, isFalse);
    expect(s.notifyAthkar, isFalse);
    expect(s.notifyIqama, isTrue, reason: 'untouched channels stay on');
    expect(s.notifyWird, isTrue);
  });

  test('an unknown channel is rejected rather than silently ignored', () async {
    expect(
      () => controller.toggleChannel('nonsense', false),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('changing the tasbeeh target does NOT reschedule', () async {
    await controller.updateTasbeehTarget(300);
    await controller.pendingRearm;
    expect(scheduler.rearmCount, 0,
        reason: 'the tasbeeh target has no bearing on alarms');
    expect((await db.settingsDao.get()).tasbeehTarget, 300);
  });

  test('changing the khatma length does NOT reschedule', () async {
    await controller.updateKhatmaPages(300);
    await controller.pendingRearm;
    expect(scheduler.rearmCount, 0);
    expect((await db.settingsDao.get()).khatmaTotalPages, 300);
  });

  test('the Hijri offset is clamped to plus or minus one day', () async {
    await controller.updateHijriOffset(5);
    expect((await db.settingsDao.get()).hijriOffsetDays, 1);
    await controller.updateHijriOffset(-9);
    expect((await db.settingsDao.get()).hijriOffsetDays, -1);
    await controller.updateHijriOffset(0);
    expect((await db.settingsDao.get()).hijriOffsetDays, 0);
  });

  test('the tasbeeh target can never be set below one', () async {
    await controller.updateTasbeehTarget(0);
    expect((await db.settingsDao.get()).tasbeehTarget, 1);
  });

  test('an iqama offset is clamped to a sane range', () async {
    await controller.updateIqamaOffset('fajr', -10);
    await controller.pendingRearm;
    expect(
      decodeIqamaOffsets((await db.settingsDao.get()).iqamaOffsetsJson)['fajr'],
      0,
    );
  });

  test('onboarding completion is persisted', () async {
    expect((await db.settingsDao.get()).onboardingComplete, isFalse);
    await controller.markOnboardingComplete();
    expect((await db.settingsDao.get()).onboardingComplete, isTrue);
  });

  group('detectLocation', () {
    test('stores device coordinates and reschedules', () async {
      final c = SettingsController(
        db: db,
        scheduler: scheduler,
        location: StubLocation(const ResolvedLocation(
          latitude: 30.0444,
          longitude: 31.2357,
          source: 'device',
        )),
      );

      final result = await c.detectLocation();
      await c.pendingRearm;

      expect(result.source, 'device');
      expect(result.isFallback, isFalse);
      final s = await db.settingsDao.get();
      expect(s.latitude, closeTo(30.0444, 0.0001));
      expect(scheduler.rearmCount, 1,
          reason: 'new coordinates change every prayer time');
    });

    test('a refusal keeps the existing coordinates and says so', () async {
      final c = SettingsController(
        db: db,
        scheduler: scheduler,
        location: StubLocation(null),
      );

      final result = await c.detectLocation();

      expect(result.isFallback, isTrue);
      expect(result.latitude, closeTo(29.3759, 0.0001),
          reason: 'still Kuwait, untouched');
      expect(scheduler.rearmCount, 0,
          reason: 'nothing changed, so nothing to reschedule');
    });

    test('no location port at all falls back rather than throwing', () async {
      final result = await controller.detectLocation();
      expect(result.isFallback, isTrue);
      expect(result.latitude, closeTo(29.3759, 0.0001));
    });

    test('a port that throws falls back instead of taking Settings down',
        () async {
      final c = SettingsController(
        db: db,
        scheduler: scheduler,
        location: ThrowingLocation(),
      );

      final result = await c.detectLocation();

      expect(result.isFallback, isTrue);
      expect(result.latitude, closeTo(29.3759, 0.0001));
    });

    test('a fallback never overwrites coordinates the user already set',
        () async {
      await controller.updateLocation(
        latitude: 25.2048,
        longitude: 55.2708,
        cityLabel: 'دبي',
      );
      await controller.pendingRearm;
      scheduler.rearmCount = 0;

      final c = SettingsController(
        db: db,
        scheduler: scheduler,
        location: StubLocation(null),
      );
      final result = await c.detectLocation();

      expect(result.latitude, closeTo(25.2048, 0.0001));
      expect((await db.settingsDao.get()).cityLabel, 'دبي');
      expect(scheduler.rearmCount, 0);
    });
  });

  // Reported from the phone on 8 September 2026:
  //
  //   «لما باجي ادوس ع الزائد او الناقص عشان ازود او أقلل وقت الإقامة في
  //   كليكات كتير غلط يعني ممكن ادوس ٣ او ٤ مرات عشان يزود او يقلل»
  //
  // Three or four taps to move the number once. The cause is in this file's
  // own doc comment: `DeferredSchedulerPort` measures a re-arm at ~11.7s (262
  // sequential platform-channel calls), and every stepper tap awaited one
  // before the screen refreshed. So the row showed the old value for eleven
  // seconds, and each further tap recomputed `shown + 5` from that same stale
  // number and wrote it again.
  group('the iqama stepper', () {
    test('four quick taps move it four steps, not one', () async {
      final gate = Completer<void>();
      final slow = GatedScheduler(gate.future);
      final c = SettingsController(db: db, scheduler: slow);

      final before = decodeIqamaOffsets(
          (await db.settingsDao.get()).iqamaOffsetsJson)['dhuhr']!;

      // Four taps with nothing awaited between them, which is what a fast
      // finger actually produces.
      await Future.wait([
        c.stepIqamaOffset('dhuhr', 5),
        c.stepIqamaOffset('dhuhr', 5),
        c.stepIqamaOffset('dhuhr', 5),
        c.stepIqamaOffset('dhuhr', 5),
      ]);

      final after = decodeIqamaOffsets(
          (await db.settingsDao.get()).iqamaOffsetsJson)['dhuhr']!;
      expect(after, before + 20, reason: 'four taps, four steps');

      gate.complete();
      await c.pendingRearm;
    });

    test('a tap returns before the re-arm does', () async {
      // What makes the row feel alive: it must update on the first tap, not
      // eleven seconds later.
      final gate = Completer<void>();
      final slow = GatedScheduler(gate.future);
      final c = SettingsController(db: db, scheduler: slow);

      final landed = await c
          .stepIqamaOffset('asr', 5)
          .timeout(const Duration(seconds: 1));

      expect(landed, isNotNull);
      expect(slow.finished, 0, reason: 'the re-arm has not finished yet');

      gate.complete();
      await c.pendingRearm;
      expect(slow.finished, 1);
    });

    test('a burst of taps costs one re-arm, not four', () async {
      // 262 platform-channel calls each. Four of them is 47 seconds of work
      // for a setting the user changed once.
      final gate = Completer<void>();
      final slow = GatedScheduler(gate.future);
      final c = SettingsController(db: db, scheduler: slow);

      for (var i = 0; i < 4; i++) {
        unawaited(c.stepIqamaOffset('fajr', 5));
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      gate.complete();
      await c.pendingRearm;

      expect(slow.started, lessThanOrEqualTo(2),
          reason: 'one re-arm in flight, at most one coalesced behind it');
    });

    test('the step returns where it landed, so the row need not re-read',
        () async {
      final before = decodeIqamaOffsets(
          (await db.settingsDao.get()).iqamaOffsetsJson)['isha']!;
      final landed = await controller.stepIqamaOffset('isha', 5);
      expect(landed, before + 5);
      await controller.pendingRearm;
    });

    test('it still clamps, and the clamp does not swallow the step', () async {
      await controller.updateIqamaOffset('maghrib', 0);
      await controller.pendingRearm;

      final landed = await controller.stepIqamaOffset('maghrib', -5);
      expect(landed, 0, reason: 'zero is the floor');

      final up = await controller.stepIqamaOffset('maghrib', 5);
      expect(up, 5, reason: 'and stepping back up still moves');
      await controller.pendingRearm;
    });

    test('a step still rebuilds the window — just not before the UI',
        () async {
      await controller.stepIqamaOffset('fajr', 5);
      await controller.pendingRearm;
      expect(scheduler.rearmCount, greaterThanOrEqualTo(1));
      expect(scheduler.last!.iqamaOffsets['fajr'], isNotNull);
    });
  });
}

/// A scheduler that does not finish until it is let go.
///
/// Stands in for the real one, which this codebase measures at ~11.7s. The
/// stepper bug is invisible against an instant fake, because the stale window
/// it depends on never opens.
class GatedScheduler implements SchedulerPort {
  GatedScheduler(this._gate);
  final Future<void> _gate;
  int started = 0;
  int finished = 0;

  @override
  Future<void> rearm(SchedulingConfig config) async {
    started++;
    await _gate;
    finished++;
  }
}
