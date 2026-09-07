import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';

/// Workout sessions started today.
final todayWorkoutsProvider = FutureProvider<List<WorkoutSession>>(
  (ref) => ref
      .watch(databaseProvider)
      .workoutDao
      .sessionsOn(ref.watch(currentDayProvider)),
);

final recentWorkoutsProvider = FutureProvider<List<WorkoutSession>>(
  (ref) => ref.watch(databaseProvider).workoutDao.recentSessions(),
);
