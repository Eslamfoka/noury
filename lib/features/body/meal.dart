import '../../data/db/tables.dart';

export '../../data/db/tables.dart' show MealFeeling;

/// Presentation and reading of [MealFeeling].
///
/// The enum itself lives in `tables.dart` because drift stores it by index,
/// the same arrangement as [PrayerState] and its scoring.
extension MealFeelingLabel on MealFeeling {
  String get arabicLabel => switch (this) {
        MealFeeling.good => 'كويس',
        MealFeeling.bloating => 'انتفاخ',
        MealFeeling.pain => 'ألم',
        MealFeeling.gas => 'غازات',
      };

  /// True for anything the user might want to show a doctor.
  ///
  /// Not "bad". Nouri does not grade meals, and a symptom is information
  /// rather than a failure.
  bool get isSymptom => this != MealFeeling.good;
}

/// The order the choices are offered in, best first.
const mealFeelings = <MealFeeling>[
  MealFeeling.good,
  MealFeeling.bloating,
  MealFeeling.pain,
  MealFeeling.gas,
];

/// A plain, non-diagnostic reading of the last [total] meals.
///
/// Deliberately descriptive. It counts what was logged and stops there:
/// «٣ من آخر ٧ وجبات بعدها انتفاخ» is an observation the user can take to a
/// doctor. Naming a cause, or a food to avoid, would be diagnosing — which
/// §1.5 of the brief rules out and which Nouri is not competent to do.
class MealPattern {
  const MealPattern({required this.total, required this.withSymptoms});

  final int total;
  final int withSymptoms;

  bool get hasEnoughToSay => total >= 3;
  bool get anySymptoms => withSymptoms > 0;
}

MealPattern patternFrom(Iterable<MealFeeling> recent) {
  final list = recent.toList();
  return MealPattern(
    total: list.length,
    withSymptoms: list.where((f) => f.isSymptom).length,
  );
}
