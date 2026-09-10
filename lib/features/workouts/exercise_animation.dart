import 'package:flutter/material.dart';

import 'exercise.dart';
import 'pose_painter.dart';
import 'pose.dart';

/// Plays an exercise as frames.
///
/// This is the "video". A [Ticker] advances a clock, [frameAt] interpolates
/// the pose for that instant, and [PosePainter] draws it — so the whole thing
/// is a few hundred bytes of coordinates rather than a video file, works
/// offline, needs no codec, and stays sharp at any size.
///
/// [playing] false holds the figure still on its first keyframe. A rest screen
/// uses that to show what is coming without it moving.
class ExerciseAnimation extends StatefulWidget {
  const ExerciseAnimation({
    super.key,
    required this.exercise,
    this.playing = true,
  });

  final Exercise exercise;
  final bool playing;

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Computed once per exercise, not per frame — a bounding box recomputed
  /// every frame would make the figure zoom as it moved.
  late Rect _bounds;

  @override
  void initState() {
    super.initState();
    _bounds = poseBounds(widget.exercise.keyframes);
    // One second per cycle of the controller; the exercise's own loopSeconds
    // is applied in the frame lookup, so changing exercise never restarts or
    // jars the controller.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.playing) _controller.repeat();
  }

  @override
  void didUpdateWidget(ExerciseAnimation old) {
    super.didUpdateWidget(old);
    if (old.exercise.id != widget.exercise.id) {
      _bounds = poseBounds(widget.exercise.keyframes);
    }
    if (widget.playing && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.playing && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercise;

    if (!widget.playing) {
      return CustomPaint(
        painter: PosePainter(pose: e.keyframes.first, bounds: _bounds),
        size: Size.infinite,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // lastElapsedDuration is null on the very first frame, before the
        // ticker has run — the first keyframe is the right thing to show then.
        final t = (_controller.lastElapsedDuration ?? Duration.zero)
                .inMilliseconds /
            1000.0;
        final Pose pose = frameAt(
          e.keyframes,
          t,
          loopSeconds: e.loopSeconds,
        );
        return CustomPaint(
          painter: PosePainter(pose: pose, bounds: _bounds),
          size: Size.infinite,
        );
      },
    );
  }
}
