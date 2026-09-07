import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/day_plan.dart';
import 'package:nouri/features/planner/day_planner.dart';
import 'package:nouri/features/planner/shift.dart';

/// Sunday 6 September 2026, Kuwait — the day in
/// `docs/superpowers/specs/slice2-worked-example.md`, planned by hand.
final day = DateTime(2026, 9, 6);

final prayers = DailyPrayerTimes(
  fajr: DateTime(2026, 9, 6, 4, 7),
  sunrise: DateTime(2026, 9, 6, 5, 30),
  dhuhr: DateTime(2026, 9, 6, 11, 46),
  asr: DateTime(2026, 9, 6, 15, 18),
  maghrib: DateTime(2026, 9, 6, 18, 4),
  isha: DateTime(2026, 9, 6, 19, 23),
);

PlannedTask task(
  String id, {
  required TaskWeight weight,
  Duration duration = const Duration(minutes: 30),
  TaskAnchor? anchor,
  TaskPillar pillar = TaskPillar.deen,
}) =>
    PlannedTask(
      id: id,
      title: id,
      pillar: pillar,
      weight: weight,
      duration: duration,
      anchor: anchor ?? const FlexibleAnchor(),
    );

DayPlan plan({
  ShiftPattern? shift,
  List<PlannedTask> tasks = const [],
  DateTime? now,
  PlannerConfig config = const PlannerConfig(),
}) =>
    planDay(
      date: day,
      shift: shift ?? ShiftPattern.morning,
      prayers: prayers,
      tasks: tasks,
      config: config,
      now: now,
    );

ScheduledTask? find(DayPlan p, String id) {
  for (final t in p.allTasks) {
    if (t.task.id == id) return t;
  }
  return null;
}

