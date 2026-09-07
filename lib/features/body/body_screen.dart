import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import '../shared/nouri_avatar.dart';
import 'body_providers.dart';
import 'fasting_window.dart';
import 'log_meal_sheet.dart';
import 'log_weight_sheet.dart';
import 'meal.dart';
import '../steps/walk_screen.dart';

/// The physical pillar.
///
/// Ordered by what the brief says matters. Calming the stomach comes before
/// the number, so the meal log leads and weight sits below it. There is no
/// calorie count anywhere, deliberately.
class BodyScreen extends ConsumerWidget {
  const BodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final window = ref.watch(fastingWindowProvider);
    final hidden = ref.watch(hiddenMealsProvider);
    final meals = (ref.watch(todayMealsProvider).value ?? const <Meal>[])
        .where((m) => !hidden.contains(m.id))
        .toList();
    final pattern = ref.watch(mealPatternProvider);
    final weight = ref.watch(latestWeightProvider).value;
    final toGo = ref.watch(weightToGoProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('البدن', style: cairo(size: 17, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('الأكل والراحة',
                    style: cairo(size: 11.5, color: NouriColors.muted)),
              ],
            ),
            const NouriAvatar(size: 36),
          ],
        ),
        const SizedBox(height: 18),

        _WindowCard(window: window),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _Action(
                label: 'سجّل وجبة',
                icon: Icons.restaurant_outlined,
                onTap: () => showLogMealSheet(context, ref),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _Action(
                label: 'سجّل وزنك',
                icon: Icons.monitor_weight_outlined,
                onTap: () => showLogWeightSheet(context, ref),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),

        // Movement lives inside البدن rather than behind a seventh bottom tab.
        // The shell already carries six destinations, one past Material's
        // recommendation, and walking and workouts are the physical pillar --
        // this is where a user would look for them.
        Row(
          children: [
            Expanded(
              child: _Action(
                key: const ValueKey('open-walk'),
                label: 'امشي',
                icon: Icons.directions_walk,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const WalkScreen()),
                ),
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 20),

        if (weight != null) ...[
          _WeightRow(grams: weight.grams, toGo: toGo),
          const SizedBox(height: 20),
        ],

        Text('وجبات النهاردة',
            style: cairo(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        if (meals.isEmpty)
          const _NoMealsYet()
        else
          for (final m in meals) _MealRow(meal: m, ref: ref),

        if (pattern.hasEnoughToSay && pattern.anySymptoms) ...[
          const SizedBox(height: 18),
          _PatternNote(pattern: pattern),
        ],

        const SizedBox(height: 20),
        Text(
          'نوري مش دكتور ومش بديل عن الكشف. ده سجل بيوصف اللي حصل، '
          'مش تشخيص. لو الوجع مستمر، اعرض نفسك على دكتور وخد السجل ده معاك.',
          style: cairo(size: 11, color: NouriColors.muted, height: 1.85),
        ),
      ],
    );
  }
}

/// Where the day sits in the 16/8 cycle.
class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.window});

  final FastingWindow window;

  @override
  Widget build(BuildContext context) {
    final h = window.remaining.inHours;
    final m = window.remaining.inMinutes.remainder(60);
    final eating = window.isEating;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: eating ? NouriColors.gold : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                eating ? Icons.local_dining_outlined : Icons.bedtime_outlined,
                size: 17,
                color: eating ? NouriColors.gold : NouriColors.muted,
              ),
              const SizedBox(width: 8),
              Text(window.phase.arabicLabel,
                  style: cairo(size: 15, weight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            eating
                ? 'الأكل مفتوح لحد ${formatClock(window.closes)}'
                : 'الأكل يفتح ${formatClock(window.opens)}',
            style: cairo(size: 12.5, color: NouriColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            h > 0
                ? 'فاضل ${toArabicDigits('$h')} ساعة و${toArabicDigits('$m')} دقيقة'
                : 'فاضل ${toArabicDigits('$m')} دقيقة',
            style: cairo(size: 12.5, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.grams, required this.toGo});

  final int grams;
  final int? toGo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: NouriColors.surface,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('آخر وزن', style: cairo(size: 13)),
            ),
            Text(formatWeight(grams),
                style: cairo(size: 15, weight: FontWeight.w700)),
            if (toGo != null) ...[
              const SizedBox(width: 10),
              Text('باقي ${formatWeight(toGo!)}',
                  style: cairo(size: 11, color: NouriColors.muted)),
            ],
          ],
        ),
      );
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.meal, required this.ref});

  final Meal meal;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('meal-${meal.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: const Icon(Icons.delete_outline,
            size: 18, color: NouriColors.muted),
      ),
      onDismissed: (_) async {
        // Synchronous, before any await: the row must leave the list in the
        // same frame the dismiss animation ends.
        ref.read(hiddenMealsProvider.notifier).hide(meal.id);
        await ref.read(databaseProvider).bodyDao.deleteMeal(meal.id);
        ref
          ..invalidate(todayMealsProvider)
          ..invalidate(recentMealsProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(formatClock(meal.at),
                  style: cairo(size: 11.5, color: NouriColors.muted)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                meal.description?.isNotEmpty ?? false
                    ? meal.description!
                    : 'وجبة',
                style: cairo(size: 13),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: NouriColors.border),
              ),
              child: Text(meal.feeling.arabicLabel,
                  style: cairo(size: 10.5, color: NouriColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reports what was logged, and stops there.
///
/// It states a count and points at a doctor. It never names a food, a cause or
/// a change to make — that would be diagnosing, which §1.5 of the brief rules
/// out and which Nouri is not competent to do.
class _PatternNote extends StatelessWidget {
  const _PatternNote({required this.pattern});

  final MealPattern pattern;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: NouriColors.surfaceActive,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NouriAvatar(size: 30),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                '${toArabicDigits('${pattern.withSymptoms}')} من آخر '
                '${toArabicDigits('${pattern.total}')} وجبات حسّيت بعدها '
                'بحاجة. السجل ده يفيد الدكتور.',
                style: cairo(size: 12.5, height: 1.7),
              ),
            ),
          ],
        ),
      );
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Icon(icon, size: 19, color: NouriColors.gold),
                const SizedBox(height: 6),
                Text(label,
                    style: cairo(size: 12, weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
}

class _NoMealsYet extends StatelessWidget {
  const _NoMealsYet();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NouriColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'لسه مسجلتش وجبة النهاردة. سجّل بعد ما تاكل، وقول حسّيت إزاي.',
          style: cairo(size: 12.5, color: NouriColors.muted, height: 1.8),
        ),
      );
}
