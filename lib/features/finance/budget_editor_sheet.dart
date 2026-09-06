import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../home/home_providers.dart';
import 'budget_categories.dart';
import 'finance_providers.dart';

/// Sets the monthly limit for each category.
///
/// Budgets are stored against the financial month's start date, so changing
/// this month's food budget never rewrites last month's history — the report
/// for a past cycle still shows the limit that was actually in force.
Future<void> showBudgetEditorSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NouriColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _BudgetEditor(parentRef: ref),
    ),
  );
}

class _BudgetEditor extends ConsumerStatefulWidget {
  const _BudgetEditor({required this.parentRef});

  final WidgetRef parentRef;

  @override
  ConsumerState<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<_BudgetEditor> {
  final _controllers = <BudgetCategory, TextEditingController>{};
  final _income = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _income.dispose();
    super.dispose();
  }

  void _prefill(Map<String, int> budgets, int incomeFils) {
    if (_loaded) return;
    for (final c in BudgetCategory.values) {
      final existing = budgets[c.name] ?? 0;
      _controllers[c] = TextEditingController(
        text: existing == 0 ? '' : _plain(existing),
      );
    }
    if (incomeFils > 0) _income.text = _plain(incomeFils);
    _loaded = true;
  }

  /// Editable form of an amount: "12.500", no currency, western digits so the
  /// numeric keyboard behaves.
  String _plain(int fils) {
    final whole = fils ~/ 1000;
    final part = fils % 1000;
    return part == 0 ? '$whole' : '$whole.${part.toString().padLeft(3, '0')}';
  }

  Future<void> _save() async {
    final month = ref.read(currentFinancialMonthProvider).value;
    if (month == null) return;

    final db = widget.parentRef.read(databaseProvider);

    for (final entry in _controllers.entries) {
      final fils = parseMoney(entry.value.text) ?? 0;
      await db.financeDao.setBudget(
        monthStart: month.start,
        category: entry.key.name,
        limitFils: fils,
      );
    }

    final income = parseMoney(_income.text) ?? 0;
    await widget.parentRef
        .read(settingsControllerForFinanceProvider)
        .updateMonthlyIncome(income);

    widget.parentRef.invalidate(monthBudgetsProvider);
    widget.parentRef.invalidate(settingsProvider);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(monthBudgetsProvider).value;
    final settings = ref.watch(settingsProvider).value;
    if (budgets == null || settings == null) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: NouriColors.gold),
        ),
      );
    }
    _prefill(budgets, settings.monthlyIncomeFils);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: NouriColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('ميزانية الشهر',
                  style: cairo(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'سيب أي بند فاضي لو مش عايز تحدّد له سقف.',
                style: cairo(size: 11.5, color: NouriColors.muted),
              ),
              const SizedBox(height: 16),

              _Field(label: 'الدخل الشهري', controller: _income),
              const SizedBox(height: 6),
              const Divider(color: NouriColors.border, height: 24),

              for (final c in BudgetCategory.values)
                _Field(label: c.arabicLabel, controller: _controllers[c]!),

              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: NouriColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _save,
                child: Text('احفظ',
                    style: cairo(
                      size: 16,
                      weight: FontWeight.w700,
                      color: NouriColors.background,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label, style: cairo(size: 13.5))),
            SizedBox(
              width: 110,
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.٫]')),
                ],
                textAlign: TextAlign.center,
                style: cairo(size: 14, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '—',
                  hintStyle: cairo(size: 14, color: NouriColors.border),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  filled: true,
                  fillColor: NouriColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
