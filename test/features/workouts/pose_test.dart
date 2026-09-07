import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/workouts/pose.dart';
import 'package:nouri/features/workouts/workout_catalogue.dart';

Pose _uniform(double v) =>
    Pose({for (final j in Joint.values) j: Offset(v, v)});

void main() {
  final a = _uniform(0.2);
  final b = _uniform(0.8);

  group('lerp', () {
    test('at the ends returns the endpoints', () {
      expect(Pose.lerp(a, b, 0).joints[Joint.head], const Offset(0.2, 0.2));
      expect(Pose.lerp(a, b, 1).joints[Joint.head], const Offset(0.8, 0.8));
    });

    test('halfway is halfway', () {
      final mid = Pose.lerp(a, b, 0.5).joints[Joint.hip]!;
      expect(mid.dx, closeTo(0.5, 1e-9));
    });

    test('rejects a pose missing a joint', () {
      // A missing joint would draw a limb to (0,0) — a figure with its hand
      // pinned to the corner of the screen. Loudly wrong beats quietly wrong.
      final incomplete = Pose({Joint.head: const Offset(0.5, 0.1)});
      expect(() => Pose.lerp(a, incomplete, 0.5), throwsArgumentError);
      expect(() => Pose.lerp(incomplete, a, 0.5), throwsArgumentError);
    });
  });

  group('frameAt', () {
    final kf = [a, b];

    test('loops seamlessly', () {
      expect(
        frameAt(kf, 0, loopSeconds: 2).joints,
        frameAt(kf, 2, loopSeconds: 2).joints,
      );
    });

    test('is stable past many loops', () {
      expect(
        frameAt(kf, 0.5, loopSeconds: 2).joints,
        frameAt(kf, 100.5, loopSeconds: 2).joints,
      );
    });

    test('treats the keyframes as a cycle, so two poses go there and back', () {
      // Quarter of the way through a two-keyframe loop is halfway from a to b;
      // three quarters is halfway back. That round trip is what makes a squat
      // a squat rather than a figure that snaps upright.
      final quarter = frameAt(kf, 0.5, loopSeconds: 2).joints[Joint.hip]!;
      final threeQuarters = frameAt(kf, 1.5, loopSeconds: 2).joints[Joint.hip]!;
      expect(quarter.dx, closeTo(threeQuarters.dx, 1e-9));
      expect(quarter.dx, greaterThan(0.2));
      expect(quarter.dx, lessThan(0.8));
    });

    test('a single keyframe is a still frame, not a crash', () {
      expect(frameAt([a], 3.2, loopSeconds: 2).joints[Joint.head],
          const Offset(0.2, 0.2));
    });

    test('an empty keyframe list is rejected', () {
      expect(() => frameAt([], 0, loopSeconds: 2), throwsArgumentError);
    });

    test('a zero loop does not divide by zero', () {
      expect(frameAt(kf, 1, loopSeconds: 0).joints[Joint.head],
          const Offset(0.2, 0.2));
    });
  });

  group('poseBounds', () {
    test('is the union across every keyframe, not just the first', () {
      final bounds = poseBounds([_uniform(0.2), _uniform(0.8)]);
      expect(bounds.left, closeTo(0.2, 1e-9));
      expect(bounds.right, closeTo(0.8, 1e-9));
    });

    test('is stable across an exercise, so the figure does not zoom', () {
      // Computed once per exercise. Per-frame bounds would make a squat
      // appear to zoom in on the way down.
      for (final e in kAllExercises) {
        final all = poseBounds(e.keyframes);
        for (final f in e.keyframes) {
          final one = poseBounds([f]);
          expect(all.left, lessThanOrEqualTo(one.left + 1e-9), reason: e.id);
          expect(all.right, greaterThanOrEqualTo(one.right - 1e-9),
              reason: e.id);
        }
      }
    });

    test('a side-on exercise gets a box as tall as a standing one is', () {
      // The point of fitting: a plank spans a fraction of the unit box
      // vertically, and without this it would sit in the bottom third of the
      // card with dead space above it.
      final plank = poseBounds(kPlank.keyframes);
      expect(plank.longestSide, greaterThan(0.4),
          reason: 'a plank is wide, so its long side is its width');
    });

    test('an empty list falls back to the unit box rather than infinities', () {
      expect(poseBounds(const []).width, 1);
    });
  });

  group('the catalogue', () {
    test('every pose defines all thirteen joints', () {
      for (final e in kAllExercises) {
        for (final p in e.keyframes) {
          expect(p.isComplete, isTrue,
              reason: '${e.id} has a keyframe missing a joint');
        }
      }
    });

    test('every pose stays inside the unit box', () {
      // A stray coordinate puts a limb off the edge of the card, which is far
      // easier to catch here than by staring at the screen.
      for (final e in kAllExercises) {
        for (final p in e.keyframes) {
          for (final entry in p.joints.entries) {
            expect(entry.value.dx, inInclusiveRange(0, 1),
                reason: '${e.id}: ${entry.key.name}.dx');
            expect(entry.value.dy, inInclusiveRange(0, 1),
                reason: '${e.id}: ${entry.key.name}.dy');
          }
        }
      }
    });

    test('every exercise has a name, a cue and at least two keyframes', () {
      for (final e in kAllExercises) {
        expect(e.nameAr.trim(), isNotEmpty, reason: e.id);
        expect(e.cueAr.trim(), isNotEmpty,
            reason: '${e.id}: a home workout with no coaching hurts backs');
        expect(e.keyframes.length, greaterThanOrEqualTo(2), reason: e.id);
        expect(e.loopSeconds, greaterThan(0), reason: e.id);
      }
    });

    test('exercise ids are unique', () {
      final ids = kAllExercises.map((e) => e.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every keyframe of an exercise differs from the one before it', () {
      // Two identical keyframes would render as a frozen figure that looks
      // like a broken animation.
      for (final e in kAllExercises) {
        for (var i = 1; i < e.keyframes.length; i++) {
          expect(e.keyframes[i].joints, isNot(e.keyframes[i - 1].joints),
              reason: '${e.id} keyframe $i is identical to the one before');
        }
      }
    });

    test('routines are non-empty, uniquely named, and sensibly sized', () {
      expect(kRoutines, isNotEmpty);
      expect(kRoutines.map((r) => r.id).toSet(), hasLength(kRoutines.length));
      for (final r in kRoutines) {
        expect(r.exercises, isNotEmpty, reason: r.id);
        expect(r.nameAr.trim(), isNotEmpty, reason: r.id);
        expect(r.work.inSeconds, greaterThan(0), reason: r.id);
      }
    });

    test('the full-body routine really is twenty exercises', () {
      expect(kFullBody.totalCount, 20);
      expect(kQuickHome.totalCount, 8);
      expect(kWarmUp.totalCount, 5);
    });

    test('a routine can be found by id', () {
      expect(routineById('full-body')?.nameAr, kFullBody.nameAr);
      expect(routineById('nope'), isNull);
    });

    test('total duration counts no rest after the last exercise', () {
      // 5 x 20s work + 4 x 15s rest.
      expect(kWarmUp.totalDuration, const Duration(seconds: 5 * 20 + 4 * 15));
    });
  });
}
