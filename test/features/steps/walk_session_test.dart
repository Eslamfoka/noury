import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/steps/step_source.dart';
import 'package:nouri/features/steps/walk_session.dart';

void main() {
  group('the simulated source', () {
    test('emits a rising cumulative count', () async {
      final s = SimulatedStepSource(
        startAt: 1000,
        stepsPerTick: 2,
        tick: const Duration(milliseconds: 1),
      );
      addTearDown(s.dispose);
      expect(await s.cumulativeSteps().take(3).toList(), [1002, 1004, 1006]);
    });

    test('reports itself ready — no hardware, no permission needed', () async {
      final s = SimulatedStepSource();
      addTearDown(s.dispose);
      expect(await s.state(), StepSensorState.ready);
    });
  });

  group('distance', () {
    test('is steps times stride', () {
      final s = walkStats(
        steps: 1000,
        elapsed: const Duration(minutes: 10),
        strideCm: 72,
        weightGrams: 87000,
      );
      expect(s.metres, 720);
    });

    test('follows the stride the user set', () {
      final short = walkStats(
        steps: 1000,
        elapsed: const Duration(minutes: 10),
        strideCm: 60,
        weightGrams: 87000,
      );
      expect(short.metres, 600);
    });
  });

  group('the awkward inputs', () {
    test('a reboot mid-session cannot produce negative steps', () {
      // TYPE_STEP_COUNTER resets to zero on reboot, so the delta against the
      // session's start reading goes negative. A walk must never run backwards.
      final s = walkStats(
        steps: -5,
        elapsed: const Duration(minutes: 1),
        strideCm: 72,
        weightGrams: 87000,
      );
      expect(s.steps, 0);
      expect(s.metres, 0);
      expect(s.kcal, 0);
    });

    test('zero elapsed time never divides by zero', () {
      final s = walkStats(
        steps: 0,
        elapsed: Duration.zero,
        strideCm: 72,
        weightGrams: 87000,
      );
      expect(s.kcal, 0);
      expect(formatPace(0, Duration.zero), '—');
    });

    test('an unset weight still yields a distance, and no calorie claim', () {
      // Weight is only known once the user has logged one. Distance does not
      // need it; a calorie figure invented without it would be a lie.
      final s = walkStats(
        steps: 2000,
        elapsed: const Duration(minutes: 20),
        strideCm: 72,
        weightGrams: 0,
      );
      expect(s.metres, 1440);
      expect(s.kcal, 0);
    });
  });

  group('calories', () {
    test('scale with weight', () {
      final light = walkStats(
        steps: 3000,
        elapsed: const Duration(minutes: 30),
        strideCm: 72,
        weightGrams: 70000,
      );
      final heavy = walkStats(
        steps: 3000,
        elapsed: const Duration(minutes: 30),
        strideCm: 72,
        weightGrams: 100000,
      );
      expect(heavy.kcal, greaterThan(light.kcal));
    });

    test('a half-hour walk lands in a believable range', () {
      // 3400 steps, 87 kg, half an hour is roughly 2.4 km at 4.9 km/h. A
      // formula returning 12 or 1200 would be wrong in a way that testing the
      // arithmetic against itself would never catch.
      final s = walkStats(
        steps: 3400,
        elapsed: const Duration(minutes: 30),
        strideCm: 72,
        weightGrams: 87000,
      );
      expect(s.kcal, inInclusiveRange(90, 200));
    });

    test('a brisker walk burns more than a stroll of the same length', () {
      final stroll = walkStats(
        steps: 2000,
        elapsed: const Duration(minutes: 30),
        strideCm: 72,
        weightGrams: 87000,
      );
      final brisk = walkStats(
        steps: 4200,
        elapsed: const Duration(minutes: 30),
        strideCm: 72,
        weightGrams: 87000,
      );
      expect(brisk.kcal, greaterThan(stroll.kcal));
    });
  });

  group('formatting', () {
    test('distance switches unit at a kilometre, in Arabic digits', () {
      expect(formatDistance(450), contains('م'));
      expect(formatDistance(450), isNot(contains('كم')));
      expect(formatDistance(1200), contains('كم'));
      expect(RegExp(r'[0-9]').hasMatch(formatDistance(1200)), isFalse,
          reason: 'numbers are Arabic-Indic throughout the app');
    });

    test('a kilometre exactly reads as kilometres', () {
      expect(formatDistance(1000), contains('كم'));
    });

    test('pace reads as km/h in Arabic digits', () {
      final p = formatPace(2400, const Duration(minutes: 30));
      expect(p, contains('كم/س'));
      expect(RegExp(r'[0-9]').hasMatch(p), isFalse);
    });

    test('a dash rather than a nonsense pace before anything has happened', () {
      expect(formatPace(0, Duration.zero), '—');
      expect(formatPace(500, Duration.zero), '—');
    });

    test('a duration reads as minutes and seconds, in Arabic digits', () {
      expect(formatWalkClock(const Duration(minutes: 12, seconds: 5)), '١٢:٠٥');
      expect(formatWalkClock(Duration.zero), '٠:٠٠');
    });
  });

  group('the session target', () {
    test('progress is elapsed over the target, clamped at one', () {
      expect(walkFraction(const Duration(minutes: 15), 30), 0.5);
      expect(walkFraction(const Duration(minutes: 45), 30), 1.0);
      expect(walkFraction(Duration.zero, 30), 0.0);
    });

    test('a zero target never divides by zero', () {
      expect(walkFraction(const Duration(minutes: 5), 0), 0.0);
    });
  });
}