void main() {
  group('rule 1 — sleep is sized first, backwards from the wake time', () {
    test('a morning shift gets its seven hours', () {
      final p = plan();
      expect(p.sleep!.length, const Duration(hours: 7));
      expect(p.sleep!.end, DateTime(2026, 9, 7, 5, 0),
          reason: 'the sleep at the end of today ends at tomorrow wake');
      expect(p.sleep!.start, DateTime(2026, 9, 6, 22, 0));
    });

    test('bedtime never lands before isha', () {
      // Praying isha is not optional, and a plan that put the user in bed
      // before it would be wrong about the day.
      final p = plan();
      expect(p.sleep!.start.isAfter(prayers.isha), isTrue);
    });

    test('sleep is never cut below the floor to make room', () {
      // The brief's rule: when the day overfills, defer a task — never
      // shorten sleep.
      final p = plan(config: const PlannerConfig(
        targetSleep: Duration(hours: 12),
        minimumSleep: Duration(hours: 6),
      ));
      expect(p.sleep!.length, greaterThanOrEqualTo(const Duration(hours: 6)));
    });

    test('sleep is a real duration, on every day of the year', () {
      // The one place in this file that deliberately *offsets* rather than
      // constructs. Everywhere else `add(Duration(days: 1))` is the bug —
      // it is 24 absolute hours, which is the wrong length on a DST night.
      //
      // Sleep is the exception, and it is the exception on purpose: seven
      // hours of sleep is seven *real* hours. On a spring-forward night that
      // means bedtime lands at 21:00 rather than 22:00, and the user still
      // gets their seven hours. Constructing 22:00 there would quietly hand
      // them six.
      //
      // Anyone "fixing" this later to match the rest of the file would be
      // reintroducing exactly that, so the invariant is pinned across a whole
      // year rather than on one date — which also keeps the test independent
      // of whatever zone the machine running it happens to be in.
      for (var d = 0; d < 365; d++) {
        final date = DateTime(2026, 1, 1 + d);
        final p = planDay(
          date: date,
          shift: ShiftPattern.morning,
          prayers: DailyPrayerTimes(
            fajr: DateTime(date.year, date.month, date.day, 4, 7),
            sunrise: DateTime(date.year, date.month, date.day, 5, 30),
            dhuhr: DateTime(date.year, date.month, date.day, 11, 46),
            asr: DateTime(date.year, date.month, date.day, 15, 18),
            maghrib: DateTime(date.year, date.month, date.day, 18, 4),
            isha: DateTime(date.year, date.month, date.day, 19, 23),
          ),
          tasks: const [],
        );

        expect(p.sleep!.length, const Duration(hours: 7),
            reason: 'sleep on $date was ${p.sleep!.length}');
      }
    });

    test('the waking day never runs backwards, on any day of the year', () {
      for (var d = 0; d < 365; d++) {
        final date = DateTime(2026, 1, 1 + d);
        final p = planDay(
          date: date,
          shift: ShiftPattern.morning,
          prayers: DailyPrayerTimes(
            fajr: DateTime(date.year, date.month, date.day, 4, 7),
            sunrise: DateTime(date.year, date.month, date.day, 5, 30),
            dhuhr: DateTime(date.year, date.month, date.day, 11, 46),
            asr: DateTime(date.year, date.month, date.day, 15, 18),
            maghrib: DateTime(date.year, date.month, date.day, 18, 4),
            isha: DateTime(date.year, date.month, date.day, 19, 23),
          ),
          tasks: const [],
        );

        for (final b in p.blocks) {
          expect(b.end.isAfter(b.start), isTrue,
              reason: '${b.kind.name} on $date runs backwards');
        }
      }
    });

    test('a night shift sleeps forwards from coming home, not backwards',
        () {
      // There is no morning to wake for: the user gets home at 08:00 and
      // sleeps through the day.
      final p = plan(shift: ShiftPattern.night);
      expect(p.sleep!.start.hour, 9, reason: 'home at 08:00, an hour awake');
      expect(p.sleep!.length, const Duration(hours: 7));
    });
  });

  group('rule 2 — heavy tasks only where the user is home and free', () {
    test('a heavy task lands after getting home, never on the commute', () {
      final p = plan(tasks: [
        task('walk', weight: TaskWeight.heavy),
      ]);
      final walk = find(p, 'walk')!;
      expect(walk.start.isAfter(ShiftPattern.morning.homeAgain!.on(day)),
          isTrue);
      expect(walk.block, isNot(DayBlockKind.work));
    });

    test('a heavy task is deferred rather than squeezed into work time', () {
      // A shift with no free time at home at all.
      const allDay = ShiftPattern(
        type: ShiftType.morning,
        wake: Clock(5, 0),
        leaveHome: Clock(5, 30),
        workStart: Clock(6, 0),
        workEnd: Clock(21, 0),
        homeAgain: Clock(21, 30),
      );

      final p = plan(
        shift: allDay,
        tasks: [task('workout', weight: TaskWeight.heavy,
            duration: const Duration(hours: 2))],
      );

      expect(find(p, 'workout'), isNull);
      expect(p.deferred.single.reason, DeferralReason.needsHomeTime);
    });

    test('there is a settling gap between arriving home and working', () {
      final p = plan(tasks: [task('walk', weight: TaskWeight.heavy)]);
      final home = ShiftPattern.morning.homeAgain!.on(day);
      expect(
        find(p, 'walk')!.start.difference(home),
        greaterThanOrEqualTo(const Duration(minutes: 30)),
        reason: 'arriving is not the same as being available',
      );
    });
  });

  group('rule 3 — light tasks ride along', () {
    test('a light task can take the commute', () {
      final p = plan(tasks: [
        task('lecture',
            weight: TaskWeight.light,
            duration: const Duration(minutes: 45),
            anchor: const FlexibleAnchor(preferredBlock: DayBlockKind.morning)),
      ]);
      final lecture = find(p, 'lecture')!;
      expect(lecture.start.isBefore(ShiftPattern.morning.workStart!.on(day)),
          isTrue);
    });

    test('a light task can take a work break', () {
      final p = plan(tasks: [
        task('tasbeeh',
            weight: TaskWeight.light,
            duration: const Duration(minutes: 10),
            anchor: const FlexibleAnchor(preferredBlock: DayBlockKind.work)),
      ]);
      expect(find(p, 'tasbeeh')!.block, DayBlockKind.work);
    });
  });

  group('rule 4 — breaks scale with the effort just finished', () {
    test('two heavy tasks are separated by the heavy break', () {
      final p = plan(tasks: [
        task('walk', weight: TaskWeight.heavy,
            duration: const Duration(minutes: 30)),
        task('wird', weight: TaskWeight.heavy,
            duration: const Duration(minutes: 30)),
      ]);
      final first = find(p, 'walk')!;
      final second = find(p, 'wird')!;
      expect(second.start.difference(first.end),
          greaterThanOrEqualTo(const Duration(minutes: 30)));
    });

    test('two light tasks barely pause between them', () {
      final p = plan(tasks: [
        task('a', weight: TaskWeight.light,
            duration: const Duration(minutes: 10)),
        task('b', weight: TaskWeight.light,
            duration: const Duration(minutes: 10)),
      ]);
      final gap = find(p, 'b')!.start.difference(find(p, 'a')!.end);
      expect(gap, lessThan(const Duration(minutes: 30)));
    });
  });

  group('rule 6 — prayers are anchors, not tasks', () {
    test('all five appear, at their real times', () {
      final p = plan();
      for (final slot in prayers.ordered) {
        final placed = find(p, 'prayer-${slot.name}');
        expect(placed, isNotNull, reason: slot.name);
        expect(placed!.start, slot.time);
      }
    });

    test('nothing is scheduled on top of a prayer', () {
      final p = plan(tasks: [
        for (var i = 0; i < 6; i++)
          task('t$i', weight: TaskWeight.light,
              duration: const Duration(minutes: 20)),
      ]);

      for (final slot in prayers.ordered) {
        final prayerEnd = slot.time.add(const Duration(minutes: 15));
        for (final t in p.allTasks) {
          if (t.task.id.startsWith('prayer-')) continue;
          final overlaps =
              t.start.isBefore(prayerEnd) && slot.time.isBefore(t.end);
          expect(overlaps, isFalse,
              reason: '${t.task.id} at ${t.start} overlaps ${slot.name}');
        }
      }
    });

    test('a prayer during work is filed under الدوام', () {
      final p = plan();
      expect(find(p, 'prayer-dhuhr')!.block, DayBlockKind.work,
          reason: 'dhuhr at 11:46 falls inside 07:00-14:00');
    });
  });

  group('anchored tasks', () {
    test('a prayer anchor follows the prayer, offset and all', () {
      final p = plan(tasks: [
        task('evening-athkar',
            weight: TaskWeight.light,
            duration: const Duration(minutes: 15),
            anchor: const PrayerAnchor('maghrib',
                offset: Duration(minutes: 16))),
      ]);
      expect(find(p, 'evening-athkar')!.start,
          prayers.maghrib.add(const Duration(minutes: 16)));
    });

    test('a clock anchor takes its exact time', () {
      final p = plan(tasks: [
        task('breakfast',
            weight: TaskWeight.light,
            pillar: TaskPillar.body,
            anchor: const ClockAnchor(Clock(5, 0))),
      ]);
      expect(find(p, 'breakfast')!.start, DateTime(2026, 9, 6, 5, 0));
    });

    test('an anchor inside the sleep window is deferred, not honoured', () {
      final p = plan(tasks: [
        task('midnight', weight: TaskWeight.light,
            anchor: const ClockAnchor(Clock(2, 0))),
      ]);
      expect(find(p, 'midnight'), isNull);
      expect(p.deferred.single.reason, DeferralReason.outsideTheDay);
    });

    test('an anchored task wins its minutes over a flexible one', () {
      final p = plan(tasks: [
        task('flexible', weight: TaskWeight.light,
            duration: const Duration(minutes: 30)),
        task('anchored',
            weight: TaskWeight.light,
            duration: const Duration(minutes: 30),
            anchor: const ClockAnchor(Clock(5, 0))),
      ]);
      expect(find(p, 'anchored')!.start, DateTime(2026, 9, 6, 5, 0));
    });
  });

  group('when the day does not fit', () {
    test('the overflow is deferred and named, never silently dropped', () {
      final p = plan(tasks: [
        for (var i = 0; i < 40; i++)
          task('t$i', weight: TaskWeight.heavy,
              duration: const Duration(hours: 1)),
      ]);

      expect(p.deferred, isNotEmpty);
      expect(p.deferred.first.arabicNote, isNotEmpty,
          reason: 'the user is always told what was dropped');
    });

    test('heavy tasks are placed before light ones compete for the room', () {
      // A heavy task fits in fewer places, so letting the light ones settle
      // first would leave nowhere for it to go.
      final p = plan(tasks: [
        task('light', weight: TaskWeight.light,
            duration: const Duration(hours: 2)),
        task('heavy', weight: TaskWeight.heavy,
            duration: const Duration(hours: 2)),
      ]);
      expect(find(p, 'heavy'), isNotNull);
    });

    test('a deferral note explains rather than accuses', () {
      final p = plan(tasks: [
        task('reading', weight: TaskWeight.heavy,
            duration: const Duration(hours: 9)),
      ]);
      final note = p.deferred.single.arabicNote;
      for (final blame in ['فاتتك', 'ضيعت', 'فشل', 'كسلان']) {
        expect(note.contains(blame), isFalse, reason: note);
      }
    });
  });

  group('re-planning mid-day', () {
    test('nothing is placed before now', () {
      final noon = DateTime(2026, 9, 6, 12, 0);
      final p = plan(
        now: noon,
        tasks: [task('walk', weight: TaskWeight.heavy)],
      );
      for (final t in p.allTasks) {
        expect(t.start.isBefore(noon), isFalse,
            reason: '${t.task.id} at ${t.start} is behind now');
      }
    });

    test('a prayer already passed is not re-listed', () {
      final p = plan(now: DateTime(2026, 9, 6, 12, 0));
      expect(find(p, 'prayer-fajr'), isNull);
      expect(find(p, 'prayer-dhuhr'), isNull, reason: '11:46 has passed');
      expect(find(p, 'prayer-asr'), isNotNull);
    });

    test('re-planning is deterministic — the same inputs, the same day', () {
      final noon = DateTime(2026, 9, 6, 12, 0);
      final a = plan(now: noon, tasks: [task('x', weight: TaskWeight.heavy)]);
      final b = plan(now: noon, tasks: [task('x', weight: TaskWeight.heavy)]);
      expect(find(a, 'x')!.start, find(b, 'x')!.start);
    });
  });

  group('the shapes of a day', () {
    test('a morning shift shows the four blocks', () {
      final p = plan(tasks: [
        task('a', weight: TaskWeight.light,
            anchor: const FlexibleAnchor(preferredBlock: DayBlockKind.work)),
      ]);
      expect(p.blocks.map((b) => b.kind), contains(DayBlockKind.work));
      expect(p.blocks.map((b) => b.kind), contains(DayBlockKind.evening));
    });

    test('a day off is left loose rather than filled with invented work', () {
      final p = plan(shift: ShiftPattern.dayOff);
      // The prayers still anchor it; nothing else was asked for, so nothing
      // else appears.
      expect(p.allTasks.where((t) => !t.task.id.startsWith('prayer-')),
          isEmpty);
      expect(p.allTasks.where((t) => t.task.id.startsWith('prayer-')),
          isNotEmpty);
      expect(p.blocks.map((b) => b.kind), isNot(contains(DayBlockKind.work)));
    });

    test('a day off still takes what the user did ask for', () {
      final p = plan(
        shift: ShiftPattern.dayOff,
        tasks: [task('reading', weight: TaskWeight.heavy)],
      );
      expect(find(p, 'reading'), isNotNull);
    });

    test('a night day has a different shape, and says so', () {
      final p = plan(shift: ShiftPattern.night);
      expect(p.blocks.map((b) => b.kind), isNot(contains(DayBlockKind.work)),
          reason: 'the night shift works into tomorrow, not into this day');
      expect(p.sleep!.start.hour, greaterThan(8));
    });

    test('every block is in order and nothing runs backwards', () {
      final p = plan(tasks: [
        for (var i = 0; i < 5; i++)
          task('t$i', weight: TaskWeight.light,
              duration: const Duration(minutes: 20)),
      ]);
      for (final b in p.blocks) {
        expect(b.end.isAfter(b.start), isTrue, reason: b.kind.name);
        for (var i = 1; i < b.tasks.length; i++) {
          expect(b.tasks[i].start.isBefore(b.tasks[i - 1].start), isFalse,
              reason: 'tasks in ${b.kind.name} are out of order');
        }
      }
    });

    test('no two tasks in a block overlap', () {
      final p = plan(tasks: [
        for (var i = 0; i < 8; i++)
          task('t$i', weight: TaskWeight.light,
              duration: const Duration(minutes: 25)),
      ]);
      for (final b in p.blocks) {
        for (var i = 1; i < b.tasks.length; i++) {
          expect(b.tasks[i].start.isBefore(b.tasks[i - 1].end), isFalse,
              reason: '${b.tasks[i].task.id} overlaps '
                  '${b.tasks[i - 1].task.id}');
        }
      }
    });

    test('nothing is ever scheduled inside the sleep window', () {
      final p = plan(tasks: [
        for (var i = 0; i < 12; i++)
          task('t$i', weight: TaskWeight.light,
              duration: const Duration(minutes: 30)),
      ]);
      for (final t in p.allTasks) {
        expect(t.start.isBefore(p.sleep!.start) || t.start.isAfter(p.sleep!.end),
            isTrue,
            reason: '${t.task.id} at ${t.start} is inside the sleep window');
      }
    });
  });

  test('an empty task list still produces a day with its prayers', () {
    final p = plan();
    expect(p.blocks, isNotEmpty);
    expect(p.allTasks, hasLength(5));
    expect(p.deferred, isEmpty);
  });
}
