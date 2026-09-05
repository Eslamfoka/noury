import 'package:flutter/material.dart';

import '../../core/theme/nouri_colors.dart';

/// The small gold «نوري» mark that appears wherever Nouri speaks — the header,
/// reminders, reports, and the coming-soon placeholders.
class NouriAvatar extends StatelessWidget {
  const NouriAvatar({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: NouriColors.surfaceActive,
        shape: BoxShape.circle,
        border: Border.all(color: NouriColors.gold, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        'نوري',
        style: TextStyle(
          color: NouriColors.gold,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}
