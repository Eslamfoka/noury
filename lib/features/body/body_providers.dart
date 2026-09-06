import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import 'fasting_window.dart';
import 'meal.dart';

/// Where today sits in the eating/fasting cycle.
///
/// Uses the coarse clock: the phase changes twice a day, so a per-second tick
/// would be pure waste.
final fastingWindowProvider = Provider<FastingWindow>((ref) {
  final startHour =
      ref.watch(settingsProvider).value?.eatingWindowStartHour ?? 12;
  final now = ref.watch(coarseClockProvider).value ?? DateTime.now();
  return FastingWindow.at(now, startHour: startHour);
});

final todayMealsProvider = FutureProvider<List<Meal>>(
  (ref) => ref.watch(databaseProvider).bodyDao.mealsOn(DateTime.now()),
);

final recentMealsProvider = FutureProvider<List<Meal>>(
  (ref) => ref.watch(databaseProvider).bodyDao.recentMeals(),
);

/// A descriptive reading of the last few meals.
///
/// Never a diagnosis — see [MealPattern].
final mealPatternProvider = Provider<MealPattern>((ref) {
  final meals = ref.watch(recentMealsProvider).value ?? const [];
  return patternFrom(meals.map((m) => m.feeling));
});

final latestWeightProvider = FutureProvider<Weight?>(
  (ref) => ref.watch(databaseProvider).bodyDao.latestWeight(),
);

/// Grams still to go, or null when there is no reading to measure from.
///
/// Returns null rather than zero when the target is met or passed: Nouri has
/// nothing to nag about at that point.
final weightToGoProvider = Provider<int?>((ref) {
  final latest = ref.watch(latestWeightProvider).value;
  final target = ref.watch(settingsProvider).value?.targetWeightGrams ?? 74000;
  if (latest == null) return null;
  final diff = latest.grams - target;
  return diff > 0 ? diff : null;
});

/// Weight formatted the way a bathroom scale reads: «٨٧٫٤ كجم».
String formatWeight(int grams) {
  final kg = grams ~/ 1000;
  final hundreds = (grams % 1000) ~/ 100;
  return '$kg٫$hundreds كجم'
      .replaceAllMapped(RegExp('[0-9]'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);
}

/// Parses a weight typed as kilograms into grams.
///
/// Accepts Arabic-Indic digits and both decimal separators, like the money
/// parser. Returns null on nonsense rather than throwing — a typo in a number
/// field is an ordinary event.
int? parseWeightKg(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;

  const arabic = '٠١٢٣٤٥٦٧٨٩';
  s = s.split('').map((c) {
    final i = arabic.indexOf(c);
    return i == -1 ? c : '$i';
  }).join();
  s = s.replaceAll('٫', '.').replaceAll(',', '.');

  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) return null;

  final parts = s.split('.');
  final kg = int.tryParse(parts[0]);
  if (kg == null) return null;

  var frac = parts.length > 1 ? parts[1] : '';
  // "87.4" is 87.4 kg, not 87 kg and 4 g.
  frac = frac.padRight(3, '0').substring(0, 3);

  final grams = kg * 1000 + int.parse(frac);
  // A human weight. Anything outside this is a typo, not a reading.
  if (grams < 20000 || grams > 400000) return null;
  return grams;
}

/// Meals hidden from the list the instant they are swiped away.
///
/// Same reason as the expense list: Dismissible requires its child to leave
/// the tree as soon as the animation ends, but deleting the row and refreshing
/// the query is async. Hiding is synchronous, so the list rebuilds without the
/// row in the same frame.
class HiddenMeals extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void hide(int id) => state = {...state, id};
}

final hiddenMealsProvider =
    NotifierProvider<HiddenMeals, Set<int>>(HiddenMeals.new);
