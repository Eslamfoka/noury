import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../core/time/date_formats.dart';
import '../home/home_providers.dart';
import '../prayers/prayer_scoring.dart';
import '../shared/nouri_avatar.dart';
import 'prayers_line.dart';
import 'prayers_sheet.dart';
import 'tasks_providers.dart';
import 'task_status.dart';

/// المهام — the whole of today, in one list.
///
/// Home shows the day as four expandable blocks, which answers "what shape is
/// my day". This answers a different question: **"what is left, and where does
/// each thing stand"** — every task, its time, and whether it has happened,
/// is happening, has been put off, or is still open.
///
/// **The prayers are here as one line**, at the top, since 13 September
/// 2026 — «عايز اخلي الصلاه ككل الخمس فروض في قايمة المهام وتنقسم بنسب في
/// المية». Twenty percent a prayer, one hundred at isha. It used not to carry
/// them at all, on the argument that Home already logs them and a second
/// place would drift; the answer is that the line is *derived* from the same
/// log, and the sheet it opens writes through the same `logPrayer`. See
/// `prayers_line.dart`.
///
/// Two things it deliberately does not do.
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
    final prayers = ref.watch(todayPrayersLineProvider);
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
          data: (data) => _body(context, data, prayers),
        ),
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    List<TaskLine> lines,
    PrayersLine? prayers,
  ) {
    if (lines.isEmpty && prayers == null) {
      return [
        Text(
          'مفيش مهام في خطة النهاردة.',
          style: cairo(size: 13, color: NouriColors.muted, height: 1.8),
        ),
      ];
    }

    // The prayers count as one task among the day's: done at a hundred, and
    // not before. «٣ من ٩» is still a count, not a score.
    final done = lines.where((l) => l.status == TaskStatus.done).length +
        (prayers?.isDone ?? false ? 1 : 0);
    final total = lines.length + (prayers == null ? 0 : 1);

    return [
      _Summary(done: done, total: total),
      const SizedBox(height: 16),
      // First, always. The prayers frame the day the other tasks sit inside,
      // and the line spans from fajr to isha rather than owning one slot.
      if (prayers != null) ...[
        _PrayersCard(line: prayers),
        const SizedBox(height: 8),
      ],
      for (final line in lines) ...[
        _TaskCard(line: line),
        const SizedBox(height: 8),
      ],
    ];
  }
}

/// The five prayers as one card, at twenty percent each.
///
/// Same shape as a task card — time, title, a chip on the end — so it reads
/// as one of the day's tasks and not as a second widget bolted on. Two
/// things are its own: the chip is the percentage rather than a status word,
/// because the percentage *is* what the user asked to see; and under the
/// title sit the five by name, each with a dot that fills when it is prayed,
/// so «٤٠٪» never has to be decoded.
///
/// The status still decides the colour — gold while the current prayer is
/// unlogged, green at a hundred, muted otherwise — and nothing is ever red.
class _PrayersCard extends StatelessWidget {
  const _PrayersCard({required this.line});

  final PrayersLine line;

  Color get _accent => switch (line.status) {
        TaskStatus.done => NouriColors.success,
        TaskStatus.due => NouriColors.gold,
        TaskStatus.snoozed => NouriColors.gold,
        TaskStatus.upcoming => NouriColors.muted,
        TaskStatus.open => NouriColors.muted,
      };

  @override
  Widget build(BuildContext context) {
    final isDue = line.status == TaskStatus.due;

    return GestureDetector(
      key: const ValueKey('task-card-${PrayersLine.taskId}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showPrayersSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDue ? NouriColors.surfaceActive : NouriColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: isDue ? Border.all(color: NouriColors.gold) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    formatClock(line.showAt),
                    key: const ValueKey('task-time-${PrayersLine.taskId}'),
                    style: cairo(
                      size: 12,
                      weight: FontWeight.w600,
                      color: _accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (line.isDone) ...[
                  const Icon(Icons.check,
                      key: ValueKey('task-done-${PrayersLine.taskId}'),
                      size: 15,
                      color: NouriColors.success),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    'الصلاة — الخمس فروض',
                    style: cairo(
                      size: 13,
                      color:
                          line.isDone ? NouriColors.muted : NouriColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: const ValueKey('prayers-percent'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    toArabicDigits('${line.percent}٪'),
                    style: cairo(
                        size: 10.5, weight: FontWeight.w700, color: _accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Filled in twenty-percent steps, the way he described it.
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: line.fraction,
                minHeight: 4,
                backgroundColor: NouriColors.background,
                color: line.isDone ? NouriColors.success : NouriColors.gold,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                for (final slot in line.slots)
                  Expanded(child: _PrayerDot(slot: slot)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One prayer's name with a dot above it: filled in its state's colour once
/// prayed, hollow otherwise. «فاتتني» draws hollow too — it is logged, but it
/// is not a prayer that happened, and the dot says only that.
class _PrayerDot extends StatelessWidget {
  const _PrayerDot({required this.slot});

  final PrayerSlotState slot;

  @override
  Widget build(BuildContext context) {
    final color = slot.prayed ? chipColorFor(slot.state) : NouriColors.border;

    return Column(
      children: [
        Container(
          key: ValueKey(
              'prayer-dot-${slot.prayer}-${slot.prayed ? 'prayed' : 'open'}'),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: slot.prayed ? color : Colors.transparent,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          slot.arabicName,
          style: cairo(
            size: 9.5,
            color: slot.prayed ? NouriColors.text : NouriColors.muted,
          ),
        ),
      ],
    );
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
