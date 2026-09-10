import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/task_alarm_plan.dart';
import 'package:nouri/core/notifications/task_alert.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/daily_tasks.dart';
import 'package:nouri/features/planner/day_plan.dart';
import 'package:nouri/features/planner/day_planner.dart';
import 'package:nouri/features/planner/shift.dart';

/// The user's requirement:
///
///   «i want the tasks have correct time and there is notification reminder
///    as prayer — for example tasbih time according to the plan for my time
///    according to duty, it will be 1 pm; when time 1 pm send me notification»
///
/// So the alert's time is not a clock constant. It is whatever `planDay`
/// decided for that task on that shift, which is what makes it follow the
/// duty pattern.
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
  test('an alert lands at the time the plan gave its task', () {
    final plan = planFor(ShiftPattern.morning);
    final tasbeeh = plan.allTasks.firstWhere((t) => t.task.id == 'tasbeeh');
    final alert =
        taskAlertsFor(plan).firstWhere((a) => a.taskId == 'tasbeeh');

    expect(alert.when, tasbeeh.start,
        reason: 'the alarm is the plan speaking, not a clock constant');
  });

  test('the same task moves when the shift moves it', () {
    // The whole point of «according to my duty». A morning shift and an
    // evening shift put تسبيح in different places, and the alarm follows.
    final morning = taskAlertsFor(planFor(ShiftPattern.morning))
        .firstWhere((a) => a.taskId == 'tasbeeh');
    final evening = taskAlertsFor(planFor(ShiftPattern.evening))
        .firstWhere((a) => a.taskId == 'tasbeeh');

    expect(morning.when, isNot(evening.when));
  });

  test('every placed task that has a sound gets exactly one alert', () {
    final plan = planFor(ShiftPattern.morning);
    final alerts = taskAlertsFor(plan);

    for (final t in plan.allTasks) {
      if (t.task.id.startsWith('prayer-')) continue;
      if (alertKindForTaskId(t.task.id) == null) continue;
      expect(alerts.where((a) => a.taskId == t.task.id).length, 1,
          reason: t.task.id);
    }
  });

  test('prayers are not doubled — the adhan already announces them', () {
    // Two notifications for one prayer, seconds apart, with different sounds,
    // would be worse than none.
    final alerts = taskAlertsFor(planFor(ShiftPattern.morning));
    expect(alerts.where((a) => a.taskId.startsWith('prayer-')), isEmpty);
  });

  test('a deferred task is never rung about', () {
    // If the plan has already said something does not fit today, Nouri does
    // not then ring to demand it.
    final plan = planFor(ShiftPattern.night);
    final deferred = plan.deferred.map((d) => d.task.id).toSet();
    for (final a in taskAlertsFor(plan)) {
      expect(deferred, isNot(contains(a.taskId)), reason: a.taskId);
    }
  });

  test('alerts come out in the order the day happens', () {
    final alerts = taskAlertsFor(planFor(ShiftPattern.morning));
    for (var i = 1; i < alerts.length; i++) {
      expect(alerts[i].when.isBefore(alerts[i - 1].when), isFalse);
    }
  });

  test('two alerts that sound alike are the same kind of thing', () {
    // Not "every alert in a day is unique" — أول وجبة and آخر وجبة both mean
    // "eat", and giving them different tones would teach the user a
    // distinction that does not exist. The property that matters is that a
    // sound never means two *different* things.
    final alerts = taskAlertsFor(planFor(ShiftPattern.morning));
    final kindBySound = <String, TaskAlertKind>{};
    for (final a in alerts) {
      final seen = kindBySound[a.kind.sound];
      if (seen != null) {
        expect(seen, a.kind,
            reason: '${a.kind.sound} would mean two different things');
      }
      kindBySound[a.kind.sound] = a.kind;
    }
    expect(kindBySound, isNotEmpty);
  });

  test('both meals share one sound — they are the same instruction', () {
    final alerts = taskAlertsFor(planFor(ShiftPattern.morning));
    final meals = alerts.where((a) => a.taskId.endsWith('-meal')).toList();
    expect(meals.length, 2);
    expect(meals.first.kind, meals.last.kind);
  });

  test('the meal is asked about half an hour after it is due', () {
    final alerts = taskAlertsFor(planFor(ShiftPattern.morning));
    final meal = alerts.firstWhere((a) => a.taskId == 'first-meal');
    expect(meal.askAt, meal.when.add(const Duration(minutes: 30)));
  });

  test('a kind with no follow-up has no ask time', () {
    final alerts = taskAlertsFor(planFor(ShiftPattern.morning));
    final phone = alerts.firstWhere((a) => a.taskId == 'phone-time');
    expect(phone.askAt, isNull);
  });

  test('every shift produces a day that can be announced', () {
    for (final shift in [
      ShiftPattern.morning,
      ShiftPattern.evening,
      ShiftPattern.night,
      ShiftPattern.dayOff,
    ]) {
      expect(taskAlertsFor(planFor(shift)), isNotEmpty,
          reason: shift.type.name);
    }
  });
}
