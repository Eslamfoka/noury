import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/daily_tasks.dart';
import 'package:nouri/features/planner/day_plan.dart';
import 'package:nouri/features/planner/day_planner.dart';
import 'package:nouri/features/planner/shift.dart';
import 'package:nouri/features/tasks/task_status.dart';

/// المهام — where each of today's tasks stands.
///
/// The user's requirement:
///
///   «Clearly show the status: completed, upcoming, currently due,
///    delayed/snoozed, or still not done ... do not use shameful language,
///    red colors, or "failed" states.»
final day = DateTime(2026, 9, 6);

final prayers = DailyPrayerTimes(
  fajr: DateTime(2026, 9, 6, 4, 7),
  sunrise: DateTime(2026, 9, 6, 5, 30),
  dhuhr: DateTime(2026, 9, 6, 11, 46),
  asr: DateTime(2026, 9, 6, 15, 18),
  maghrib: DateTime(2026, 9, 6, 18, 4),
  isha: DateTime(2026, 9, 6, 19, 23),
);

DayPlan planFor(ShiftPattern shift) => planDay(
      date: day,
      shift: shift,
      prayers: prayers,
      tasks: dailyTasksFor(date: day, shift: shift),
    );

void main() {
  final plan = planFor(ShiftPattern.morning);

  TaskLine lineFor(
    String id, {
    required DateTime now,
    Set<String> done = const {},
    Map<String, DateTime> snoozed = const {},
  }) =>
      taskLinesFor(plan: plan, now: now, done: done, snoozedUntil: snoozed)
          .firstWhere((l) => l.taskId == id);

  group('the day it lists', () {
    test('every planned task appears', () {
      final lines = taskLinesFor(plan: plan, now: day);
      final planned = plan.allTasks
          .map((t) => t.task.id)
          .where((id) => !id.startsWith('prayer-'))
          .toSet();
      expect(lines.map((l) => l.taskId).toSet(), planned);
    });

    test('prayers are not in it', () {
      // «keep prayer/adhan/iqama separate and unchanged» — and Home already
      // logs them. A fourth place to keep in sync would be a fourth place to
      // drift.
      final lines = taskLinesFor(plan: plan, now: day);
      expect(lines.where((l) => l.taskId.startsWith('prayer-')), isEmpty);
    });

    test('it is ordered by the time actually shown', () {
      final lines = taskLinesFor(plan: plan, now: day);
      for (var i = 1; i < lines.length; i++) {
        expect(lines[i].showAt.isBefore(lines[i - 1].showAt), isFalse);
      }
    });

    test('each line carries the time the planner gave it', () {
      final walk = lineFor('walk', now: day);
      final planned = plan.allTasks.firstWhere((t) => t.task.id == 'walk');
      expect(walk.plannedAt, planned.start);
    });
  });

  group('the five states', () {
    test('before its time, a task is upcoming', () {
      final walk = lineFor('walk', now: DateTime(2026, 9, 6, 5, 0));
      expect(walk.status, TaskStatus.upcoming);
    });

    test('at its time, it is due', () {
      final planned =
          plan.allTasks.firstWhere((t) => t.task.id == 'walk').start;
      final walk = lineFor('walk', now: planned.add(const Duration(minutes: 1)));
      expect(walk.status, TaskStatus.due);
    });

    test('it stays due for as long as the task lasts, not for an instant', () {
      // A thirty-minute walk planned at 16:30 is still the thing to be doing
      // at 16:45.
      final planned =
          plan.allTasks.firstWhere((t) => t.task.id == 'walk').start;
      final walk =
          lineFor('walk', now: planned.add(const Duration(minutes: 20)));
      expect(walk.status, TaskStatus.due);
    });

    test('a short task still gets a fifteen-minute window', () {
      // A ten-minute tasbeeh that stopped being "now" after ten minutes would
      // flicker past before it could be read.
      final planned =
          plan.allTasks.firstWhere((t) => t.task.id == 'tasbeeh').start;
      final tasbeeh =
          lineFor('tasbeeh', now: planned.add(const Duration(minutes: 12)));
      expect(tasbeeh.status, TaskStatus.due);
    });

    test('after its window, it is open — never missed, never failed', () {
      final planned =
          plan.allTasks.firstWhere((t) => t.task.id == 'walk').start;
      final walk = lineFor('walk', now: planned.add(const Duration(hours: 3)));
      expect(walk.status, TaskStatus.open);
    });

    test('the logs saying it happened outrank everything', () {
      final planned =
          plan.allTasks.firstWhere((t) => t.task.id == 'walk').start;
      // Long past its window, but done.
      final walk = lineFor('walk',
          now: planned.add(const Duration(hours: 5)), done: {'walk'});
      expect(walk.status, TaskStatus.done);
    });

    test('done early is still done', () {
      final walk = lineFor('walk',
          now: DateTime(2026, 9, 6, 6, 0), done: {'walk'});
      expect(walk.status, TaskStatus.done);
    });
  });

  group('snoozing', () {
    test('a snoozed task shows its new time, not its old one', () {
      // «When I tap Snooze 5 minutes, update the task's displayed time so I
      // can see the new time.»
      final to = DateTime(2026, 9, 6, 17, 5);
      final walk = lineFor('walk',
          now: DateTime(2026, 9, 6, 17, 0), snoozed: {'walk': to});

      expect(walk.status, TaskStatus.snoozed);
      expect(walk.showAt, to);
      expect(walk.plannedAt, isNot(to),
          reason: 'the planned time is still remembered');
    });

    test('a snooze that has already come round is no longer a snooze', () {
      final to = DateTime(2026, 9, 6, 17, 5);
      final walk = lineFor('walk',
          now: DateTime(2026, 9, 6, 17, 6), snoozed: {'walk': to});
      expect(walk.status, isNot(TaskStatus.snoozed));
    });

    test('a snooze re-times the due window from the new time', () {
      final to = DateTime(2026, 9, 6, 17, 5);
      final walk = lineFor('walk',
          now: DateTime(2026, 9, 6, 17, 10), snoozed: {'walk': to});
      expect(walk.status, TaskStatus.due);
    });

    test('a snooze on something already done is ignored', () {
      final walk = lineFor('walk',
          now: DateTime(2026, 9, 6, 17, 0),
          done: {'walk'},
          snoozed: {'walk': DateTime(2026, 9, 6, 17, 5)});
      expect(walk.status, TaskStatus.done);
    });

    test('a snoozed task sorts to where it now is, not where it was', () {
      final lines = taskLinesFor(
        plan: plan,
        now: DateTime(2026, 9, 6, 5, 0),
        snoozedUntil: {'morning-athkar': DateTime(2026, 9, 6, 23, 0)},
      );
      expect(lines.last.taskId, 'morning-athkar');
    });
  });

  group('the words it uses', () {
    test('nothing accuses, and nothing has failed', () {
      for (final s in TaskStatus.values) {
        final label = s.arabicLabel;
        expect(label.trim(), isNotEmpty, reason: s.name);
        for (final w in ['فاتتك', 'ضيعت', 'فشل', 'كسلان', 'متأخر', 'مقصر']) {
          expect(label.contains(w), isFalse, reason: '${s.name}: $w');
        }
      }
    });

    test('a task whose time has passed is «لسه», the word Home already uses',
        () {
      expect(TaskStatus.open.arabicLabel, 'لسه');
    });

    test('every state says something different', () {
      final labels = TaskStatus.values.map((s) => s.arabicLabel).toSet();
      expect(labels.length, TaskStatus.values.length);
    });
  });

  test('every shift produces a listable day', () {
    for (final shift in [
      ShiftPattern.morning,
      ShiftPattern.evening,
      ShiftPattern.night,
      ShiftPattern.dayOff,
    ]) {
      expect(taskLinesFor(plan: planFor(shift), now: day), isNotEmpty,
          reason: shift.type.name);
    }
  });
}
