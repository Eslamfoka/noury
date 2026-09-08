import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../core/time/date_formats.dart';
import '../home/home_providers.dart';
import '../shared/nouri_avatar.dart';
import 'tasks_providers.dart';
import 'task_status.dart';

/// المهام — the whole of today, in one list.
///
/// Home shows the day as four expandable blocks, which answers "what shape is
/// my day". This answers a different question: **"what is left, and where does
/// each thing stand"** — every task, its time, and whether it has happened,
/// is happening, has been put off, or is still open.
///
/// Three things it deliberately does not do.
///
/// **It does not carry prayers.** They are anchors rather than tasks, the
/// adhan announces them on its own channels, and Home already logs them.
/// Putting them here would be a fourth place to keep in sync.
///
/// **It does not mark anything done.** Every status is *derived* from the log
/// the user already keeps — a walk session, a meal row, the athkar
/// `completedAt`. Tapping a task opens the screen where it is actually done,
/// so there is still exactly one place the truth lives.
///
/// **Nothing here is red, and nothing has failed.** A task whose time has
/// passed reads «لسه» — the word Home has always used for a prayer not yet
/// logged. There is still a day left.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(todayTaskLinesProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('المهام', style: cairo(size: 17, weight: FontWeight.w700)),
            const NouriAvatar(size: 36),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          formatGregorianLong(now),
          style: cairo(size: 11.5, color: NouriColors.muted),
        ),
        const SizedBox(height: 18),
        ...lines.when(
          // Deliberately not a spinner. The list is assembled from the plan,
          // the logs and a small file — it resolves in a frame or two, and a
          // spinner for that flashes. It also animates forever, which makes
          // `pumpAndSettle` time out and took every shell test down with it.
          loading: () => [
            Text(
              'بجمع مهام النهاردة…',
              style: cairo(size: 12.5, color: NouriColors.muted),
            ),
          ],
          error: (_, _) => [
            Text(
              'مش قادر أقرا خطة النهاردة دلوقتي.',
              style: cairo(size: 13, color: NouriColors.muted),
            ),
          ],
          data: (data) => _body(context, data),
        ),
      ],
    );
  }

  List<Widget> _body(BuildContext context, List<TaskLine> lines) {
    if (lines.isEmpty) {
      return [
        Text(
          'مفيش مهام في خطة النهاردة.',
          style: cairo(size: 13, color: NouriColors.muted, height: 1.8),
        ),
      ];
    }

    final done = lines.where((l) => l.status == TaskStatus.done).length;

    return [
      _Summary(done: done, total: lines.length),
      const SizedBox(height: 16),
      for (final line in lines) ...[
        _TaskCard(line: line),
        const SizedBox(height: 8),
      ],
    ];
  }
}

/// «٣ من ٩ خلصوا» — a count, not a score.
class _Summary extends StatelessWidget {
  const _Summary({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: NouriColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        // Flexible rather than a Spacer between fixed texts: at 360dp the
        // three of them overflowed the row by 33 pixels, which draws the
        // yellow-and-black stripe on a real screen. Caught by a widget test.
        child: Row(
          children: [
            Text(
              // «من», never a slash: «٣ / ٩» lays out right to left and says
              // nine of three. Held app-wide by counter_form_test.
              toArabicDigits('$done من $total'),
              key: const ValueKey('tasks-summary-count'),
              style: cairo(size: 15, weight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'خلصوا النهاردة',
                overflow: TextOverflow.ellipsis,
                style: cairo(size: 12, color: NouriColors.muted),
              ),
            ),
            if (done < total)
              Flexible(
                child: Text(
                  'لسه فيه وقت',
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: cairo(size: 11.5, color: NouriColors.muted),
                ),
              ),
          ],
        ),
      );
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.line});

  final TaskLine line;

  /// The colour a status wears.
  ///
  /// **Never red, in any state.** `palette_test` fails the build on one, and
  /// the reason it exists is that a day with a red row on it reads as a day
  /// gone wrong. Gold means "now", green means done, muted means everything
  /// else — including a task whose time has passed.
  Color get _accent => switch (line.status) {
        TaskStatus.done => NouriColors.success,
        TaskStatus.due => NouriColors.gold,
        TaskStatus.snoozed => NouriColors.gold,
        TaskStatus.upcoming => NouriColors.muted,
        TaskStatus.open => NouriColors.muted,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = line.status == TaskStatus.done;

    return GestureDetector(
      key: ValueKey('task-card-${line.taskId}'),
      behavior: HitTestBehavior.opaque,
      // Opens the screen where the task is actually done. المهام stays the
      // overview; it is never the place the log is written.
      onTap: () => openTaskScreen(context, ref, line.taskId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: line.status == TaskStatus.due
              ? NouriColors.surfaceActive
              : NouriColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: line.status == TaskStatus.due
              ? Border.all(color: NouriColors.gold)
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatClock(line.showAt),
                    key: ValueKey('task-time-${line.taskId}'),
                    style: cairo(
                      size: 12,
                      weight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                  // A snoozed task shows where it came from, so the day still
                  // reads as the day that was planned.
                  if (line.isSnoozed)
                    Text(
                      toArabicDigits('كان ${formatClock(line.plannedAt)}'),
                      key: ValueKey('task-was-${line.taskId}'),
                      style: cairo(size: 9, color: NouriColors.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isDone) ...[
              Icon(Icons.check,
                  key: ValueKey('task-done-${line.taskId}'),
                  size: 15,
                  color: NouriColors.success),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                line.title,
                style: cairo(
                  size: 13,
                  color: isDone ? NouriColors.muted : NouriColors.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(status: line.status, accent: _accent),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.accent});

  final TaskStatus status;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('task-status-${status.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
        ),
        child: Text(
          status.arabicLabel,
          style: cairo(size: 10.5, color: accent),
        ),
      );
}
