import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../body/log_meal_sheet.dart';
import '../home/home_providers.dart';
import '../shell/app_shell.dart';
import '../steps/walk_screen.dart';
import '../workouts/workout_screen.dart';
import 'snooze_store.dart';
import 'task_status.dart';

/// What has been put off, and until when.
///
/// Read from the file the snooze handler writes — see [SnoozeStore] for why it
/// is a file and not the database. Failing to read it costs a label, never an
/// alarm, so it degrades to "nothing is snoozed" rather than to an error.
final snoozedTasksProvider = FutureProvider<Map<String, DateTime>>((ref) async {
  // Day-scoped: a snooze belongs to the day it was made on, and the store
  // drops yesterday's on read.
  ref.watch(currentDayProvider);

  // **And re-read on the coarse clock.** The file is written by a different
  // isolate — the one Android wakes when «فكّرني بعد ٥ دقايق» is pressed with
  // the app closed — so nothing in this isolate knows it changed. Without
  // this the provider is cached from launch and المهام goes on showing the
  // old time until the app is restarted, which is exactly what happened the
  // first time the round trip was watched on the emulator.
  //
  // It costs one small JSON read every thirty seconds, and only while the
  // list is being looked at.
  ref.watch(coarseClockProvider);

  try {
    final store = await openSnoozeStore();
    return store.read();
  } catch (_) {
    return const {};
  }
});

/// Today's tasks, each with its time and where it stands.
///
/// Assembled from three things the app already has: the plan the shift
/// produced, the completions derived from the logs, and the snooze file. It
/// stores nothing of its own — المهام is a view, not a second record.
final todayTaskLinesProvider = FutureProvider<List<TaskLine>>((ref) async {
  // A plain Provider<AsyncValue<DayPlan>>, so it is watched rather than
  // awaited: it is loading until the settings and the prayer times are.
  final plan = ref.watch(todayPlanProvider).value;
  if (plan == null) return const [];

  final done = await ref.watch(todayCompletedTasksProvider.future);
  final snoozed = await ref.watch(snoozedTasksProvider.future);

  // The coarse clock, not `DateTime.now()`: the list has to re-decide what is
  // «دلوقتي» as the day moves, and it has to turn over at midnight like
  // everything else day-scoped.
  final now = ref.watch(coarseClockProvider).value ?? DateTime.now();

  return taskLinesFor(
    plan: plan,
    now: now,
    done: done,
    snoozedUntil: snoozed,
  );
});

/// Opens the screen where a task is actually done.
///
/// The same mapping the notification tap uses, so a task reached from المهام
/// and a task reached from its alarm land in the same place. المهام is the
/// overview; it is never where the log is written.
Future<void> openTaskScreen(
  BuildContext context,
  WidgetRef ref,
  String taskId,
) async {
  switch (taskId) {
    case 'walk':
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WalkScreen()),
      );
    case 'workout':
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const WorkoutScreen()),
      );
    case 'first-meal' || 'last-meal':
      await showLogMealSheet(context, ref);
    default:
      // Everything else is logged on a card that already lives on another tab
      // — the wird and knowledge time on النهاردة, the tasbeeh and the athkar
      // on الأذكار. This used to do nothing at all, which made eight of the
      // eleven rows a dead tap.
      ref.read(requestedTabProvider.notifier).request(tabForTaskId(taskId));
  }
}
