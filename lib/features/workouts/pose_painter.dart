import 'package:flutter/material.dart';

import '../../core/theme/nouri_colors.dart';
import 'pose.dart';

/// Draws one pose as a figure.
///
/// Limbs are rounded strokes so the joints read as joints rather than as
/// mitred corners, and the head is a filled circle. Nothing here is animated —
/// the painter draws a single frame and [ExerciseAnimation] decides which.
class PosePainter extends CustomPainter {
  const PosePainter({
    required this.pose,
    required this.bounds,
    this.colour = NouriColors.text,
    this.accent = NouriColors.gold,
  });

  final Pose pose;

  /// The box the whole exercise moves inside — see [poseBounds]. Mapping this
  /// to the canvas rather than the raw unit box is what stops a side-on plank
  /// sitting in the bottom third of the card with dead space above it.
  final Rect bounds;
  final Color colour;

  /// The head, so the figure has a front and reads at a glance.
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Aspect ratio is preserved rather than stretched: scaling x and y
    // independently would give a plank a wide flat head.
    const pad = 0.06;
    final usable = size.shortestSide * (1 - 2 * pad);
    final span = bounds.longestSide;
    final scale = span <= 0 ? usable : usable / span;

    // Centre what the figure actually occupies in the canvas.
    final drawnW = bounds.width * scale;
    final drawnH = bounds.height * scale;
    final originX = (size.width - drawnW) / 2;
    final originY = (size.height - drawnH) / 2;

    Offset at(Joint j) {
      final o = pose.joints[j]!;
      return Offset(
        originX + (o.dx - bounds.left) * scale,
        originY + (o.dy - bounds.top) * scale,
      );
    }

    final side = usable;

    final stroke = Paint()
      ..color = colour
      ..strokeWidth = side * 0.028
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final (a, b) in kBones) {
      // The neck-to-head bone is covered by the head circle; drawing it would
      // put a stub through the face.
      if (a == Joint.head || b == Joint.head) continue;
      canvas.drawLine(at(a), at(b), stroke);
    }

    // The neck stub, from the neck up to just under the head.
    final neck = at(Joint.neck);
    final head = at(Joint.head);
    final headRadius = side * 0.062;
    final toHead = head - neck;
    final len = toHead.distance;
    if (len > headRadius) {
      canvas.drawLine(neck, neck + toHead * ((len - headRadius) / len), stroke);
    }

    canvas.drawCircle(head, headRadius, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(PosePainter old) =>
      old.pose.joints != pose.joints ||
      old.bounds != bounds ||
      old.colour != colour ||
      old.accent != accent;
}
