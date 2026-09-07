import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/home/home_providers.dart';
import 'package:nouri/features/steps/step_source.dart';
import 'package:nouri/features/steps/steps_providers.dart';
import 'package:nouri/features/steps/walk_screen.dart';

import '../../support/harness.dart';

/// A source that emits exactly what a test tells it to, when it tells it.
///
/// Not [SimulatedStepSource]: that one runs on a real timer, and a widget test
/// that waited on wall-clock time would be slow and flaky. This gives the test
/// the pump-by-pump control it needs.
class ScriptedStepSource implements StepSource {
  ScriptedStepSource({this.available = true});

  final bool available;
  final _controller = StreamController<int>.broadcast();

  void emit(int cumulative) => _controller.add(cumulative);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Stream<int> cumulativeSteps() => _controller.stream;

  @override
  void dispose() => _controller.close();
}

void main() {
  late NouriDatabase db;
  late ScriptedStepSource source;

  Future<void> pump(WidgetTester t, {bool sensor = true}) async {
    source = ScriptedStepSource(available: sensor);
    addTearDown(source.dispose);

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          stepSourceProvider.overrideWithValue(source),
        ],
        child: testShell(const WalkScreen()),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('offers the four session lengths', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      for (final m in [15, 30, 45, 60]) {
        expect(find.byKey(ValueKey('walk-target-$m')), findsOneWidget);
      }
    });
  });

  testWidgets('with no sensor it says so and offers no start button',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t, sensor: false);

      expect(find.byKey(const ValueKey('no-step-sensor')), findsOneWidget);
      expect(find.byKey(const ValueKey('walk-start')), findsNothing);
      expect(find.byKey(const ValueKey('walk-start-simulated')), findsNothing,
          reason: 'simulation is off by default and must stay opt-in');
    });
  });

  testWidgets('with no sensor but simulation allowed, it offers a labelled try',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.settingsDao
          .update(const SettingsRowsCompanion(allowSimulatedSteps: Value(true)));
      await pump(t, sensor: false);

      expect(find.byKey(const ValueKey('walk-start-simulated')), findsOneWidget);
      expect(find.textContaining('تجريبية'), findsWidgets,
          reason: 'simulated numbers must never look like real ones');
    });
  });

  testWidgets('counts steps from the session start, not from boot', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('walk-start')));
      await t.pumpAndSettle();

      // The phone had already walked 8000 steps today before the session.
      source.emit(8000);
      await t.pumpAndSettle();
      expect(find.text('٠'), findsOneWidget,
          reason: 'the first reading is the baseline, not 8000 steps taken');

      source.emit(8120);
      await t.pumpAndSettle();
      expect(find.text('١٢٠'), findsOneWidget);
    });
  });

  testWidgets('a reboot mid-session shows zero rather than a negative count',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('walk-start')));
      await t.pumpAndSettle();
      source.emit(8000);
      await t.pumpAndSettle();

      // TYPE_STEP_COUNTER resets to zero on reboot.
      source.emit(12);
      await t.pumpAndSettle();
      expect(find.text('٠'), findsOneWidget);
    });
  });

  testWidgets('finishing persists the session, including a short one',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.bodyDao.addWeight(at: DateTime.now(), grams: 87000);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('walk-target-30')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('walk-start')));
      await t.pumpAndSettle();

      source.emit(1000);
      source.emit(1500);
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('walk-finish')));
      await t.pumpAndSettle();

      final rows = await db.stepsDao.sessionsOn(DateTime.now());
      expect(rows, hasLength(1));
      expect(rows.single.steps, 500);
      expect(rows.single.targetMinutes, 30);
      expect(rows.single.metres, 360, reason: '500 steps at a 72 cm stride');
    });
  });

  testWidgets('shows a dash for calories until a weight is known', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('walk-start')));
      await t.pumpAndSettle();
      source.emit(1000);
      source.emit(2000);
      await t.pumpAndSettle();

      expect(find.text('—'), findsWidgets);
      expect(find.textContaining('سجّل وزنك في البدن'), findsOneWidget,
          reason: 'say why the number is missing rather than inventing one');
    });
  });

  testWidgets('pausing is reversible and never loses the count', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('walk-start')));
      await t.pumpAndSettle();
      source.emit(100);
      source.emit(250);
      await t.pumpAndSettle();
      expect(find.text('١٥٠'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('walk-pause')));
      await t.pumpAndSettle();
      expect(find.text('كمّل'), findsOneWidget);
      expect(find.text('١٥٠'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('walk-pause')));
      await t.pumpAndSettle();
      expect(find.text('وقّف شوية'), findsOneWidget);
    });
  });

  testWidgets("today's walking is summarised before a new session", (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.stepsDao.addSession(
        startedAt: DateTime.now(),
        seconds: 1800,
        steps: 3400,
        metres: 2448,
        kcal: 122,
        targetMinutes: 30,
      );
      await pump(t);

      expect(find.byKey(const ValueKey('walk-today-total')), findsOneWidget);
      expect(find.textContaining('٣٤٠٠'), findsOneWidget);
    });
  });
}
