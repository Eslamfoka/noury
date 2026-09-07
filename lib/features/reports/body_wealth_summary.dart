import '../../data/db/nouri_database.dart';

/// The last seven days of the physical and financial pillars.
///
/// A separate type from [WeeklySummary] rather than a widening of it. The
/// religious summary is the oldest, most-tested thing in reports and its
/// meaning is settled; bolting walking and expenses onto it would put three
/// pillars in one object that only ever gets read a third at a time.
///
/// Deterministic and local, like its sibling. No AI, no cross-pillar score —
/// that is Slice 5. This exists so the data the user is already logging stops
/// being invisible.
class BodyWealthSummary {
  const BodyWealthSummary({
    required this.walkSessions,
    required this.walkMinutes,
    required this.walkSteps,
    required this.walkMetres,
    required this.workoutSessions,
    required this.exercisesDone,
    required this.mealsLogged,
    required this.mealsUncomfortable,
    required this.latestWeightGrams,
    required this.weightChangeGrams,
    required this.spentFils,
    required this.budgetedFils,
    required this.knowledgeMinutes,
    required this.knowledgeDays,
  });

  final int walkSessions;
  final int walkMinutes;
  final int walkSteps;
  final int walkMetres;

  final int workoutSessions;

  /// Exercises actually completed, across every session. A partial workout
  /// contributes what it did rather than nothing.
  final int exercisesDone;

  final int mealsLogged;

  /// Meals followed by bloating, pain or gas.
  ///
  /// A count, never a cause. The brief is explicit that Nouri does not name
  /// what caused a symptom — that is for the user and their doctor.
  final int mealsUncomfortable;

  /// Null until a weight has been logged. Not zero: an unknown weight and a
  /// weight of nothing are different things.
  final int? latestWeightGrams;

  /// Change across the week, negative for a loss. Null unless there are at
  /// least two readings — one reading is a point, not a trend.
  final int? weightChangeGrams;

  final int spentFils;

  /// The sum of this month's category limits, or zero when none are set.
  final int budgetedFils;

  /// Minutes of knowledge time across the week, all three kinds together —
  /// the brief treats them as one block, so one total is the honest number.
  final int knowledgeMinutes;

  /// How many days of the week carried any at all. Ten minutes on six days is
  /// a different week from an hour on one, and the total alone hides that.
  final int knowledgeDays;

  bool get hasBody =>
      walkSessions > 0 ||
      workoutSessions > 0 ||
      mealsLogged > 0 ||
      latestWeightGrams != null;

  bool get hasWealth => spentFils > 0 || budgetedFils > 0;

  bool get hasKnowledge => knowledgeMinutes > 0;

  bool get isEmpty => !hasBody && !hasWealth && !hasKnowledge;

  /// How much of the month's budget the week's spending used, or null when no
  /// budget is set. Nouri shows a dash rather than inventing a denominator.
  double? get budgetFraction {
    if (budgetedFils <= 0) return null;
    return (spentFils / budgetedFils).clamp(0.0, 1.0);
  }

  static BodyWealthSummary build({
    required List<WalkSession> walks,
    required List<WorkoutSession> workouts,
    required List<Meal> meals,
    required List<Weight> weights,
    required List<Expense> expenses,
    required Map<String, int> budgets,
    List<KnowledgeLog> knowledge = const [],
  }) {
    // Oldest first, so "change across the week" is last minus first.
    final ordered = [...weights]..sort((a, b) => a.at.compareTo(b.at));

    return BodyWealthSummary(
      walkSessions: walks.length,
      walkMinutes: walks.fold(0, (a, w) => a + w.seconds) ~/ 60,
      walkSteps: walks.fold(0, (a, w) => a + w.steps),
      walkMetres: walks.fold(0, (a, w) => a + w.metres),
      workoutSessions: workouts.length,
      exercisesDone: workouts.fold(0, (a, w) => a + w.doneCount),
      mealsLogged: meals.length,
      mealsUncomfortable:
          meals.where((m) => m.feeling != MealFeeling.good).length,
      latestWeightGrams: ordered.isEmpty ? null : ordered.last.grams,
      weightChangeGrams: ordered.length < 2
          ? null
          : ordered.last.grams - ordered.first.grams,
      spentFils: expenses.fold(0, (a, e) => a + e.amountFils),
      budgetedFils: budgets.values.fold(0, (a, v) => a + v),
      knowledgeMinutes: knowledge.fold(0, (a, k) => a + k.minutes),
      knowledgeDays:
          knowledge.map((k) => dayOf(k.date)).toSet().length,
    );
  }
}
