import 'package:flutter/material.dart';

import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';
import '../../../core/time/hijri_date.dart';
import '../../shared/nouri_avatar.dart';

/// The Home header: greeting, Hijri date, and the gold Nouri mark.
///
/// This is a fixed contract — Phase 2's scheduler replaces only the middle of
/// the Home screen, never this.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.hijri,
    required this.greeting,
  });

  final HijriDate hijri;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(greeting, style: cairo(size: 19, weight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              hijri.formatted,
              style: cairo(size: 12, color: NouriColors.muted),
            ),
          ],
        ),
        const NouriAvatar(),
      ],
    );
  }
}
