import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import '../settings/settings_controller.dart';
import '../settings/settings_screen.dart';
import 'budget_categories.dart';
import 'financial_month.dart';

/// The financial month containing today.
///
/// Starts on payday, not the 1st — see [FinancialMonth]. The start day is a
/// setting because the brief says the salary lands somewhere between the 20th
/// and the 25th.
final currentFinancialMonthProvider = Provider<AsyncValue<FinancialMonth>>(
  (ref) => ref.watch(settingsProvider).whenData(
        (s) => FinancialMonth.containing(
          DateTime.now(),
          startDay: s.financialMonthStartDay,
        ),
      ),
);

final monthExpensesProvider = FutureProvider<List<Expense>>((ref) async {
  final month = ref.watch(currentFinancialMonthProvider).value;
  if (month == null) return const [];
  return ref
      .watch(databaseProvider)
      .financeDao
      .expensesBetween(month.start, month.end);
});

final monthSpendByCategoryProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final month = ref.watch(currentFinancialMonthProvider).value;
  if (month == null) return const {};
  return ref
      .watch(databaseProvider)
      .financeDao
      .spendByCategory(month.start, month.end);
});

final monthBudgetsProvider = FutureProvider<Map<String, int>>((ref) async {
  final month = ref.watch(currentFinancialMonthProvider).value;
  if (month == null) return const {};
  return ref.watch(databaseProvider).financeDao.budgetsFor(month.start);
});

/// Total spent this cycle, in fils.
final monthTotalSpentProvider = Provider<int>((ref) {
  final spend = ref.watch(monthSpendByCategoryProvider).value ?? const {};
  return spend.values.fold(0, (a, b) => a + b);
});

/// What is left after every budget, and what share of income that is.
///
/// The brief asks for a real savings rate derived from actual logged budgets
/// rather than an aspirational number.
class SavingsSnapshot {
  const SavingsSnapshot({
    required this.incomeFils,
    required this.budgetedFils,
    required this.spentFils,
  });

  final int incomeFils;
  final int budgetedFils;
  final int spentFils;

  int get projectedSavings => incomeFils - budgetedFils;
  int get actualSoFar => incomeFils - spentFils;

  /// Null when income has not been set — Nouri shows a dash rather than
  /// inventing a rate.
  double? get projectedRate =>
      incomeFils <= 0 ? null : projectedSavings / incomeFils;
}

final savingsSnapshotProvider = Provider<SavingsSnapshot>((ref) {
  final income = ref.watch(settingsProvider).value?.monthlyIncomeFils ?? 0;
  final budgets = ref.watch(monthBudgetsProvider).value ?? const {};
  return SavingsSnapshot(
    incomeFils: income,
    budgetedFils: budgets.values.fold(0, (a, b) => a + b),
    spentFils: ref.watch(monthTotalSpentProvider),
  );
});

/// Budget status per category, for the cycle so far.
final budgetStatusesProvider =
    Provider<Map<BudgetCategory, BudgetStatus>>((ref) {
  final month = ref.watch(currentFinancialMonthProvider).value;
  if (month == null) return const {};

  final budgets = ref.watch(monthBudgetsProvider).value ?? const {};
  final spend = ref.watch(monthSpendByCategoryProvider).value ?? const {};
  final now = DateTime.now();

  return {
    for (final c in BudgetCategory.values)
      if ((budgets[c.name] ?? 0) > 0 || (spend[c.name] ?? 0) > 0)
        c: BudgetStatus(
          limit: budgets[c.name] ?? 0,
          spent: spend[c.name] ?? 0,
          month: month,
          now: now,
        ),
  };
});

/// The settings controller, reachable from the finance screens.
///
/// Separate name from `settingsControllerProvider` only to keep the finance
/// feature's imports explicit about what it reaches for.
final settingsControllerForFinanceProvider =
    Provider<SettingsController>((ref) => ref.watch(settingsControllerProvider));
