import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/workouts/exercise_animation.dart';
import 'package:nouri/features/workouts/workout_catalogue.dart';
import 'package:nouri/features/workouts/workout_screen.dart';

import '../../support/harness.dart';

void main() {
  late NouriDatabase db;

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(testApp(db: db, child: const WorkoutScreen()));
    await t.pumpAndSettle();
  }

  testWidgets('lists every routine with its length', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      for (final r in kRoutines) {
        expect(find.byKey(ValueKey('routine-${r.id}')), findsOneWidget);
      }
      expect(find.text('الجسم كامل'), findsOneWidget);
      expect(find.textContaining('٢٠ تمرين'), findsOneWidget);
    });
  });

  testWidgets('starting a routine shows the first exercise and its cue',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('routine-quick-home')));
      await t.pump();

      expect(find.byKey(const ValueKey('workout-exercise-name')),
          findsOneWidget);
      expect(find.text(kQuickHome.exercises.first.nameAr), findsOneWidget);
      expect(find.text(kQuickHome.exercises.first.cueAr), findsOneWidget,
          reason: 'a home workout with no coaching is how backs get hurt');
      expect(find.byType(ExerciseAnimation), findsWidgets);
    });
  });

  testWidgets('the progress line reads «٥ من ٢٠ — ٢٥٪» after five', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('routine-full-body')));
      await t.pump();

      for (var i = 0; i < 5; i++) {
        await t.tap(find.byKey(const ValueKey('workout-skip')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('workout-skip')));
        await t.pump();
      }

      expect(find.text('٥ من ٢٠ — ٢٥٪'), findsOneWidget);
    });
  });

  testWidgets('a rest names the exercise it is leading into', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('routine-quick-home')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('workout-skip')));
      await t.pump();

      expect(find.byKey(const ValueKey('workout-rest')), findsOneWidget);
      expect(find.textContaining(kQuickHome.exercises[1].nameAr),
          findsOneWidget);
    });
  });

  testWidgets('pausing is reversible', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('routine-warm-up')));
      await t.pump();

      await t.tap(find.byKey(const ValueKey('workout-pause')));
      await t.pump();
      expect(find.text('كمّل'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('workout-pause')));
      await t.pump();
      expect(find.text('وقّف'), findsOneWidget);
    });
  });

  testWidgets('finishing early still records the work done', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('routine-full-body')));
      await t.pump();

      for (var i = 0; i < 5; i++) {
        await t.tap(find.byKey(const ValueKey('workout-skip')));
        await t.pump();
        await t.tap(find.byKey(const ValueKey('workout-skip')));
        await t.pump();
      }

      await t.tap(find.byKey(const ValueKey('workout-finish')));
      await t.pumpAndSettle();

      final rows = await db.workoutDao.sessionsOn(DateTime.now());
      expect(rows, hasLength(1));
      expect(rows.single.doneCount, 5,
          reason: 'five of twenty is real work, not nothing');
      expect(rows.single.totalCount, 20);
      expect(rows.single.routineId, 'full-body');
    });
  });

  testWidgets('running a whole routine to the end records it once', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('routine-warm-up')));
      await t.pump();

      // Five exercises, four rests. Skipping past the last exercise finishes.
      for (var i = 0; i < 9; i++) {
        final skip = find.byKey(const ValueKey('workout-skip'));
        if (skip.evaluate().isEmpty) break;
        await t.tap(skip);
        await t.pumpAndSettle();
      }

      final rows = await db.workoutDao.sessionsOn(DateTime.now());
      expect(rows, hasLength(1));
      expect(rows.single.doneCount, 5);
      expect(rows.single.totalCount, 5);
    });
  });

  testWidgets('a double tap on «كفاية» records one session, not two',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('routine-warm-up')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('workout-skip')));
      await t.pump();

      final finish = find.byKey(const ValueKey('workout-finish'));
      await t.tap(finish);
      await t.tap(finish, warnIfMissed: false);
      await t.pumpAndSettle();

      expect(await db.workoutDao.recentSessions(), hasLength(1));
    });
  });

  testWidgets('skipping the last exercise then tapping «كفاية» records once',
      (t) async {
    // The narrower race: finishing the routine kicks off a save, and the user
    // hits the button while it is still in flight.
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('routine-warm-up')));
      await t.pump();

      for (var i = 0; i < 9; i++) {
        final skip = find.byKey(const ValueKey('workout-skip'));
        if (skip.evaluate().isEmpty) break;
        await t.tap(skip);
        await t.pump();
      }

      final finish = find.byKey(const ValueKey('workout-finish'));
      if (finish.evaluate().isNotEmpty) {
        await t.tap(finish, warnIfMissed: false);
      }
      await t.pumpAndSettle();

      expect(await db.workoutDao.recentSessions(), hasLength(1));
    });
  });

  testWidgets('past sessions are listed on the picker', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.workoutDao.addSession(
        startedAt: DateTime.now(),
        routineId: 'quick-home',
        doneCount: 6,
        totalCount: 8,
        seconds: 400,
      );
      await pump(t);

      expect(find.text('آخر تمارينك'), findsOneWidget);
      expect(find.text('٦ من ٨'), findsOneWidget);
    });
  });
}
