import 'dart:ui' show Offset, Rect;

/// The joints a figure is drawn from.
///
/// Thirteen is the smallest set that reads as a human body doing an exercise:
/// fewer and the limbs stop bending where limbs bend.
enum Joint {
  head,
  neck,
  shoulderL,
  shoulderR,
  elbowL,
  elbowR,
  handL,
  handR,
  hip,
  kneeL,
  kneeR,
  footL,
  footR,
}

/// The bones, as pairs of joints. Drawn in this order.
const kBones = <(Joint, Joint)>[
  (Joint.head, Joint.neck),
  (Joint.neck, Joint.shoulderL),
  (Joint.neck, Joint.shoulderR),
  (Joint.shoulderL, Joint.elbowL),
  (Joint.shoulderR, Joint.elbowR),
  (Joint.elbowL, Joint.handL),
  (Joint.elbowR, Joint.handR),
  (Joint.neck, Joint.hip),
  (Joint.hip, Joint.kneeL),
  (Joint.hip, Joint.kneeR),
  (Joint.kneeL, Joint.footL),
  (Joint.kneeR, Joint.footR),
];

/// One frame of an exercise: where every joint is.
///
/// Positions are in a unit box — (0,0) top-left, (1,1) bottom-right — so a
/// pose is resolution-independent and the same data draws at any size. This is
/// what makes the "video" a few hundred bytes instead of a few megabytes, and
/// it needs no codec, no `video_player`, and no network.
class Pose {
  const Pose(this.joints);

  final Map<Joint, Offset> joints;

  /// Every joint must be present. A pose missing one would draw a limb to
  /// (0,0) — a figure with its hand pinned to the corner of the screen — so
  /// this is checked rather than defaulted.
  bool get isComplete =>
      Joint.values.every((j) => joints.containsKey(j));

  static Pose lerp(Pose a, Pose b, double t) {
    if (!a.isComplete || !b.isComplete) {
      throw ArgumentError('both poses must define every joint');
    }
    return Pose({
      for (final j in Joint.values)
        j: Offset.lerp(a.joints[j], b.joints[j], t)!,
    });
  }
}

/// Smooths the motion between two keyframes.
///
/// Linear interpolation makes a figure move like a machine — constant speed,
/// hard stop, hard start. Smoothstep eases in and out, which is how a body
/// actually moves through the bottom of a squat.
double _ease(double t) => t * t * (3 - 2 * t);

/// The frame at [t] seconds of a looping keyframe sequence.
///
/// The keyframes are a **cycle**: the last interpolates back to the first. So
/// a squat is two poses — standing and down — and the loop is
/// stand → down → stand, with no third keyframe to keep in step.
Pose frameAt(
  List<Pose> keyframes,
  double t, {
  required double loopSeconds,
}) {
  if (keyframes.isEmpty) {
    throw ArgumentError('an exercise needs at least one keyframe');
  }
  if (keyframes.length == 1) return keyframes.first;
  if (loopSeconds <= 0) return keyframes.first;

  final n = keyframes.length;
  final phase = (t % loopSeconds) / loopSeconds;
  final scaled = phase * n;
  final i = scaled.floor() % n;
  final local = scaled - scaled.floor();

  return Pose.lerp(keyframes[i], keyframes[(i + 1) % n], _ease(local));
}

/// The box every keyframe of an exercise fits inside.
///
/// Computed across the whole sequence, not per frame. Per-frame would make the
/// figure grow and shrink as it moved — a squat would appear to zoom in on the
/// way down. Across the sequence, the frame is stable and the body moves
/// inside it, which is what a camera on a tripod looks like.
///
/// This is what lets a side-on plank fill the card as well as a standing
/// squat does: the poses are authored where they are anatomically sensible,
/// and the painter fits whatever box they turn out to occupy.
Rect poseBounds(List<Pose> frames) {
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;

  for (final f in frames) {
    for (final o in f.joints.values) {
      if (o.dx < minX) minX = o.dx;
      if (o.dy < minY) minY = o.dy;
      if (o.dx > maxX) maxX = o.dx;
      if (o.dy > maxY) maxY = o.dy;
    }
  }

  if (minX > maxX || minY > maxY) return const Rect.fromLTWH(0, 0, 1, 1);
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
