import 'package:flutter/material.dart';

import '../../../core/format/arabic_numerals.dart';
import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';
import '../day_plan.dart';

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
    this.interactive = false,
  });

  final DayPlan plan;
  final DateTime now;

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
    required this.onTap,
  });

  final DayBlock block;
  final bool isCurrent;
  final bool isPast;
  final bool isExpanded;
  final VoidCallback onTap;

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
                      '${formatClock(block.start)} – ${formatClock(block.end)}'
                      ' · ${toArabicDigits('${block.tasks.length}')} مهام',
                      style: cairo(size: 11.5, color: NouriColors.muted),
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
          if (isExpanded && block.tasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 11),
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: NouriColors.border)),
              ),
              child: Column(
                children: [
                  for (final t in block.tasks) _TaskRow(scheduled: t),
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
  const _TaskRow({required this.scheduled});

  final ScheduledTask scheduled;

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
          Expanded(child: Text(task.title, style: cairo(size: 12.5))),
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
