import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format/arabic_numerals.dart';
import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';

/// The daily progress ring.
///
/// Shows a plain count of the nine daily items, never a percentage. The arc is
/// gold at every value and the track is a muted surface — there is no state at
/// which this widget turns red or otherwise signals failure. An empty day is
/// simply an empty ring.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.done,
    required this.total,
    this.size = 74,
  });

  final int done;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(fraction),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                toArabicDigits('$done/$total'),
                style: cairo(size: size * 0.23, weight: FontWeight.w700),
              ),
              SizedBox(height: size * 0.03),
              Text(
                'النهاردة',
                style: cairo(size: size * 0.12, color: NouriColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = NouriColors.surface;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = NouriColors.gold;

    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (fraction > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}
