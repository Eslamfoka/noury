import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../finance/budget_categories.dart';
import '../finance/finance_providers.dart';
import '../home/home_providers.dart';
import '../steps/walk_session.dart';
import 'body_wealth_summary.dart';

/// The last seven days of البدن and المالية, assembled from local rows.
final bodyWealthSummaryProvider =
    FutureProvider<BodyWealthSummary>((ref) async {
  final db = ref.watch(databaseProvider);
  final today = DateTime.now();
  final from = DateTime(today.year, today.month, today.day - 6);

  // Money is read over the financial month, not the week: a budget is a
  // monthly thing, and "spent this week against a monthly limit" would be a
  // comparison between two different periods.
  final month = ref.watch(currentFinancialMonthProvider).value;

  final walks = await db.stepsDao.between(from, today);
  final workouts = <WorkoutSession>[];
  for (var i = 0; i < 7; i++) {
    workouts.addAll(await db.workoutDao
        .sessionsOn(DateTime(from.year, from.month, from.day + i)));
  }

  final meals = <Meal>[];
  for (var i = 0; i < 7; i++) {
    meals.addAll(
        await db.bodyDao.mealsOn(DateTime(from.year, from.month, from.day + i)));
  }

  final weights = await db.bodyDao.recentWeights();
  final inRange = weights
      .where((w) => !w.at.isBefore(from))
      .toList();

  final expenses = month == null
      ? <Expense>[]
      : await db.financeDao.expensesBetween(month.start, month.end);
  final budgets =
      month == null ? <String, int>{} : await db.financeDao.budgetsFor(month.start);

  return BodyWealthSummary.build(
    walks: walks,
    workouts: workouts,
    meals: meals,
    weights: inRange,
    expenses: expenses,
    budgets: budgets,
  );
});

/// البدن والمالية in the weekly report.
///
/// Added because both pillars had real data and appeared nowhere — walking and
/// workouts especially, which were logged into a screen nobody ever looked
/// back at. Deterministic and local, like the religious summary above it; the
/// cross-pillar reading arrives with the AI layer.
class BodyWealthPanel extends ConsumerWidget {
  const BodyWealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(bodyWealthSummaryProvider);
    final s = summary.value;

    if (s == null || s.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('البدن والمالية',
              style: cairo(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'لسه مفيش تسجيل للأسبوع ده. سجّل مشية أو وجبة أو مصروف '
            'وهيبان هنا.',
            key: const ValueKey('body-wealth-empty'),
            style: cairo(size: 12, color: NouriColors.muted, height: 1.8),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('البدن والمالية',
            style: cairo(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (s.hasBody) ...[
          Row(
            children: [
              Expanded(
                child: _Tile(
                  label: 'مشي',
                  value: s.walkSteps == 0
                      ? '—'
                      : toArabicDigits('${s.walkSteps}'),
                  hint: s.walkSteps == 0
                      ? 'مفيش مشي مسجّل'
                      : toArabicDigits(
                          'خطوة · ${formatDistance(s.walkMetres)}'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _Tile(
                  label: 'تمارين',
                  value: toArabicDigits('${s.exercisesDone}'),
                  hint: toArabicDigits('في ${s.workoutSessions} جلسة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (s.mealsLogged > 0)
            _Row(
              label: 'وجبات مسجّلة',
              value: s.mealsUncomfortable == 0
                  ? toArabicDigits('${s.mealsLogged}')
                  : toArabicDigits(
                      '${s.mealsLogged} · ${s.mealsUncomfortable} مضايقاك'),
            ),
          if (s.latestWeightGrams != null)
            _Row(
              label: 'الوزن',
              value: _weightLine(s),
            ),
          const SizedBox(height: 12),
        ],
        if (s.hasWealth) ...[
          _Row(
            label: 'مصروف الشهر',
            value: s.budgetedFils == 0
                ? formatMoney(s.spentFils)
                : '${formatMoney(s.spentFils)} — '
                    '${formatMoney(s.budgetedFils)}',
          ),
          if (s.budgetFraction != null) ...[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: s.budgetFraction,
                minHeight: 5,
                backgroundColor: NouriColors.surface,
                // attention, never a failure red: going over budget is
                // something to notice, not something to be scolded for.
                valueColor: AlwaysStoppedAnimation(
                  s.spentFils > s.budgetedFils
                      ? NouriColors.attention
                      : NouriColors.gold,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  /// «٨٦٫٤ كجم» plus the week's change when there is more than one reading.
  static String _weightLine(BodyWealthSummary s) {
    final kg = (s.latestWeightGrams! / 1000).toStringAsFixed(1);
    final base = toArabicDigits('${kg.replaceAll('.', '٫')} كجم');

    final change = s.weightChangeGrams;
    if (change == null || change == 0) return base;

    final delta = (change.abs() / 1000).toStringAsFixed(1).replaceAll('.', '٫');
    // Named as down or up in words rather than with a sign, which reads as
    // arithmetic rather than as a week.
    final word = change < 0 ? 'نزلت' : 'زادت';
    return toArabicDigits('$base · $word $delta');
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(value,
              style: cairo(size: 18, weight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 3),
          Text(label,
              style: cairo(size: 11.5, weight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(hint,
              style: cairo(size: 10, color: NouriColors.muted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: cairo(size: 12.5, color: NouriColors.muted)),
            Text(value, style: cairo(size: 12.5, weight: FontWeight.w600)),
          ],
        ),
      );
}
