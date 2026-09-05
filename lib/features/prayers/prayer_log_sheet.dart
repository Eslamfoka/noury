import 'package:flutter/material.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/tables.dart';
import 'prayer_names.dart';
import 'prayer_scoring.dart';

/// Asks how the prayer was performed.
///
/// The four states are offered best-first as a positive challenge. Clearing an
/// entry is possible but sits apart from the four, so it never reads as a
/// fifth, worst grade. Nothing here scolds — the sheet asks a question.
Future<PrayerState?> showPrayerLogSheet(
  BuildContext context,
  String prayerSlot,
  PrayerState current,
) {
  return showModalBottomSheet<PrayerState>(
    context: context,
    backgroundColor: NouriColors.surface,
    // Scroll-controlled and scrollable: on a short screen (or with large
    // system font sizes) the four options plus the clear action would
    // otherwise overflow and the last control would be unreachable.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NouriColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'صليت ${arabicPrayerName(prayerSlot)} إزاي؟',
                style: cairo(size: 16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              for (final state in loggablePrayerStates)
                _StateOption(
                  state: state,
                  selected: state == current,
                  onTap: () => Navigator.of(ctx).pop(state),
                ),
              if (current != PrayerState.none) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(PrayerState.none),
                  child: Text(
                    'امسح التسجيل',
                    style: cairo(size: 12.5, color: NouriColors.muted),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _StateOption extends StatelessWidget {
  const _StateOption({
    required this.state,
    required this.selected,
    required this.onTap,
  });

  final PrayerState state;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = chipColorFor(state);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? NouriColors.surfaceActive : NouriColors.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : NouriColors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    chipLabelFor(state),
                    style: cairo(size: 14.5, weight: FontWeight.w600),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check, size: 18, color: NouriColors.success),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
