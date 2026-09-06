import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../home/home_providers.dart';
import 'budget_categories.dart';
import 'finance_providers.dart';

/// "Spent X on Y" — the one financial action the brief asks for daily.
///
/// Deliberately two taps and a number: amount, category, done. A logging step
/// that takes longer than the purchase itself does not get used.
Future<void> showAddExpenseSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NouriColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _AddExpenseForm(parentRef: ref),
    ),
  );
}

class _AddExpenseForm extends StatefulWidget {
  const _AddExpenseForm({required this.parentRef});

  final WidgetRef parentRef;

  @override
  State<_AddExpenseForm> createState() => _AddExpenseFormState();
}

class _AddExpenseFormState extends State<_AddExpenseForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  BudgetCategory _category = BudgetCategory.food;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fils = parseMoney(_amount.text);
    if (fils == null || fils <= 0) {
      setState(() => _error = 'اكتب مبلغ صحيح');
      return;
    }

    await widget.parentRef.read(databaseProvider).financeDao.addExpense(
          date: DateTime.now(),
          category: _category.name,
          amountFils: fils,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );

    widget.parentRef.invalidate(monthExpensesProvider);
    widget.parentRef.invalidate(monthSpendByCategoryProvider);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
              Text('صرفت كام؟',
                  style: cairo(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.٫]')),
                ],
                style: cairo(size: 22, weight: FontWeight.w700),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '٠٫٠٠٠',
                  hintStyle: cairo(size: 22, color: NouriColors.border),
                  errorText: _error,
                  filled: true,
                  fillColor: NouriColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 16),
              Text('على إيه؟',
                  style: cairo(size: 13, color: NouriColors.muted)),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in BudgetCategory.values)
                    GestureDetector(
                      onTap: () => setState(() => _category = c),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 13, vertical: 8),
                        decoration: BoxDecoration(
                          color: c == _category
                              ? NouriColors.gold
                              : NouriColors.background,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: c == _category
                                ? NouriColors.gold
                                : NouriColors.border,
                          ),
                        ),
                        child: Text(
                          c.arabicLabel,
                          style: cairo(
                            size: 12.5,
                            weight: c == _category
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: c == _category
                                ? NouriColors.background
                                : NouriColors.text,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _note,
                style: cairo(size: 13),
                decoration: InputDecoration(
                  hintText: 'ملاحظة (اختياري)',
                  hintStyle: cairo(size: 13, color: NouriColors.muted),
                  filled: true,
                  fillColor: NouriColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: NouriColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _save,
                child: Text('سجّل',
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
