import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import '../settings/settings_screen.dart';
import 'water_plan.dart';

final todayWaterProvider = FutureProvider<WaterLog?>(
  (ref) => ref
      .watch(databaseProvider)
      .waterDao
      .forDate(ref.watch(currentDayProvider)),
);

final fastingTodayProvider = FutureProvider<bool>(
  (ref) => ref
      .watch(databaseProvider)
      .waterDao
      .isFasting(ref.watch(currentDayProvider)),
);

/// The day's water, and the fasting marker that governs it.
///
/// Both live on the same card because they are the same decision from the
/// user's side: whether today is a day for drinking through, or a day for
/// leaving it until maghrib.
class WaterCard extends ConsumerWidget {
  const WaterCard({super.key});

  Future<void> _add(WidgetRef ref, int glasses) async {
    // Read off `ref` before the first await: a WidgetRef belongs to a widget,
    // and after an await that widget may be gone. Same reasoning as logPrayer.
    final db = ref.read(databaseProvider);
    final settings = await ref.read(settingsProvider.future);

    await db.waterDao.add(
      DateTime.now(),
      glasses,
      target: settings.waterTargetGlasses,
    );

    try {
      ref.invalidate(todayWaterProvider);
    } catch (_) {
      // The card went away mid-write. The glass is counted; nothing to
      // refresh.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value;
    final log = ref.watch(todayWaterProvider).value;
    final fasting = ref.watch(fastingTodayProvider).value ?? false;

    final target = settings?.waterTargetGlasses ?? kDefaultWaterGlasses;
    final progress =
        WaterProgress(glasses: log?.glasses ?? 0, target: target);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined,
                  size: 18, color: NouriColors.gold),
              const SizedBox(width: 8),
              Text('المياه',
                  style: cairo(size: 13.5, weight: FontWeight.w600)),
              const Spacer(),
              Text(
                toArabicDigits('${progress.glasses} من ${progress.target}'),
                key: const ValueKey('water-count'),
                style: cairo(size: 13, color: NouriColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 5,
              backgroundColor: NouriColors.surfaceActive,
              valueColor: AlwaysStoppedAnimation(
                progress.isComplete ? NouriColors.success : NouriColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            progress.arabicNote,
            key: const ValueKey('water-note'),
            style: cairo(size: 11.5, color: NouriColors.muted),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const ValueKey('water-add'),
                  style: FilledButton.styleFrom(
                    backgroundColor: NouriColors.gold,
                    foregroundColor: NouriColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: () => _add(ref, 1),
                  child: Text(
                    'شربت كوباية',
                    style: cairo(
                      size: 13,
                      weight: FontWeight.w700,
                      color: NouriColors.background,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              // For a mistap. Clamped at zero in the DAO — a negative count of
              // glasses is not a thing.
              SizedBox(
                width: 46,
                child: OutlinedButton(
                  key: const ValueKey('water-remove'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: NouriColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  onPressed: () => _add(ref, -1),
                  child: const Icon(Icons.remove,
                      size: 16, color: NouriColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // The fasting marker. Set by the user, never inferred: Nouri
          // suggests the sunnah fasts but cannot know whether one was kept,
          // and guessing wrong means nudging a fasting person to drink.
          Row(
            children: [
              Expanded(
                child: Text(
                  fasting
                      ? 'صايم النهاردة — مفيش تنبيه مياه لحد المغرب'
                      : 'صايم النهاردة؟',
                  key: const ValueKey('water-fasting-label'),
                  style: cairo(
                      size: 11.5, color: NouriColors.muted, height: 1.7),
                ),
              ),
              Switch(
                key: const ValueKey('water-fasting-switch'),
                value: fasting,
                activeThumbColor: NouriColors.gold,
                onChanged: (v) async {
                  // Through the controller, not the DAO: today's water
                  // reminders are already armed and have to be rebuilt, or
                  // Nouri would nudge a fasting person to drink at noon
                  // having just been told they are fasting.
                  final controller = ref.read(settingsControllerProvider);
                  await controller.setFastingDay(DateTime.now(), v);
                  try {
                    ref.invalidate(fastingTodayProvider);
                  } catch (_) {
                    // Card gone; the marker and the re-arm both happened.
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
