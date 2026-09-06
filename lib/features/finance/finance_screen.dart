import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../shared/nouri_avatar.dart';
import 'add_expense_sheet.dart';
import 'budget_editor_sheet.dart';
import 'budget_categories.dart';
import 'finance_providers.dart';
import 'financial_month.dart';

/// المالية — the wealth pillar.
///
/// Deliberately shows the cycle the user actually lives in: from payday to the
/// day before the next, not the calendar month. Everything stays on-device.
class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(currentFinancialMonthProvider).value;
    if (month == null) {
      return const Center(
        child: CircularProgressIndicator(color: NouriColors.gold),
      );
    }

    final statuses = ref.watch(budgetStatusesProvider);
    final savings = ref.watch(savingsSnapshotProvider);
    final spent = ref.watch(monthTotalSpentProvider);
    final expenses = ref.watch(monthExpensesProvider).value ?? const [];
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: NouriColors.gold,
        foregroundColor: NouriColors.background,
        onPressed: () => showAddExpenseSheet(context, ref),
        icon: const Icon(Icons.add, size: 20),
        label: Text('سجّل مصروف',
            style: cairo(
              size: 13.5,
              weight: FontWeight.w700,
              color: NouriColors.background,
            )),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(15, 18, 15, 90),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('المالية',
                      style: cairo(size: 17, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(month.label,
                      style: cairo(size: 11.5, color: NouriColors.muted)),
                ],
              ),
              const NouriAvatar(size: 36),
            ],
          ),
          const SizedBox(height: 18),

          _CycleCard(month: month, now: now, spent: spent, savings: savings),
          const SizedBox(height: 18),

          Row(
            children: [
              Text('البنود', style: cairo(size: 14, weight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () => showBudgetEditorSheet(context, ref),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('عدّل الميزانية',
                    style: cairo(size: 12, color: NouriColors.gold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (statuses.isEmpty)
            const _NoBudgetsYet()
          else ...[
            for (final entry in statuses.entries)
              _CategoryRow(category: entry.key, status: entry.value),
          ],

          if (expenses.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('آخر المصاريف',
                style: cairo(size: 14, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            for (final e in expenses.take(8)) _ExpenseRow(expense: e),
          ],

          const SizedBox(height: 20),
          Text(
            'نوري مش مستشار مالي. ده إطار للانضباط، مش نصيحة استثمار. '
            'وكل الأرقام محفوظة على الجهاز ده بس.',
            style: cairo(size: 11, color: NouriColors.muted, height: 1.8),
          ),
        ],
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.month,
    required this.now,
    required this.spent,
    required this.savings,
  });

  final FinancialMonth month;
  final DateTime now;
  final int spent;
  final SavingsSnapshot savings;

  @override
  Widget build(BuildContext context) {
    final remaining = month.daysRemaining(now);
    final rate = savings.projectedRate;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NouriColors.surfaceActive,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NouriColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اتصرف الشهر ده',
              style: cairo(size: 11.5, color: NouriColors.muted)),
          const SizedBox(height: 6),
          Text(formatMoney(spent),
              style: cairo(size: 28, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 11),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: NouriColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Metric(
                  label: 'باقي في الشهر',
                  value: toArabicDigits('$remaining يوم'),
                ),
                _Metric(
                  label: 'نسبة الادخار',
                  value: rate == null
                      ? '—'
                      : toArabicDigits('${(rate * 100).round()}٪'),
                  accent: rate == null ? null : NouriColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: cairo(size: 10.5, color: NouriColors.muted)),
          const SizedBox(height: 3),
          Text(value,
              style: cairo(
                size: 15,
                weight: FontWeight.w700,
                color: accent ?? NouriColors.text,
              )),
        ],
      );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.status});

  final BudgetCategory category;
  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    // Warm orange for attention, never red — the same rule as prayers. Being
    // over budget is information, not a scolding.
    final bar = status.isOver
        ? NouriColors.attention
        : status.isAheadOfPace
            ? NouriColors.gold
            : NouriColors.success;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: NouriColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(category.arabicLabel,
                      style: cairo(size: 13.5, weight: FontWeight.w600)),
                ),
                Text(
                  status.limit > 0
                      ? '${formatMoney(status.spent)} / ${formatMoney(status.limit)}'
                      : formatMoney(status.spent),
                  style: cairo(size: 11.5, color: NouriColors.muted),
                ),
              ],
            ),
            if (status.limit > 0) ...[
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: status.fraction,
                  minHeight: 4,
                  backgroundColor: NouriColors.background,
                  valueColor: AlwaysStoppedAnimation(bar),
                ),
              ),
              if (status.isOver || status.isAheadOfPace) ...[
                const SizedBox(height: 7),
                Text(
                  status.isOver
                      ? 'عدّى البند بـ ${formatMoney(-status.remaining)}'
                      : 'ماشي أسرع من باقي الشهر شوية',
                  style: cairo(size: 10.5, color: bar),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  const _ExpenseRow({required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final category = categoryFromName(expense.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(category?.arabicLabel ?? expense.category,
                    style: cairo(size: 13)),
                if (expense.note != null && expense.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(expense.note!,
                      style: cairo(size: 10.5, color: NouriColors.muted)),
                ],
              ],
            ),
          ),
          Text(formatMoney(expense.amountFils),
              style: cairo(size: 13, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _NoBudgetsYet extends StatelessWidget {
  const _NoBudgetsYet();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NouriColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'لسه مفيش بنود ولا مصاريف الشهر ده. ابدأ بتسجيل أول مصروف، '
          'ونوري هيبدأ يوريك بيروح فين.',
          style: cairo(size: 12.5, color: NouriColors.muted, height: 1.85),
        ),
      );
}
