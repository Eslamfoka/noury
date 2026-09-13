import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/tables.dart';
import '../home/home_providers.dart';
import '../prayers/log_prayer.dart';
import '../prayers/prayer_log_sheet.dart';
import '../prayers/prayer_row.dart';

/// صلوات اليوم, from المهام.
///
/// The prayers line on المهام is tapped to *do* something about it, and the
/// thing to do is log a prayer. Sending the user to Home for that would be a
/// tab switch and a scroll for one tap; so the five rows Home draws are drawn
/// here too, on a sheet, and tapping one opens the same question.
///
/// **Still one place the truth lives.** The write goes through [logPrayer],
/// exactly as it does from Home, the daily review and the notification tap.
/// This is a fourth door to the same room, not a second room.
Future<void> showPrayersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NouriColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const SafeArea(child: _PrayersSheet()),
  );
}

class _PrayersSheet extends ConsumerWidget {
  const _PrayersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, not passed in: a prayer logged from this sheet has to show
    // its chip here at once, without closing and reopening.
    final times = ref.watch(todayPrayerTimesProvider).value;
    final logs =
        ref.watch(todayPrayerLogsProvider).value ?? const <String, PrayerState>{};
    final now = ref.watch(coarseClockProvider).value ?? DateTime.now();

    if (times == null) return const SizedBox(height: 120);

    final next = times.next(now);

    return SingleChildScrollView(
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
            Text('صلوات اليوم',
                style: cairo(size: 16, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'دوس على الصلاة وقول صليتها إزاي.',
              style: cairo(size: 11.5, color: NouriColors.muted, height: 1.7),
            ),
            const SizedBox(height: 14),
            for (final slot in times.ordered)
              PrayerRow(
                slot: slot,
                state: logs[slot.name] ?? PrayerState.none,
                isNext: next?.name == slot.name,
                onTap: () async {
                  final chosen = await showPrayerLogSheet(
                    context,
                    slot.name,
                    logs[slot.name] ?? PrayerState.none,
                  );
                  if (chosen == null) return;
                  await logPrayer(
                    ref,
                    prayer: slot.name,
                    scheduledTime: slot.time,
                    state: chosen,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
