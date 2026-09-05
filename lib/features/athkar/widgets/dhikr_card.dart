import 'package:flutter/material.dart';

import '../../../core/format/arabic_numerals.dart';
import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';
import '../../../data/athkar/athkar_item.dart';

/// One dhikr: the text in Amiri, its source, its repeat pill, and — only where
/// the wording is well-established — a tap-to-reveal virtue.
///
/// The virtue is hidden by default so the dhikr itself stays the visual focus.
/// When an entry has no established virtue the control is **absent**, not
/// disabled, so nothing invites the user to look for text that does not exist.
class DhikrCard extends StatefulWidget {
  const DhikrCard({
    super.key,
    required this.item,
    required this.repeatsDone,
    required this.onTap,
  });

  final AthkarItem item;
  final int repeatsDone;
  final VoidCallback onTap;

  @override
  State<DhikrCard> createState() => _DhikrCardState();
}

class _DhikrCardState extends State<DhikrCard> {
  bool _virtueShown = false;

  @override
  void didUpdateWidget(DhikrCard old) {
    super.didUpdateWidget(old);
    // A new dhikr starts with its virtue hidden again.
    if (old.item.id != widget.item.id && _virtueShown) {
      _virtueShown = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            item.text,
            textAlign: TextAlign.center,
            style: NouriText.dhikr,
          ),
          const SizedBox(height: 14),
          Text(
            item.source,
            textAlign: TextAlign.center,
            style: cairo(size: 11, color: NouriColors.muted),
          ),
          const SizedBox(height: 12),
          _RepeatPill(done: widget.repeatsDone, total: item.count),
          if (item.note != null) ...[
            const SizedBox(height: 10),
            Text(
              item.note!,
              textAlign: TextAlign.center,
              style: cairo(size: 10.5, color: NouriColors.muted),
            ),
          ],
          if (item.hasVirtue) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _virtueShown = !_virtueShown),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'الفضل',
                      style: cairo(
                        size: 12,
                        weight: FontWeight.w600,
                        color: NouriColors.gold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _virtueShown ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: NouriColors.gold,
                    ),
                  ],
                ),
              ),
            ),
            if (_virtueShown)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  item.virtue!,
                  textAlign: TextAlign.center,
                  style:
                      cairo(size: 12, color: NouriColors.muted, height: 1.8),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _RepeatPill extends StatelessWidget {
  const _RepeatPill({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: NouriColors.surfaceActive,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: NouriColors.border),
      ),
      child: Text(
        toArabicDigits('$done / $total'),
        style: cairo(size: 13, weight: FontWeight.w600),
      ),
    );
  }
}
