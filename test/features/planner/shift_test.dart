import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/planner/day_plan.dart';
import 'package:nouri/features/planner/shift.dart';

void main() {
  group('shift patterns match the brief', () {
    test('the morning shift', () {
      const s = ShiftPattern.morning;
      expect(s.wake, const Clock(5, 0));
      expect(s.leaveHome, const Clock(6, 0));
      expect(s.workStart, const Clock(7, 0));
      expect(s.workEnd, const Clock(14, 0));
      expect(s.crossesMidnight, isFalse);
    });

    test('the evening shift', () {
      const s = ShiftPattern.evening;
      expect(s.wake, const Clock(12, 0));
      expect(s.workStart, const Clock(14, 0));
      expect(s.workEnd, const Clock(21, 0));
      expect(s.homeAgain, const Clock(22, 0));
    });

    test('the night shift crosses midnight and has no fixed wake', () {
      const s = ShiftPattern.night;
      expect(s.workStart, const Clock(22, 0));
      expect(s.workEnd, const Clock(7, 0));
      expect(s.crossesMidnight, isTrue);
      expect(s.wake, isNull,
          reason: 'wake is computed backwards from the next duty, not fixed');
    });

    test('a day off has no work anchors', () {
      expect(ShiftPattern.dayOff.isWorking, isFalse);
      expect(ShiftPattern.dayOff.workStart, isNull);
    });

    test('every shift type resolves to a pattern', () {
      for (final t in ShiftType.values) {
        expect(ShiftPattern.forType(t).type, t);
      }
    });
  });

  group('commute', () {
    test('the morning commute is an hour of usable time', () {
      // The brief calls the commute usable: light tasks belong here.
      expect(ShiftPattern.morning.outboundCommute, const Duration(hours: 1));
    });

    test('a day off has no commute', () {
      expect(ShiftPattern.dayOff.outboundCommute, isNull);
    });
  });

  group('Clock', () {
    test('converts to a real time on a given day', () {
      final t = const Clock(16, 15).on(DateTime(2026, 9, 6));
      expect(t, DateTime(2026, 9, 6, 16, 15));
    });

    test('orders by minutes from midnight', () {
      expect(const Clock(6, 0).minutesFromMidnight, 360);
      expect(const Clock(22, 30).minutesFromMidnight, 1350);
    });

    test('compares by value, so patterns can be asserted', () {
      expect(const Clock(5, 0), const Clock(5, 0));
      expect(const Clock(5, 0), isNot(const Clock(5, 1)));
    });
  });

  group('task model', () {
    const walk = PlannedTask(
      id: 'walk',
      title: 'مشي ٣٠ دقيقة',
      pillar: TaskPillar.body,
      weight: TaskWeight.heavy,
      duration: Duration(minutes: 30),
      anchor: FlexibleAnchor(preferredBlock: DayBlockKind.afterWork),
    );

    const lecture = PlannedTask(
      id: 'lecture',
      title: 'محاضرة',
      pillar: TaskPillar.mind,
      weight: TaskWeight.light,
      duration: Duration(minutes: 45),
      anchor: FlexibleAnchor(),
    );

    test('only light tasks can ride along with a commute or break', () {
      expect(walk.canRideAlong, isFalse,
          reason: 'a walk needs a place and focus');
      expect(lecture.canRideAlong, isTrue,
          reason: 'a lecture can be heard on the bus');
    });

    test('anchors cover clock, prayer and flexible', () {
      const clock = ClockAnchor(Clock(20, 0));
      const prayer =
          PrayerAnchor('maghrib', offset: Duration(minutes: 16));
      const flexible = FlexibleAnchor();

      expect(clock.at.hour, 20);
      expect(prayer.prayer, 'maghrib');
      expect(prayer.offset, const Duration(minutes: 16));
      expect(flexible.preferredBlock, isNull);
    });

    test('a prayer anchor can sit before its prayer', () {
      // Evening athkar ride 45 minutes ahead of maghrib.
      const before = PrayerAnchor('maghrib', offset: Duration(minutes: -45));
      expect(before.offset.isNegative, isTrue);
    });
  });

  group('day blocks', () {
    test('the four blocks are named as the brief names them', () {
      expect(
        DayBlockKind.values.map((b) => b.arabicLabel).toList(),
        ['الصباح', 'الدوام', 'بعد الدوام', 'المسا'],
      );
    });

    test('a block reports its length and whether it is empty', () {
      final block = DayBlock(
        kind: DayBlockKind.afterWork,
        start: DateTime(2026, 9, 6, 15, 15),
        end: DateTime(2026, 9, 6, 18, 4),
        tasks: const [],
      );
      expect(block.length, const Duration(hours: 2, minutes: 49));
      expect(block.isEmpty, isTrue);
    });

    test('a plan can find a block by kind', () {
      final plan = DayPlan(
        date: DateTime(2026, 9, 6),
        shift: ShiftPattern.morning,
        blocks: [
          DayBlock(
            kind: DayBlockKind.work,
            start: DateTime(2026, 9, 6, 7),
            end: DateTime(2026, 9, 6, 14),
            tasks: const [],
          ),
        ],
      );
      expect(plan.blockFor(DayBlockKind.work), isNotNull);
      expect(plan.blockFor(DayBlockKind.evening), isNull);
    });
  });
}
