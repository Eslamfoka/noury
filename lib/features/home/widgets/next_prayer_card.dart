import 'package:flutter/material.dart';

import '../../../core/format/arabic_numerals.dart';
import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';
import '../../../core/time/prayer_times_service.dart';
import '../../prayers/prayer_names.dart';

/// The prominent next-prayer card: name, time, live countdown, iqama.
///
/// A fixed contract — Phase 2 keeps this card exactly as it is.
class NextPrayerCard extends StatelessWidget {
  const NextPrayerCard({
    super.key,
    required this.slot,
    required this.iqama,
    required this.remaining,
  });

  final PrayerSlot slot;
  final DateTime iqama;
  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: NouriColors.surfaceActive,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NouriColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الصلاة القادمة',
            style: cairo(
              size: 11,
              weight: FontWeight.w600,
              color: NouriColors.gold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    arabicPrayerName(slot.name),
                    style: cairo(size: 24, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatClock(slot.time),
                    style: cairo(size: 13, color: NouriColors.muted),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // Clamped at zero inside formatCountdown, so a prayer that
                    // has just passed reads ٠:٠٠:٠٠ rather than a minus.
                    formatCountdown(remaining),
                    style: cairo(
                      size: 27,
                      weight: FontWeight.w700,
                      color: NouriColors.gold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'باقي على الأذان',
                    style: cairo(size: 10, color: NouriColors.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 9),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: NouriColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  'الإقامة ',
                  style: cairo(size: 12, color: NouriColors.muted),
                ),
                Text(
                  formatClock(iqama),
                  style: cairo(size: 12, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
