import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import 'sensor_step_source.dart';
import 'step_source.dart';

/// The step source the walk screen will use.
///
/// Overridden in tests with a [SimulatedStepSource]. In the app it is the real
/// sensor; whether that sensor exists is a separate question the screen asks
/// through [stepSensorAvailableProvider], because the answer changes what the
/// screen is allowed to offer.
final stepSourceProvider = Provider<StepSource>((ref) {
  final source = SensorStepSource();
  ref.onDispose(source.dispose);
  return source;
});

final stepSensorAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(stepSourceProvider).isAvailable(),
);

/// Today's walking sessions.
final todayWalksProvider = FutureProvider<List<WalkSession>>(
  (ref) => ref
      .watch(databaseProvider)
      .stepsDao
      .sessionsOn(ref.watch(currentDayProvider)),
);

/// Today's total steps across every session.
final todayStepsProvider = FutureProvider<int>(
  (ref) => ref
      .watch(databaseProvider)
      .stepsDao
      .stepsOn(ref.watch(currentDayProvider)),
);

final recentWalksProvider = FutureProvider<List<WalkSession>>(
  (ref) => ref.watch(databaseProvider).stepsDao.recentSessions(),
);

/// The user's latest weight in grams, or zero when none has been logged.
///
/// Zero is meaningful here rather than a placeholder: it is what stops the
/// calorie estimate from being computed against a weight nobody entered.
final latestWeightGramsProvider = FutureProvider<int>((ref) async {
  final w = await ref.watch(databaseProvider).bodyDao.latestWeight();
  return w?.grams ?? 0;
});
