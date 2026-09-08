import '../../features/planner/day_plan.dart';
import 'task_alert.dart';

/// One alarm Nouri will raise for a planned task.
class PlannedAlert {
  const PlannedAlert({
    required this.when,
    required this.kind,
    required this.taskId,
  });

  /// The task's own start time, as `planDay` decided it.
  final DateTime when;

  final TaskAlertKind kind;

  /// The `dailyTasksFor` id, carried so the tap can open the right screen and
  /// so the follow-up can be cancelled when the task is marked done.
  final String taskId;

  /// When to ask whether it happened, or null for the kinds that are not
  /// asked about.
  DateTime? get askAt {
    final after = kind.followUpAfter;
    return after == null ? null : when.add(after);
  }

  @override
  String toString() => 'PlannedAlert($taskId, ${kind.name}, $when)';
}

/// The alerts a planned day should raise.
///
/// Pure, like `planDay` itself: a plan in, a list out. No database, no clock,
/// no providers — so a day's alarms are entirely a function of its plan, and
/// the tests can state real times rather than mocking a world.
///
/// Two things are deliberately left out.
///
/// **Prayers.** `planDay` puts them in the day as anchors, but the adhan has
/// announced them since Slice 1 and on its own channel. Alerting them again
/// here would be two notifications for one prayer, seconds apart, with
/// different sounds.
///
/// **Deferred tasks.** If the plan has already said something does not fit
/// today, Nouri does not then ring to demand it. The plan says so on Home
/// instead, which is the honest place for it.
List<PlannedAlert> taskAlertsFor(DayPlan plan) {
  final alerts = <PlannedAlert>[];
  final deferred = plan.deferred.map((d) => d.task.id).toSet();

  for (final scheduled in plan.allTasks) {
    final id = scheduled.task.id;

    // The adhan already owns these.
    if (id.startsWith('prayer-')) continue;
    if (deferred.contains(id)) continue;

    final kind = alertKindForTaskId(id);
    if (kind == null) continue;

    alerts.add(PlannedAlert(when: scheduled.start, kind: kind, taskId: id));
  }

  // In the order the day happens, which is the order they will fire and the
  // order a reader of the list expects.
  alerts.sort((a, b) => a.when.compareTo(b.when));
  return alerts;
}
