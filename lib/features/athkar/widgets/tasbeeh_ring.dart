import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/format/arabic_numerals.dart';
import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';

/// The circular tasbeeh: gold beads that fill as you count.
///
/// The whole ring is tappable, not just the button. Above ~150 beads the ring
/// switches to a continuous arc, because individual beads stop being legible
/// and start looking like noise.
class TasbeehRing extends StatelessWidget {
  const TasbeehRing({
    super.key,
    required this.count,
    required this.target,
    required this.onTap,
    this.size = 236,
  });

  final int count;
  final int target;
  final VoidCallback onTap;
  final double size;

  static const beadThreshold = 150;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'سبّح',
      value: toArabicDigits('$count من $target'),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _TasbeehPainter(count: count, target: target),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    toArabicDigits('$count'),
                    style: NouriText.counter,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    toArabicDigits('من $target'),
                    style: cairo(size: 13, color: NouriColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TasbeehPainter extends CustomPainter {
  const _TasbeehPainter({required this.count, required this.target});

  final int count;
  final int target;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    if (target <= TasbeehRing.beadThreshold) {
      _paintBeads(canvas, centre, radius);
    } else {
      _paintArc(canvas, centre, radius);
    }
  }

  void _paintBeads(Canvas canvas, Offset centre, double radius) {
    final off = Paint()..color = NouriColors.surfaceActive;
    final on = Paint()..color = NouriColors.gold;

    for (var i = 0; i < target; i++) {
      final angle = (i / target) * 2 * math.pi - math.pi / 2;
      final p = Offset(
        centre.dx + radius * math.cos(angle),
        centre.dy + radius * math.sin(angle),
      );
      final filled = i < count;
      canvas.drawCircle(p, filled ? 5 : 4, filled ? on : off);
    }
  }

  void _paintArc(Canvas canvas, Offset centre, double radius) {
    final rect = Rect.fromCircle(center: centre, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = NouriColors.surfaceActive;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = NouriColors.gold;

    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    final fraction = (count / target).clamp(0.0, 1.0);
    if (fraction > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
    }
  }

  @override
  bool shouldRepaint(_TasbeehPainter old) =>
      old.count != count || old.target != target;
}
