import 'package:flutter/material.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../core/time/prayer_times_service.dart';
import '../../data/db/tables.dart';
import 'prayer_names.dart';
import 'prayer_scoring.dart';

/// One compact, tappable prayer row.
///
/// The whole row opens the logging sheet — there is no separate control to
/// hunt for. The next prayer is emphasised with the active surface and a
/// border; everything else stays quiet.
class PrayerRow extends StatelessWidget {
  const PrayerRow({
    super.key,
    required this.slot,
    required this.state,
    required this.isNext,
    required this.onTap,
  });

  final PrayerSlot slot;
  final PrayerState state;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = chipColorFor(state);
    final logged = state != PrayerState.none;

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: isNext ? NouriColors.surfaceActive : NouriColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: isNext
                  ? Border.all(color: NouriColors.border)
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: logged ? chipColor : NouriColors.border,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        arabicPrayerName(slot.name),
                        style: cairo(size: 14, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatClock(slot.time),
                        style: cairo(size: 11.5, color: NouriColors.muted),
                      ),
                    ],
                  ),
                ),
                _StateChip(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final PrayerState state;

  @override
  Widget build(BuildContext context) {
    final color = chipColorFor(state);
    final isPlaceholder = state == PrayerState.none;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPlaceholder ? Colors.transparent : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaceholder ? NouriColors.border : color.withValues(alpha: 0.4),
        ),
      ),
      child: Text(
        chipLabelFor(state),
        style: cairo(size: 10.5, weight: FontWeight.w600, color: color),
      ),
    );
  }
}
