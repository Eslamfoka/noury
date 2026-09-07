import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/workouts/exercise.dart';
import 'package:nouri/features/workouts/interval_timer.dart';
import 'package:nouri/features/workouts/workout_catalogue.dart';

Routine routineOf(int n) => Routine(
      id: 'test-$n',
      nameAr: 'تجربة',
      descriptionAr: 'تجربة',
      exercises: List.generate(n, (i) => kAllExercises[i % kAllExercises.length]),
    );

void main() {
  final routine = routineOf(3); // 30s work, 30s rest

  test('starts ready, not running', () {
    final t = IntervalTimer(routine);
    expect(t.phase, IntervalPhase.ready);
    expect(t.isRunning, isFalse);
    expect(t.doneCount, 0);
  });

  test('a tick before start does nothing', () {
    final t = IntervalTimer(routine);
    t.tick(const Duration(seconds: 10));
    expect(t.phase, IntervalPhase.ready);
    expect(t.elapsed, Duration.zero);
  });

  test('work runs for the routine work duration, then rest', () {
    final t = IntervalTimer(routine)..start();
    expect(t.phase, IntervalPhase.work);

    t.tick(const Duration(seconds: 29));
    expect(t.phase, IntervalPhase.work);
    expect(t.doneCount, 0);

    t.tick(const Duration(seconds: 1));
    expect(t.phase, IntervalPhase.rest);
    expect(t.doneCount, 1);
  });

  test('rest leads into the next exercise', () {
    final t = IntervalTimer(routine)..start();
    t.tick(const Duration(seconds: 30)); // work 1 done
    expect(t.index, 0);

    t.tick(const Duration(seconds: 30)); // rest done
    expect(t.phase, IntervalPhase.work);
    expect(t.index, 1);
  });

  test('a tick longer than the phase does not skip past the next one', () {
    // A backgrounded app resumes with one big tick. Losing a whole rest period
    // to it would drop the user into the next exercise with no warning.
    final t = IntervalTimer(routine)..start();
    t.tick(const Duration(seconds: 45));
    expect(t.phase, IntervalPhase.rest);
    expect(t.remaining, const Duration(seconds: 15));
    expect(t.doneCount, 1);
  });

  test('a very long tick still lands on the right phase', () {
    final t = IntervalTimer(routine)..start();
    // 30 work + 30 rest + 30 work + 30 rest = 120, then 10s into exercise 3.
    t.tick(const Duration(seconds: 130));
    expect(t.phase, IntervalPhase.work);
    expect(t.index, 2);
    expect(t.doneCount, 2);
    expect(t.remaining, const Duration(seconds: 20));
  });

  test('the last exercise has no trailing rest', () {
    final t = IntervalTimer(routineOf(2))..start();
    t.tick(const Duration(seconds: 30)); // ex 1 work done -> rest
    t.tick(const Duration(seconds: 30)); // rest done -> ex 2 work
    t.tick(const Duration(seconds: 30)); // ex 2 work done
    expect(t.phase, IntervalPhase.done);
    expect(t.fraction, 1.0);
    expect(t.isRunning, isFalse);
  });

  test('ticking past the end stays done', () {
    final t = IntervalTimer(routineOf(1))..start();
    t.tick(const Duration(seconds: 300));
    expect(t.phase, IntervalPhase.done);
    expect(t.doneCount, 1);
  });

  group('progress', () {
    test('five of twenty is twenty-five percent', () {
      final t = IntervalTimer(kFullBody)..start();
      for (var i = 0; i < 5; i++) {
        t.skip(); // work -> counts, into rest
        t.skip(); // rest -> next work
      }
      expect(t.doneCount, 5);
      expect(t.totalCount, 20);
      expect(t.fraction, 0.25);
    });

    test('a skipped exercise still counts', () {
      // A skip that scored nothing would just teach the user to sit through
      // the timer rather than move on.
      final t = IntervalTimer(routine)..start();
      t.skip();
      expect(t.doneCount, 1);
      expect(t.phase, IntervalPhase.rest);
    });

    test('skipping a rest goes to the next exercise without double-counting',
        () {
      final t = IntervalTimer(routine)..start();
      t.skip(); // work 1 done
      expect(t.doneCount, 1);
      t.skip(); // skip the rest
      expect(t.doneCount, 1, reason: 'a rest is not an exercise');
      expect(t.phase, IntervalPhase.work);
      expect(t.index, 1);
    });

    test('phase progress fills across the interval', () {
      final t = IntervalTimer(routine)..start();
      expect(t.phaseFraction, 0.0);
      t.tick(const Duration(seconds: 15));
      expect(t.phaseFraction, closeTo(0.5, 1e-9));
    });
  });

  group('pausing', () {
    test('holds the clock and is reversible', () {
      final t = IntervalTimer(routine)..start();
      t.tick(const Duration(seconds: 10));
      t.pause();

      t.tick(const Duration(seconds: 100));
      expect(t.remaining, const Duration(seconds: 20),
          reason: 'a paused timer must not advance');

      t.pause();
      t.tick(const Duration(seconds: 5));
      expect(t.remaining, const Duration(seconds: 15));
    });
  });

  group('what the rest screen shows', () {
    test('rest names the exercise it is leading into', () {
      final t = IntervalTimer(routine)..start();
      t.skip();
      expect(t.phase, IntervalPhase.rest);
      expect(t.upNext?.id, routine.exercises[1].id);
    });

    test('there is no next after the last exercise', () {
      final t = IntervalTimer(routineOf(1))..start();
      expect(t.upNext, isNull);
    });
  });

  test('an empty routine finishes immediately rather than crashing', () {
    final empty = Routine(
      id: 'empty',
      nameAr: 'فاضي',
      descriptionAr: '',
      exercises: const [],
    );
    final t = IntervalTimer(empty)..start();
    expect(t.phase, IntervalPhase.done);
    expect(t.fraction, 0);
  });
}
