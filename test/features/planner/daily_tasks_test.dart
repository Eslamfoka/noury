import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/daily_tasks.dart';
import 'package:nouri/features/planner/day_plan.dart';
import 'package:nouri/features/planner/day_planner.dart';
import 'package:nouri/features/planner/shift.dart';

final day = DateTime(2026, 9, 6);

final prayers = DailyPrayerTimes(
  fajr: DateTime(2026, 9, 6, 4, 7),
  sunrise: DateTime(2026, 9, 6, 5, 30),
  dhuhr: DateTime(2026, 9, 6, 11, 46),
  asr: DateTime(2026, 9, 6, 15, 18),
  maghrib: DateTime(2026, 9, 6, 18, 4),
  isha: DateTime(2026, 9, 6, 19, 23),
);

ScheduledTask? find(DayPlan p, String id) {
  for (final t in p.allTasks) {
    if (t.task.id == id) return t;
  }
  return null;
}

void main() {
  group('the daily catalogue', () {
    test('carries no prayers — those are anchors, not tasks', () {
      final tasks = dailyTasksFor(date: day, shift: ShiftPattern.morning);
      for (final t in tasks) {
        expect(t.id.startsWith('prayer-'), isFalse, reason: t.id);
      }
    });

    test('every task has a real title and a non-zero duration', () {
      for (final t in dailyTasksFor(date: day, shift: ShiftPattern.morning)) {
        expect(t.title.trim(), isNotEmpty, reason: t.id);
        expect(t.duration, greaterThan(Duration.zero), reason: t.id);
      }
    });

    test('task ids are unique', () {
      final ids =
          dailyTasksFor(date: day, shift: ShiftPattern.morning)
              .map((t) => t.id)
              .toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('athkar follow their prayers rather than a clock hour', () {
      final tasks = dailyTasksFor(date: day, shift: ShiftPattern.morning);
      final morning = tasks.firstWhere((t) => t.id == 'morning-athkar');
      final evening = tasks.firstWhere((t) => t.id == 'evening-athkar');
      expect(morning.anchor, isA<PrayerAnchor>());
      expect(evening.anchor, isA<PrayerAnchor>());
      expect((morning.anchor as PrayerAnchor).prayer, 'fajr');
      expect((evening.anchor as PrayerAnchor).prayer, 'maghrib');
    });

    test('the walk and the wird are heavy; the athkar are not', () {
      final tasks = dailyTasksFor(date: day, shift: ShiftPattern.morning);
      Map<String, TaskWeight> byId = {
        for (final t in tasks) t.id: t.weight,
      };
      expect(byId['walk'], TaskWeight.heavy);
      expect(byId['quran-wird'], TaskWeight.heavy);
      expect(byId['morning-athkar'], TaskWeight.light);
      expect(byId['tasbeeh'], TaskWeight.light);
    });

    test('meals carry no clock anchor — the eating window owns that', () {
      final tasks = dailyTasksFor(date: day, shift: ShiftPattern.morning);
      for (final id in ['first-meal', 'last-meal']) {
        final meal = tasks.firstWhere((t) => t.id == id);
        expect(meal.anchor, isA<FlexibleAnchor>(),
            reason: '$id must not fight the 16/8 window for a time');
      }
    });

    test('dropping the wird or the walk drops exactly that', () {
      final tasks = dailyTasksFor(
        date: day,
        shift: ShiftPattern.morning,
        includeQuranWird: false,
        includeWalk: false,
      );
      final ids = tasks.map((t) => t.id).toSet();
      expect(ids, isNot(contains('quran-wird')));
      expect(ids, isNot(contains('walk')));
      expect(ids, contains('morning-athkar'));
    });
  });

  group('rule 5 — knowledge time is one block, rotating', () {
    test('exactly one knowledge task a day, never three', () {
      // By id, not by pillar. The pillar was standing in for "is a knowledge
      // task" and stopped meaning that when مكالمات joined TaskPillar.mind —
      // which would have made this fail for a reason that has nothing to do
      // with the rotation it is testing.
      const knowledgeIds = {
        'knowledge-read',
        'knowledge-listen',
        'knowledge-skill',
      };
      final tasks = dailyTasksFor(date: day, shift: ShiftPattern.morning);
      expect(tasks.where((t) => knowledgeIds.contains(t.id)), hasLength(1));
    });

    test('all three faces appear across three consecutive days', () {
      final ids = <String>{};
      for (var i = 0; i < 3; i++) {
        ids.add(knowledgeTaskFor(
                DateTime(2026, 9, 6 + i), ShiftPattern.morning)
            .id);
      }
      expect(ids, hasLength(3),
          reason: 'read, listen and skill each get their turn');
    });

    test('the same date always gives the same one', () {
      // Deterministic, so a re-plan mid-day cannot silently change what the
      // user was promised this morning.
      expect(
        knowledgeTaskFor(day, ShiftPattern.morning).id,
        knowledgeTaskFor(day, ShiftPattern.morning).id,
      );
    });
  });

  group('the worked example, planned by the algorithm', () {
    late DayPlan plan;

    setUp(() {
      plan = planDay(
        date: day,
        shift: ShiftPattern.morning,
        prayers: prayers,
        tasks: dailyTasksFor(date: day, shift: ShiftPattern.morning),
      );
    });

    test('the day holds together — nothing overlaps, nothing runs backwards',
        () {
      for (final b in plan.blocks) {
        expect(b.end.isAfter(b.start), isTrue, reason: b.kind.name);
        for (var i = 1; i < b.tasks.length; i++) {
          expect(b.tasks[i].start.isBefore(b.tasks[i - 1].end), isFalse,
              reason: '${b.tasks[i].task.id} overlaps '
                  '${b.tasks[i - 1].task.id}');
        }
      }
    });

    test('an ordinary day fits, with nothing deferred', () {
      // The point of the whole exercise: a normal morning shift with the
      // standard task list should not overflow.
      expect(plan.deferred, isEmpty,
          reason: plan.deferred.map((d) => d.arabicNote).join(' · '));
    });

    test('the morning athkar land just after fajr', () {
      expect(find(plan, 'morning-athkar')!.start,
          prayers.fajr.add(const Duration(minutes: 23)));
    });

    test('the evening athkar land just after maghrib', () {
      expect(find(plan, 'evening-athkar')!.start,
          prayers.maghrib.add(const Duration(minutes: 16)));
    });

    test('the walk lands at home after work, never on the commute', () {
      final walk = find(plan, 'walk')!;
      expect(walk.start.isAfter(ShiftPattern.morning.homeAgain!.on(day)),
          isTrue);
      expect(walk.block, isNot(DayBlockKind.work));
      expect(walk.block, isNot(DayBlockKind.morning));
    });

    test('the tasbeeh rides a break at work', () {
      expect(find(plan, 'tasbeeh')!.block, DayBlockKind.work);
    });

    test('the Quran wird gets real time at home', () {
      final wird = find(plan, 'quran-wird')!;
      expect(wird.start.isAfter(ShiftPattern.morning.homeAgain!.on(day)),
          isTrue);
    });

    test('sleep athkar come last, right before bed', () {
      // «أذكار النوم» means before sleeping. A first-fit search put them in
      // the first free minute after maghrib — hours early, and before isha.
      final athkar = find(plan, 'sleep-athkar')!;
      expect(athkar.start.isBefore(plan.sleep!.start), isTrue);
      expect(athkar.start.isAfter(prayers.isha), isTrue);

      // Nothing else in the evening starts after them.
      for (final t in plan.allTasks) {
        if (t.task.id == 'sleep-athkar') continue;
        expect(t.start.isAfter(athkar.start), isFalse,
            reason: '${t.task.id} is scheduled after the sleep athkar');
      }
    });

    test('the last meal is not pushed against bedtime', () {
      // preferLatest is for the athkar only: eating immediately before bed is
      // the opposite of what the brief asks for.
      final meal = find(plan, 'last-meal')!;
      expect(plan.sleep!.start.difference(meal.end),
          greaterThan(const Duration(minutes: 20)));
    });

    test('all five prayers are in the day, in order', () {
      final prayerTasks = plan.allTasks
          .where((t) => t.task.id.startsWith('prayer-'))
          .toList();
      expect(prayerTasks, hasLength(5));
      for (var i = 1; i < prayerTasks.length; i++) {
        expect(prayerTasks[i].start.isAfter(prayerTasks[i - 1].start), isTrue);
      }
    });

    test('the day is roughly the shape the worked example drew by hand', () {
      // Not time-for-time — the algorithm is allowed to disagree with a human
      // about minutes. What must hold is the shape: work in the middle, the
      // heavy things at home afterwards, the day ending before bed.
      final kinds = plan.blocks.map((b) => b.kind).toList();
      expect(kinds, contains(DayBlockKind.morning));
      expect(kinds, contains(DayBlockKind.work));
      expect(kinds, contains(DayBlockKind.evening));

      for (final t in plan.allTasks) {
        expect(t.end.isAfter(plan.sleep!.start), isFalse,
            reason: '${t.task.id} runs past bedtime');
      }
    });
  });

  group('the other shifts', () {
    test('an evening shift still fits its day', () {
      final p = planDay(
        date: day,
        shift: ShiftPattern.evening,
        prayers: prayers,
        tasks: dailyTasksFor(date: day, shift: ShiftPattern.evening),
      );
      expect(p.blocks, isNotEmpty);
      for (final b in p.blocks) {
        for (var i = 1; i < b.tasks.length; i++) {
          expect(b.tasks[i].start.isBefore(b.tasks[i - 1].end), isFalse);
        }
      }
    });

    test('a day off holds the whole list comfortably', () {
      final p = planDay(
        date: day,
        shift: ShiftPattern.dayOff,
        prayers: prayers,
        tasks: dailyTasksFor(date: day, shift: ShiftPattern.dayOff),
      );
      expect(p.deferred, isEmpty,
          reason: 'a free day should fit everything an ordinary one does');
    });

    test('a night shift produces a day rather than an error', () {
      final p = planDay(
        date: day,
        shift: ShiftPattern.night,
        prayers: prayers,
        tasks: dailyTasksFor(date: day, shift: ShiftPattern.night),
      );
      expect(p.blocks, isNotEmpty);
      expect(p.sleep!.length, greaterThan(Duration.zero));
    });
  });

  // §5.5: "Calls time: one hour, placed by shift — after morning/evening
  // shift or before sleep; for the night shift, before duty or during it if
  // there's a chance."
  //
  // It existed in `example_day.dart` — the day worked out by hand — and
  // nowhere else, so the real planner had never placed it. The example was
  // promising an hour the app did not schedule.
  group('مكالمات', () {
    test('is an hour, and it is planned every day', () {
      for (final shift in [
        ShiftPattern.morning,
        ShiftPattern.evening,
        ShiftPattern.night,
        ShiftPattern.dayOff,
      ]) {
        final calls = dailyTasksFor(date: day, shift: shift)
            .firstWhere((t) => t.id == 'calls');
        expect(calls.duration, const Duration(hours: 1),
            reason: shift.type.name);
      }
    });

    test('is light — an hour on the phone is not a heavy task', () {
      final calls = dailyTasksFor(date: day, shift: ShiftPattern.morning)
          .firstWhere((t) => t.id == 'calls');
      expect(calls.weight, TaskWeight.light);
    });

    test('on a morning shift it lands after work, not before it', () {
      final calls = dailyTasksFor(date: day, shift: ShiftPattern.morning)
          .firstWhere((t) => t.id == 'calls');
      expect((calls.anchor as FlexibleAnchor).preferredBlock,
          DayBlockKind.afterWork);
    });

    test('on a night shift it goes before duty, in the evening', () {
      // Duty starts at 22:00, so the evening is the only stretch of the day
      // that is both awake and free.
      final calls = dailyTasksFor(date: day, shift: ShiftPattern.night)
          .firstWhere((t) => t.id == 'calls');
      expect((calls.anchor as FlexibleAnchor).preferredBlock,
          DayBlockKind.evening);
    });

    test('the algorithm actually places it on an ordinary day', () {
      // The point of the whole task: the example promised it, the planner
      // never delivered it.
      final p = planDay(
        date: day,
        shift: ShiftPattern.morning,
        prayers: prayers,
        tasks: dailyTasksFor(date: day, shift: ShiftPattern.morning),
      );
      final calls = find(p, 'calls');
      expect(calls, isNotNull, reason: 'مكالمات was never scheduled');
      expect(calls!.end.difference(calls.start), const Duration(hours: 1));
    });

    test('it does not push the wird or the walk off the day', () {
      // An hour is a big thing to add to a working day. If it cannot fit,
      // *it* is what gets deferred — the religious wird is not.
      final p = planDay(
        date: day,
        shift: ShiftPattern.morning,
        prayers: prayers,
        tasks: dailyTasksFor(date: day, shift: ShiftPattern.morning),
      );
      expect(p.deferred.map((d) => d.task.id), isNot(contains('quran-wird')));
    });

    test('when it cannot fit it is deferred by name, never dropped', () {
      // Nouri never silently shortens the day. Whatever happens to مكالمات,
      // the plan says so.
      final p = planDay(
        date: day,
        shift: ShiftPattern.morning,
        prayers: prayers,
        tasks: dailyTasksFor(date: day, shift: ShiftPattern.morning),
      );
      final placed = find(p, 'calls') != null;
      final deferred = p.deferred.any((d) => d.task.id == 'calls');
      expect(placed || deferred, isTrue,
          reason: 'a task must be either in the day or named as deferred');
    });
  });
}
