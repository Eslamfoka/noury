import 'package:flutter/material.dart';

import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';
import '../../../core/time/hijri_date.dart';
import '../../shared/nouri_avatar.dart';

/// The Home header: greeting, both dates, and the gold Nouri mark.
///
/// The Hijri date is primary — brighter and slightly larger — because Nouri is
/// a religious daily companion and that is the calendar its reminders live in.
/// The Gregorian date sits under it in muted text so the user can place the day
/// in the working week without the header becoming busy.
///
/// This is a fixed contract: Phase 2's scheduler replaces only the middle of
/// the Home screen, never this.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.hijri,
    required this.gregorian,
    required this.greeting,
  });

  final HijriDate hijri;

  /// Already formatted for the active locale — see `formatGregorianLong`.
  final String gregorian;

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(greeting, style: cairo(size: 19, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                hijri.formatted,
                style: cairo(size: 12.5, weight: FontWeight.w600),
              ),
              const SizedBox(height: 1),
              Text(
                gregorian,
                style: cairo(size: 11, color: NouriColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const NouriAvatar(),
      ],
    );
  }
}
