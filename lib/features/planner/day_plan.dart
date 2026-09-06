import 'shift.dart';

/// The four big sections the brief asks Home to show by default.
///
/// Big blocks, not a task list: the brief is explicit that a long checklist
/// recreates the exact overwhelm the app exists to remove. Hour-by-hour detail
/// appears only when a block is tapped.
enum DayBlockKind { morning, work, afterWork, evening }

extension DayBlockKindLabel on DayBlockKind {
  String get arabicLabel => switch (this) {
        DayBlockKind.morning => 'الصباح',
        DayBlockKind.work => 'الدوام',
        DayBlockKind.afterWork => 'بعد الدوام',
        DayBlockKind.evening => 'المسا',
      };
}

/// How much a task costs the user, which decides where it can go.
///
/// The brief's rule: heavy tasks need focus and a place, so they belong at
/// home in real free time. Light tasks can ride along with something else —
/// the commute, a break at work.
enum TaskWeight { heavy, light }

extension TaskWeightLabel on TaskWeight {
  String get arabicLabel => switch (this) {
        TaskWeight.heavy => 'ثقيل',
        TaskWeight.light => 'خفيف',
      };
}

/// Which pillar a task serves. Reuses the same vocabulary as the daily tip so
/// the whole app speaks about the pillars the same way.
enum TaskPillar { deen, body, mind, wealth }

extension TaskPillarLabel on TaskPillar {
  String get arabicLabel => switch (this) {
        TaskPillar.deen => 'ديني',
        TaskPillar.body => 'بدني',
        TaskPillar.mind => 'تطوير',
        TaskPillar.wealth => 'مالي',
      };
}

/// What a task is pinned to.
///
/// Two kinds, because the brief describes both: "walk 10 min at 10:00" is a
/// clock anchor, "athkar after maghrib" is a prayer anchor that moves with the
/// season.
sealed class TaskAnchor {
  const TaskAnchor();
}

/// Fixed to a wall-clock time.
class ClockAnchor extends TaskAnchor {
  const ClockAnchor(this.at);
  final Clock at;
}

/// Fixed relative to a prayer, so it follows the sun through the year.
class PrayerAnchor extends TaskAnchor {
  const PrayerAnchor(this.prayer, {this.offset = Duration.zero});

  /// fajr | dhuhr | asr | maghrib | isha
  final String prayer;

  /// Negative for "before", positive for "after".
  final Duration offset;
}

/// Nouri decides where this goes, within the block.
class FlexibleAnchor extends TaskAnchor {
  const FlexibleAnchor({this.preferredBlock});
  final DayBlockKind? preferredBlock;
}

/// One thing to do, before it has been given a time.
class PlannedTask {
  const PlannedTask({
    required this.id,
    required this.title,
    required this.pillar,
    required this.weight,
    required this.duration,
    required this.anchor,
  });

  final String id;
  final String title;
  final TaskPillar pillar;
  final TaskWeight weight;
  final Duration duration;
  final TaskAnchor anchor;

  /// Light tasks can share time with a commute or a break; heavy ones cannot.
  bool get canRideAlong => weight == TaskWeight.light;
}

/// A task once the planner has given it a slot.
class ScheduledTask {
  const ScheduledTask({
    required this.task,
    required this.start,
    required this.block,
  });

  final PlannedTask task;
  final DateTime start;
  final DayBlockKind block;

  DateTime get end => start.add(task.duration);
}

/// One of the four sections of a planned day.
class DayBlock {
  const DayBlock({
    required this.kind,
    required this.start,
    required this.end,
    required this.tasks,
  });

  final DayBlockKind kind;
  final DateTime start;
  final DateTime end;
  final List<ScheduledTask> tasks;

  Duration get length => end.difference(start);
  bool get isEmpty => tasks.isEmpty;
}

/// A whole planned day.
///
/// SCAFFOLDING: nothing builds one of these yet. The algorithm that turns a
/// shift plus a task list into blocks is the open design question, and it is
/// deliberately absent rather than guessed at.
class DayPlan {
  const DayPlan({
    required this.date,
    required this.shift,
    required this.blocks,
  });

  final DateTime date;
  final ShiftPattern shift;
  final List<DayBlock> blocks;

  Iterable<ScheduledTask> get allTasks => blocks.expand((b) => b.tasks);

  DayBlock? blockFor(DayBlockKind kind) {
    for (final b in blocks) {
      if (b.kind == kind) return b;
    }
    return null;
  }
}
