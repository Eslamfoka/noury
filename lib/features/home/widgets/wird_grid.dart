import 'package:flutter/material.dart';

import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';

/// One card's worth of state in the الورد اليومي grid.
class WirdState {
  const WirdState({
    required this.label,
    required this.subtitle,
    required this.fraction,
    required this.done,
    this.onTap,
  });

  final String label;
  final String subtitle;
  final double fraction;
  final bool done;
  final VoidCallback? onTap;
}

/// الورد اليومي — a 2×2 grid in the approved order:
/// أذكار الصباح · التسبيح · أذكار المساء · ورد القرآن
///
/// A completed card is dimmed with a soft green check. There is no failed
/// state and no red: an untouched card simply shows an empty progress bar.
class WirdGrid extends StatelessWidget {
  const WirdGrid({
    super.key,
    required this.morning,
    required this.tasbeeh,
    required this.evening,
    required this.quran,
  });

  final WirdState morning;
  final WirdState tasbeeh;
  final WirdState evening;
  final WirdState quran;

  @override
  Widget build(BuildContext context) {
    final cards = [morning, tasbeeh, evening, quran];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: [for (final c in cards) _WirdCard(state: c)],
    );
  }
}

class _WirdCard extends StatelessWidget {
  const _WirdCard({required this.state});

  final WirdState state;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (state.done) ...[
                const Icon(Icons.check, size: 14, color: NouriColors.success),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  state.label,
                  style: cairo(size: 13, weight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            state.subtitle,
            style: cairo(size: 11, color: NouriColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.fraction.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: NouriColors.background,
              valueColor: AlwaysStoppedAnimation(
                state.done ? NouriColors.success : NouriColors.gold,
              ),
            ),
          ),
        ],
      ),
    );

    final content = state.done ? Opacity(opacity: 0.55, child: card) : card;

    if (state.onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: state.onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}
