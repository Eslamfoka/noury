import 'package:flutter/material.dart';

import '../../../core/format/arabic_numerals.dart';
import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';
import '../day_plan.dart';

/// The colour a pillar reads as in the block strip.
///
/// Drawn from the existing palette rather than four new hues: the strip is a
/// glance-level cue, not a legend, and four saturated colours on one row would
/// compete with the gold that marks the current block.
Color pillarColour(TaskPillar p) => switch (p) {
      TaskPillar.deen => NouriColors.gold,
      TaskPillar.body => NouriColors.success,
      TaskPillar.mind => NouriColors.border,
      TaskPillar.wealth => NouriColors.attention,
    };

/// The four big day blocks.
///
/// Collapsed by default, one expandable at a time. The brief is explicit about
/// why: a long checklist recreates the exact overwhelm the app exists to
/// remove, so Home shows four rows and hour-by-hour detail only on tap.
///
/// Past blocks dim with a soft green check; the current one is outlined gold.
/// Nothing is ever marked failed.
class DayBlocks extends StatefulWidget {
  const DayBlocks({
    super.key,
    required this.plan,
    required this.now,
    this.done = const {},
    this.interactive = false,
  });

  final DayPlan plan;
  final DateTime now;

  /// The task ids the logs say are already done today.
  ///
  /// **Shown, never written here.** The plan stays read-only: whether it
  /// should also be a *place to log* is an open question about where the truth
  /// lives, and `docs/planner-decisions.md` records why guessing at it has
  /// already cost two bugs. Displaying what the logs already say costs no such
  /// decision — the truth is still the log, and this is a window onto it.
  final Set<String> done;

  /// False while this is a static preview: tapping a task would teach a habit
  /// the real planner then has to honour.
  final bool interactive;

  @override
  State<DayBlocks> createState() => _DayBlocksState();
}

class _DayBlocksState extends State<DayBlocks> {
  DayBlockKind? _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = _currentBlock()?.kind;
  }

  DayBlock? _currentBlock() {
    for (final b in widget.plan.blocks) {
      if (widget.now.isAfter(b.start) && widget.now.isBefore(b.end)) return b;
    }
    return null;
  }

  bool _isPast(DayBlock b) => widget.now.isAfter(b.end);

  @override
  Widget build(BuildContext context) {
    final current = _currentBlock();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in widget.plan.blocks)
          _BlockCard(
            block: block,
            isCurrent: block.kind == current?.kind,
            isPast: _isPast(block),
            isExpanded: _expanded == block.kind,
            now: widget.now,
            done: widget.done,
            onTap: () => setState(
              () => _expanded = _expanded == block.kind ? null : block.kind,
            ),
          ),
      ],
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.block,
    required this.isCurrent,
    required this.isPast,
    required this.isExpanded,
    required this.now,
    required this.done,
    required this.onTap,
  });

  final DayBlock block;
  final bool isCurrent;
  final bool isPast;
  final bool isExpanded;
  final DateTime now;

  /// The task ids today's logs already show as done.
  final Set<String> done;

  final VoidCallback onTap;

  /// A count tells you almost nothing about a block you are standing in. When
  /// this is the current block, name the next task instead — that is the
  /// question the user actually has.
  String get subtitle {
    final range = '${formatClock(block.start)} – ${formatClock(block.end)}';
    if (!isCurrent) {
      return '$range · ${toArabicDigits('${block.tasks.length}')} مهام';
    }
    for (final t in block.tasks) {
      if (t.start.isAfter(now)) return 'الجاي: ${t.task.title}';
    }
    return range;
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: isCurrent ? NouriColors.surfaceActive : NouriColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isCurrent ? NouriColors.gold : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(block.kind.arabicLabel,
                        style: cairo(size: 14.5, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: cairo(size: 11.5, color: NouriColors.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isPast)
                const Icon(Icons.check, size: 16, color: NouriColors.success)
              else
                Icon(
                  isExpanded ? Icons.expand_less : Icons.chevron_left,
                  size: 18,
                  color: isCurrent ? NouriColors.gold : NouriColors.muted,
                ),
            ],
          ),
          if (!isExpanded && block.tasks.isNotEmpty) ...[
            const SizedBox(height: 9),
            _PillarStrip(tasks: block.tasks),
          ],
          if (isExpanded && block.tasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 11),
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: NouriColors.border)),
              ),
              child: Column(
                children: [
                  for (final t in block.tasks)
                    _TaskRow(
                      scheduled: t,
                      done: done.contains(t.task.id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: isPast ? Opacity(opacity: 0.5, child: card) : card,
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.scheduled, this.done = false});

  final ScheduledTask scheduled;

  /// Whether the logs already show this as done.
  final bool done;

  @override
  Widget build(BuildContext context) {
    final task = scheduled.task;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              formatClock(scheduled.start),
              style: cairo(size: 11, color: NouriColors.muted),
            ),
          ),
          const SizedBox(width: 8),
          if (done) ...[
            // A tick, not a strikethrough. Nothing here is ever crossed out:
            // the day is a plan, not a list of things to fail at.
            Icon(
              Icons.check,
              key: ValueKey('task-done-${task.id}'),
              size: 14,
              color: NouriColors.success,
            ),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              task.title,
              style: cairo(
                size: 12.5,
                color: done ? NouriColors.muted : NouriColors.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Tag(text: task.pillar.arabicLabel),
          if (task.weight == TaskWeight.heavy) ...[
            const SizedBox(width: 5),
            _Tag(text: task.weight.arabicLabel),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: NouriColors.border),
        ),
        child: Text(text,
            style: cairo(size: 9, color: NouriColors.muted)),
      );
}

/// A one-line read of what a collapsed block is made of.
///
/// One segment per task, coloured by pillar and widened by the task's length,
/// so a block that is three hours of work and ten minutes of athkar looks like
/// that rather than like "4 مهام". It is the smallest thing that makes the
/// deen/body/mind/wealth balance visible without opening anything.
class _PillarStrip extends StatelessWidget {
  const _PillarStrip({required this.tasks});

  final List<ScheduledTask> tasks;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        child: Row(
          children: [
            for (final t in tasks)
              Expanded(
                // A one-minute task would otherwise vanish; a three-hour one
                // would swallow the row. Clamping keeps every task visible
                // and keeps the proportions honest enough to read.
                flex: t.end.difference(t.start).inMinutes.clamp(10, 120),
                child: Padding(
                  padding: const EdgeInsets.only(left: 1.5),
                  child: ColoredBox(color: pillarColour(t.task.pillar)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
