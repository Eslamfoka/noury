import '../../core/notifications/nag_store.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/task_alarm_ids.dart';
import 'snooze_store.dart';

/// Silences today's alarm and question for a task the user has just done.
///
/// The same shape prayer logging has used since `0690711`, and for the same
/// reason: the alarm and its «عملتها؟» were armed hours in advance and have no
/// way to learn they have been answered. Logging a meal at 18:05 would
/// otherwise still be asked «كلت؟» at 18:30.
///
/// The re-arm on the next launch would notice too — `completedTaskIdsFor`
/// derives it from the same log — but the next launch may be hours away and
/// the question fires in thirty minutes. This is the responsive half of the
/// same fact.
///
/// **Takes the service, not a `WidgetRef`.** It did take a ref, and that was
/// wrong: callers reach this *after* writing their row, by which point one or
/// more awaits have passed, and a `WidgetRef` read after an await throws if
/// the widget has gone. `walk_screen.dart` reached it after two awaits, in the
/// very file whose comment says "every `ref` read happens before the first
/// await". So the read is hoisted to the caller, where it belongs.
///
/// **Call it after the write, never before.** Silencing first and then failing
/// to write would take away the reminder for something Nouri has no record of
/// — the user would be left with neither the log nor the nudge.
///
/// **Best-effort.** A failed cancel costs one redundant question; it must
/// never take a write down with it.
Future<void> silenceTaskAlarms(
  NotificationService? service,
  List<String> taskIds, {
  DateTime? on,
}) async {
  if (service == null) return;

  final date = on ?? DateTime.now();

  for (final taskId in taskIds) {
    for (final ask in [false, true]) {
      final id = taskAlarmId(date, taskId, ask: ask);
      if (id == null) continue;
      try {
        await service.cancel(id);
      } catch (_) {
        // The platform channel went away. The row is written, and the next
        // re-arm works it out from the log.
      }
    }
  }

  // And forget any snooze, so المهام does not show «مأجّلة» beside something
  // that has just been finished. Separate try: the store is a nicety and the
  // cancels above are the part that matters.
  try {
    final store = await openSnoozeStore();
    for (final taskId in taskIds) {
      await store.clear(taskId);
    }
  } catch (_) {
    // A stale label until the next read, which drops it at day's end anyway.
  }

  // And tell the nag, which reads a file rather than the database: without
  // this the next tick — minutes away — would ask «عملتها؟» about a task
  // the log already answers. The re-arm on the next launch writes the same
  // fact from the logs; this is the responsive half.
  try {
    final nags = await openNagStore();
    await nags.markDone(date, taskIds);
  } catch (_) {
    // One extra question, at most.
  }
}

/// The three faces of knowledge time, which the planner treats as one block —
/// so logging any of them answers all three.
const knowledgeTaskIds = <String>[
  'knowledge-read',
  'knowledge-listen',
  'knowledge-skill',
];
