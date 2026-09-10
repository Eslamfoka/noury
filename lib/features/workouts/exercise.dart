import 'pose.dart';

/// One exercise: what it is called, how to do it, and what it looks like.
///
/// The "video" is [keyframes] — two to four poses the player interpolates
/// between. See `pose.dart` for why it is drawn rather than filmed.
class Exercise {
  const Exercise({
    required this.id,
    required this.nameAr,
    required this.cueAr,
    required this.keyframes,
    this.loopSeconds = 2.4,
  });

  final String id;
  final String nameAr;

  /// One line of form advice, shown under the figure.
  ///
  /// Mandatory. A home workout with no coaching is how people hurt their
  /// backs, and one line is what fits on the screen and in the head.
  final String cueAr;

  final List<Pose> keyframes;
  final double loopSeconds;
}

/// A routine: exercises done in order, with fixed work and rest intervals.
class Routine {
  const Routine({
    required this.id,
    required this.nameAr,
    required this.descriptionAr,
    required this.exercises,
    this.work = const Duration(seconds: 30),
    this.rest = const Duration(seconds: 30),
  });

  final String id;
  final String nameAr;
  final String descriptionAr;
  final List<Exercise> exercises;
  final Duration work;
  final Duration rest;

  int get totalCount => exercises.length;

  /// Total wall-clock length. The last exercise has no trailing rest, because
  /// resting after you have stopped is just standing about.
  Duration get totalDuration =>
      work * totalCount + rest * (totalCount - 1).clamp(0, 1 << 20);
}
