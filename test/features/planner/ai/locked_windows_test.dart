import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/ai/locked_windows.dart';
import 'package:nouri/features/planner/daily_tasks.dart';
import 'package:nouri/features/planner/day_plan.dart';
import 'package:nouri/features/planner/day_planner.dart';
import 'package:nouri/features/planner/shift.dart';

/// The hours the AI plan may not use — stated to the model, and enforced on
/// its reply.
///
///   «لاحظت ان الخطة لا بتحسب عدد ساعات النوم ولا عدد ساعات الدوام يعني
///    مممكن كل التاسكات في الأوقات بتاع النوم او الدوام»
void main() {
  final date = DateTime(2026, 9, 13);
  final times = const PrayerTimesService().forDate(date, GeoConfig.kuwaitCity);

  DayPlan plan(ShiftPattern shift) => planDay(
        date: date,
        shift: shift,
        prayers: times,
        tasks: dailyTasksFor(date: date, shift: shift),
      );

  group('lockedWindowsFor', () {
    test('a morning shift: sleep, work, and the commute either side', () {
      final windows = lockedWindowsFor(plan(ShiftPattern.morning));
      final labels = windows.map((w) => '${w.label}${w.lightOnly ? '*' : ''}').toList();
      // Last night's tail first: midnight to the wake is sleep too.
      expect(labels, ['النوم', 'المواصلات*', 'الدوام', 'المواصلات*', 'النوم']);
      expect(windows.first.start, DateTime(2026, 9, 13));
      expect(windows.first.end, times.fajr,
          reason: 'fajr outranks the 05:00 wake — the day starts there');

      final work = windows.firstWhere((w) => w.label == 'الدوام');
      expect(work.start, DateTime(2026, 9, 13, 7, 0));
      expect(work.end, DateTime(2026, 9, 13, 14, 0));

      // Tonight's sleep is the last window; last night's tail is the first.
      final sleep = windows.lastWhere((w) => w.label == 'النوم');
      expect(sleep.start.isAfter(times.isha), isTrue, reason: 'never before isha');
      expect(sleep.end, DateTime(2026, 9, 14, 5, 0), reason: 'the next wake');
    });

    test('the user\'s own hours are the ones locked', () {
      final custom = ShiftPattern.custom(
        type: ShiftType.morning,
        workStart: const Clock(8, 0),
        workEnd: const Clock(16, 0),
        commuteBefore: const Duration(minutes: 30),
      );
      final windows = lockedWindowsFor(plan(custom));
      final work = windows.firstWhere((w) => w.label == 'الدوام');
      expect(work.start, DateTime(2026, 9, 13, 8, 0));
      expect(work.end, DateTime(2026, 9, 13, 16, 0));
      final out = windows.firstWhere((w) => w.lightOnly);
      expect(out.start, DateTime(2026, 9, 13, 7, 30));
    });

    test('a night shift: last night\'s duty till morning, tonight\'s past midnight', () {
      final windows = lockedWindowsFor(plan(ShiftPattern.night));
      final duties = windows.where((w) => w.label == 'الدوام').toList();
      expect(duties, hasLength(2));
      expect(duties.first.start, DateTime(2026, 9, 13, 0, 0));
      expect(duties.first.end, DateTime(2026, 9, 13, 7, 0));
      expect(duties.last.start, DateTime(2026, 9, 13, 22, 0));
      expect(duties.last.end, DateTime(2026, 9, 14, 7, 0));
    });

    test('a day off locks only sleep — last night\'s tail and tonight\'s', () {
      final windows = lockedWindowsFor(plan(ShiftPattern.dayOff));
      expect(windows.map((w) => w.label), ['النوم', 'النوم']);
    });
  });

  group('violationFor', () {
    final windows = lockedWindowsFor(plan(ShiftPattern.morning));

    test('inside work is out, heavy or light', () {
      final at = DateTime(2026, 9, 13, 10, 0);
      expect(violationFor(at, windows: windows, heavy: true), RemovedReason.inWork);
      expect(violationFor(at, windows: windows, heavy: false), RemovedReason.inWork);
    });

    test('inside sleep is out — tonight\'s, and last night\'s tail', () {
      expect(violationFor(DateTime(2026, 9, 14, 1, 0), windows: windows, heavy: false),
          RemovedReason.inSleep);
      expect(violationFor(DateTime(2026, 9, 13, 2, 0), windows: windows, heavy: false),
          RemovedReason.inSleep, reason: 'the wird the first real plan put at 02:00');
    });

    test('the commute takes a light task and refuses a heavy one', () {
      final at = DateTime(2026, 9, 13, 6, 30);
      expect(violationFor(at, windows: windows, heavy: false), isNull,
          reason: 'athkar by ear on the bus, as the brief says');
      expect(violationFor(at, windows: windows, heavy: true), RemovedReason.heavyInCommute);
    });

    test('a free evening is free', () {
      final at = DateTime(2026, 9, 13, 17, 0);
      expect(violationFor(at, windows: windows, heavy: true), isNull);
    });

    test('an edge belongs to the window on the left of it', () {
      // 14:00 is the end of work and the start of the ride home: the ride.
      final at = DateTime(2026, 9, 13, 14, 0);
      expect(violationFor(at, windows: windows, heavy: true), RemovedReason.heavyInCommute);
      // The brief's morning pattern is home at 15:15; the window ends there.
      expect(violationFor(DateTime(2026, 9, 13, 15, 15), windows: windows, heavy: true), isNull,
          reason: 'home: the window ends there');
    });
  });
}
