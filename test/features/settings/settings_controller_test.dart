import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
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
    expect(scheduler.rearmCount, 1);
    expect((await db.settingsDao.get()).calculationMethod, 'ummAlQura');
    expect(scheduler.last!.geo.method, 'ummAlQura');
  });

  test('changing the madhab reschedules the window', () async {
    await controller.updateMadhab('hanafi');
    expect(scheduler.rearmCount, 1);
    expect(scheduler.last!.geo.madhab, 'hanafi');
  });

  test('changing an iqama offset reschedules the window', () async {
    await controller.updateIqamaOffset('maghrib', 25);
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
    expect(scheduler.rearmCount, 1);
    expect(scheduler.last!.geo.latitude, closeTo(25.2048, 0.0001));
    expect((await db.settingsDao.get()).cityLabel, 'دبي');
  });

  test('toggling a notification channel reschedules the window', () async {
    await controller.toggleChannel('iqama', false);
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
    expect(scheduler.rearmCount, 0,
        reason: 'the tasbeeh target has no bearing on alarms');
    expect((await db.settingsDao.get()).tasbeehTarget, 300);
  });

  test('changing the khatma length does NOT reschedule', () async {
    await controller.updateKhatmaPages(300);
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
}
