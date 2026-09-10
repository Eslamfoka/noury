import '../../core/notifications/task_alert.dart';
import '../planner/day_plan.dart';

/// Where one of today's tasks stands.
///
/// Five states, and **none of them is a failure.** A task whose time has
/// passed is «لسه» — the same word Home has always used for a prayer not yet
/// logged — not "missed", not "overdue", and never red. The day is a plan, not
/// a list of things to have failed at.
enum TaskStatus {
  /// The logs show it happened.
  done,

  /// Put off by «فكّرني بعد ٥ دقايق». Its time has moved, and the new one is
  /// shown so the user can see where it went.
  snoozed,

  /// Its time is now, give or take.
  due,

  /// Still ahead.
  upcoming,

  /// Its time has passed and nothing has been logged. **Not a failure** —
  /// there is still a day left, and the wording says so.
  open,
}

/// How wide "now" is.
///
/// A task is *due* for the length of the thing itself rather than for an
/// instant: a thirty-minute walk planned at 16:30 is still the thing to be
/// doing at 16:45. Below a floor of fifteen minutes, because a ten-minute
/// tasbeeh that stopped being "now" after ten minutes would flicker past.
const _minimumDueWindow = Duration(minutes: 15);

/// One task on the day, with everything the screen needs to draw it.
class TaskLine {
  const TaskLine({
    required this.taskId,
    required this.title,
    required this.plannedAt,
    required this.status,
    required this.showAt,
    required this.pillar,
    this.kind,
  });

  final String taskId;
  final String title;

  /// Where the planner put it.
  final DateTime plannedAt;

  /// The time to show — [plannedAt], unless a snooze moved it.
  final DateTime showAt;

  final TaskStatus status;
  final TaskPillar pillar;

  /// Null for a task with no alert of its own.
  final TaskAlertKind? kind;

  bool get isSnoozed => status == TaskStatus.snoozed;
}

/// Today's tasks, with their status.
///
/// Pure: a plan, a clock, what the logs say, and what has been snoozed. No
/// database and no providers, so the screen's whole behaviour is testable by
/// stating four values.
///
/// Prayers are **excluded**. They are anchors in the plan rather than tasks,
/// the adhan announces them on its own channels, and Home already logs them —
/// putting them here would be a fourth place to keep in sync. The user asked
/// for exactly this: "keep prayer/adhan/iqama separate and unchanged".
List<TaskLine> taskLinesFor({
  required DayPlan plan,
  required DateTime now,
  Set<String> done = const {},
  Map<String, DateTime> snoozedUntil = const {},
}) {
  final lines = <TaskLine>[];

  for (final scheduled in plan.allTasks) {
    final id = scheduled.task.id;
    if (id.startsWith('prayer-')) continue;

    final snooze = snoozedUntil[id];
    final showAt = snooze ?? scheduled.start;

    lines.add(TaskLine(
      taskId: id,
      title: scheduled.task.title,
      plannedAt: scheduled.start,
      showAt: showAt,
      pillar: scheduled.task.pillar,
      kind: alertKindForTaskId(id),
      status: _statusFor(
        isDone: done.contains(id),
        snoozedTo: snooze,
        at: scheduled.start,
        duration: scheduled.task.duration,
        now: now,
      ),
    ));
  }

  // In the order the day happens, by the time actually shown — a snoozed task
  // has moved, and a list that still sorted it by its original slot would put
  // it where it is not.
  lines.sort((a, b) => a.showAt.compareTo(b.showAt));
  return lines;
}

TaskStatus _statusFor({
  required bool isDone,
  required DateTime? snoozedTo,
  required DateTime at,
  required Duration duration,
  required DateTime now,
}) {
  // Done outranks everything. A task finished early is finished, whatever its
  // planned time says, and a snooze on something already done is stale.
  if (isDone) return TaskStatus.done;

  if (snoozedTo != null && snoozedTo.isAfter(now)) return TaskStatus.snoozed;

  final window = duration < _minimumDueWindow ? _minimumDueWindow : duration;
  final effectiveAt = snoozedTo ?? at;

  if (now.isBefore(effectiveAt)) return TaskStatus.upcoming;
  if (now.isBefore(effectiveAt.add(window))) return TaskStatus.due;
  return TaskStatus.open;
}

extension TaskStatusLabel on TaskStatus {
  /// What the screen says.
  ///
  /// Nothing here accuses. «لسه» is the word Home has always used for a prayer
  /// not yet logged, and it carries no verdict — the day is not over.
  String get arabicLabel => switch (this) {
        TaskStatus.done => 'تمّت',
        TaskStatus.snoozed => 'مأجّلة',
        TaskStatus.due => 'دلوقتي',
        TaskStatus.upcoming => 'جاية',
        TaskStatus.open => 'لسه',
      };
}
