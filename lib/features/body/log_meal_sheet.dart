import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../home/home_providers.dart';
import '../tasks/task_done.dart';
import 'body_providers.dart';
import 'meal.dart';

/// Logs a meal and how it felt.
///
/// The feeling is the required part and the description is optional, which is
/// the opposite of most food trackers — the brief wants the symptom, not the
/// menu, and asking for detail nobody will type is how a log stops being kept.
Future<void> showLogMealSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NouriColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _LogMeal(parentRef: ref),
    ),
  );
}

class _LogMeal extends StatefulWidget {
  const _LogMeal({required this.parentRef});

  final WidgetRef parentRef;

  @override
  State<_LogMeal> createState() => _LogMealState();
}

class _LogMealState extends State<_LogMeal> {
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _save(MealFeeling feeling) async {
    // Both meal ids: which of the two this row answers depends on how many
    // are already logged, and `completedTaskIdsFor` works that out on the next
    // re-arm. Silencing both now is the safe direction — a missed question
    // costs nothing, a redundant one is the nagging this exists to stop.
    await silenceTaskAlarms(
        widget.parentRef, const ['first-meal', 'last-meal']);

    await widget.parentRef.read(databaseProvider).bodyDao.addMeal(
          at: DateTime.now(),
          feeling: feeling,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
        );
    widget.parentRef
      ..invalidate(todayMealsProvider)
      ..invalidate(recentMealsProvider);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
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
            Text('حسّيت إزاي بعد الأكل؟',
                style: cairo(size: 16, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('من غير حساب سعرات — المهم معدتك.',
                style: cairo(size: 11.5, color: NouriColors.muted)),
            const SizedBox(height: 14),

            TextField(
              controller: _description,
              style: cairo(size: 13.5),
              decoration: InputDecoration(
                hintText: 'أكلت إيه؟ (اختياري)',
                hintStyle: cairo(size: 13, color: NouriColors.muted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 13, vertical: 12),
                filled: true,
                fillColor: NouriColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            for (final f in mealFeelings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: NouriColors.background,
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    onTap: () => _save(f),
                    borderRadius: BorderRadius.circular(13),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(f.arabicLabel,
                                style: cairo(
                                    size: 14, weight: FontWeight.w600)),
                          ),
                          const Icon(Icons.chevron_left,
                              size: 17, color: NouriColors.muted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
