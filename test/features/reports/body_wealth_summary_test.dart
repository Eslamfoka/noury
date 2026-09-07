import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/reports/body_wealth_summary.dart';

WalkSession walk(int day, {int minutes = 30, int steps = 3400}) => WalkSession(
      id: day,
      startedAt: DateTime(2026, 9, day, 18),
      seconds: minutes * 60,
      steps: steps,
      metres: (steps * 72) ~/ 100,
      kcal: 120,
      targetMinutes: 30,
    );

WorkoutSession workout(int day, {int done = 8, int total = 8}) =>
    WorkoutSession(
      id: day,
      startedAt: DateTime(2026, 9, day, 19),
      routineId: 'quick-home',
      doneCount: done,
      totalCount: total,
      seconds: 450,
    );

Meal meal(int day, MealFeeling feeling) => Meal(
      id: day * 10 + feeling.index,
      at: DateTime(2026, 9, day, 13),
      feeling: feeling,
    );

Weight weight(int day, int grams) =>
    Weight(id: day, at: DateTime(2026, 9, day, 7), grams: grams);

Expense expense(int day, int fils) => Expense(
      id: day,
      date: DateTime(2026, 9, day),
      category: 'food',
      amountFils: fils,
    );

KnowledgeLog knowledge(int day, {int minutes = 30}) => KnowledgeLog(
      id: day,
      date: DateTime(2026, 9, day),
      kind: KnowledgeKind.reading,
      minutes: minutes,
      loggedAt: DateTime(2026, 9, day, 20),
    );

BodyWealthSummary build({
  List<WalkSession> walks = const [],
  List<WorkoutSession> workouts = const [],
  List<Meal> meals = const [],
  List<Weight> weights = const [],
  List<Expense> expenses = const [],
  Map<String, int> budgets = const {},
  List<KnowledgeLog> knowledgeLogs = const [],
}) =>
    BodyWealthSummary.build(
      walks: walks,
      workouts: workouts,
      meals: meals,
      weights: weights,
      expenses: expenses,
      budgets: budgets,
      knowledge: knowledgeLogs,
    );

void main() {
  test('an empty week says so rather than showing zeroes everywhere', () {
    final s = build();
    expect(s.isEmpty, isTrue);
    expect(s.hasBody, isFalse);
    expect(s.hasWealth, isFalse);
    expect(s.latestWeightGrams, isNull);
    expect(s.weightChangeGrams, isNull);
    expect(s.budgetFraction, isNull);
  });

  group('walking', () {
    test('totals sessions, minutes, steps and distance', () {
      final s = build(walks: [
        walk(1, minutes: 30, steps: 3400),
        walk(2, minutes: 12, steps: 1000),
      ]);
      expect(s.walkSessions, 2);
      expect(s.walkMinutes, 42);
      expect(s.walkSteps, 4400);
      expect(s.walkMetres, (3400 * 72) ~/ 100 + (1000 * 72) ~/ 100);
    });

    test('a walk of under a minute still counts as a session', () {
      final s = build(walks: [walk(1, minutes: 0, steps: 20)]);
      expect(s.walkSessions, 1);
      expect(s.walkMinutes, 0);
      expect(s.hasBody, isTrue);
    });
  });

  group('workouts', () {
    test('a partial session contributes what it did', () {
      final s = build(workouts: [workout(1, done: 5, total: 20)]);
      expect(s.workoutSessions, 1);
      expect(s.exercisesDone, 5,
          reason: 'five of twenty is five, not nothing and not twenty');
    });
  });

  group('meals', () {
    test('counts the uncomfortable ones without naming a cause', () {
      final s = build(meals: [
        meal(1, MealFeeling.good),
        meal(2, MealFeeling.bloating),
        meal(3, MealFeeling.pain),
        meal(4, MealFeeling.gas),
      ]);
      expect(s.mealsLogged, 4);
      expect(s.mealsUncomfortable, 3);
    });

    test('a good week is zero uncomfortable, not an absent count', () {
      final s = build(meals: [meal(1, MealFeeling.good)]);
      expect(s.mealsLogged, 1);
      expect(s.mealsUncomfortable, 0);
    });
  });

  group('weight', () {
    test('one reading is a point, not a trend', () {
      final s = build(weights: [weight(1, 87000)]);
      expect(s.latestWeightGrams, 87000);
      expect(s.weightChangeGrams, isNull);
    });

    test('a loss across the week is negative', () {
      final s = build(weights: [weight(1, 87000), weight(6, 86400)]);
      expect(s.latestWeightGrams, 86400);
      expect(s.weightChangeGrams, -600);
    });

    test('readings out of order are still oldest-to-newest', () {
      // The DAO returns newest first; the summary must not depend on that.
      final s = build(weights: [weight(6, 86400), weight(1, 87000)]);
      expect(s.latestWeightGrams, 86400);
      expect(s.weightChangeGrams, -600);
    });
  });

  group('money', () {
    test('sums the week and the month budget', () {
      final s = build(
        expenses: [expense(1, 3500), expense(2, 1250)],
        budgets: {'food': 60000, 'transport': 20000},
      );
      expect(s.spentFils, 4750);
      expect(s.budgetedFils, 80000);
      expect(s.budgetFraction, closeTo(4750 / 80000, 1e-9));
    });

    test('no budget means a dash, never an invented denominator', () {
      final s = build(expenses: [expense(1, 3500)]);
      expect(s.budgetedFils, 0);
      expect(s.budgetFraction, isNull);
      expect(s.hasWealth, isTrue);
    });

    test('overspending clamps the bar rather than overflowing it', () {
      final s = build(
        expenses: [expense(1, 90000)],
        budgets: {'food': 60000},
      );
      expect(s.budgetFraction, 1.0);
      expect(s.spentFils, 90000, reason: 'the number itself stays honest');
    });
  });

  group('knowledge time', () {
    test('totals the minutes and counts the days they fell on', () {
      // Ten minutes on six days is a different week from an hour on one, and
      // the total alone hides that.
      final s = build(knowledgeLogs: [
        knowledge(1, minutes: 30),
        knowledge(1, minutes: 15),
        knowledge(3, minutes: 20),
      ]);
      expect(s.knowledgeMinutes, 65);
      expect(s.knowledgeDays, 2);
      expect(s.hasKnowledge, isTrue);
    });

    test('a week with none is not knowledge, and not an error', () {
      final s = build();
      expect(s.knowledgeMinutes, 0);
      expect(s.hasKnowledge, isFalse);
    });

    test('a knowledge-only week is not empty', () {
      final s = build(knowledgeLogs: [knowledge(1)]);
      expect(s.isEmpty, isFalse);
      expect(s.hasBody, isFalse);
      expect(s.hasWealth, isFalse);
    });
  });

  test('a body-only week has no wealth section, and the reverse', () {
    expect(build(walks: [walk(1)]).hasBody, isTrue);
    expect(build(walks: [walk(1)]).hasWealth, isFalse);
    expect(build(expenses: [expense(1, 100)]).hasBody, isFalse);
    expect(build(expenses: [expense(1, 100)]).hasWealth, isTrue);
  });
}
