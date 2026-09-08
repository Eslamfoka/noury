import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/notifications/task_alarm_ids.dart';

/// Silences today's alarm and question for a task the user has just done.
///
/// The same shape prayer logging already uses, and for the same reason: the
/// alarm and its «عملتها؟» were armed hours in advance and have no way to
/// learn they have been answered. Logging a meal at 18:05 would otherwise
/// still be asked «كلت؟» at 18:30.
///
/// The re-arm on the next launch would notice too — `completedTaskIdsFor`
/// derives it from the same log — but the next launch may be hours away, and
/// the question fires in thirty minutes. This is the responsive half of the
/// same fact.
///
/// **Everything is read off `ref` before the first await.** A WidgetRef
/// belongs to a widget, and after an await that widget may be gone, at which
/// point reading it throws. This is the bug `0690711` had to fix in
/// `logPrayer`, reached through a different door.
///
/// **Best-effort.** If the cancel fails, the log is still correct and the
/// worst case is one redundant question, so it must never take a write down
/// with it.
Future<void> silenceTaskAlarms(
  WidgetRef ref,
  List<String> taskIds, {
  DateTime? on,
}) async {
  final service = ref.read(notificationServiceProvider);
  if (service == null) return;

  final date = on ?? DateTime.now();

  for (final taskId in taskIds) {
    for (final ask in [false, true]) {
      final id = taskAlarmId(date, taskId, ask: ask);
      if (id == null) continue;
      try {
        await service.cancel(id);
      } catch (_) {
        // The platform channel went away, or the widget did. Either way the
        // row is written and the next re-arm will work it out.
      }
    }
  }
}

/// The three faces of knowledge time, which the planner treats as one block —
/// so logging any of them answers all three.
const knowledgeTaskIds = <String>[
  'knowledge-read',
  'knowledge-listen',
  'knowledge-skill',
];
