import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/format/arabic_plurals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../core/time/prayer_times_service.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import '../shared/nouri_avatar.dart';
import 'prayer_log_sheet.dart';
import 'prayer_names.dart';
import 'prayer_scoring.dart';

/// A prayer whose time has passed and which has not been answered.
class UnansweredPrayer {
  const UnansweredPrayer({required this.slot, required this.state});

  final PrayerSlot slot;
  final PrayerState state;
}

/// Which of [times] have passed by [now] without being logged.
///
/// A prayer still ahead is not "unanswered" — it simply has not happened. Only
/// the ones that have passed are worth asking about.
///
/// Deliberately a plain function rather than logic buried in the provider: the
/// rule is pure, and keeping it pure means it can be tested without a clock, a
/// database or a location fix.
List<UnansweredPrayer> unansweredFrom({
  required DailyPrayerTimes times,
  required Map<String, PrayerState> logs,
  required DateTime now,
}) =>
    [
      for (final slot in times.ordered)
        if (slot.time.isBefore(now) &&
            (logs[slot.name] ?? PrayerState.none) == PrayerState.none)
          UnansweredPrayer(slot: slot, state: PrayerState.none),
    ];

/// Today's prayers that are still unlogged and whose time has gone.
final unansweredPrayersProvider = Provider<List<UnansweredPrayer>>((ref) {
  final times = ref.watch(todayPrayerTimesProvider).value;
  if (times == null) return const [];

  return unansweredFrom(
    times: times,
    logs: ref.watch(todayPrayerLogsProvider).value ?? const {},
    now: ref.watch(clockProvider).value ?? DateTime.now(),
  );
});

/// The end-of-day review.
///
/// Opened by the 22:00 summary notification, and available any time from Home.
/// Its whole job is to make catching up cheap: every prayer the user never got
/// to is one tap away, in one place, without scrolling the day.
///
/// The wording never counts what was missed. «فيه ٣ صلوات لسه متسجلتش» states a
/// fact and offers the next step; "you missed three prayers" would be a verdict.
Future<void> showDailyReviewSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NouriColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _DailyReview(),
  );
}

class _DailyReview extends ConsumerWidget {
  const _DailyReview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(unansweredPrayersProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  const NouriAvatar(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pending.isEmpty
                          ? 'كل صلوات النهاردة متسجلة. تقبّل الله.'
                          : 'فيه ${countPrayers(pending.length)} لسه '
                              'متسجلتش. تحب تسجلها دلوقتي؟',
                      style: cairo(size: 14.5, height: 1.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (pending.isEmpty)
                const _NothingPending()
              else
                for (final p in pending)
                  _PendingRow(
                    entry: p,
                    onTap: () => _log(context, ref, p.slot),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _log(
    BuildContext context,
    WidgetRef ref,
    PrayerSlot slot,
  ) async {
    final chosen =
        await showPrayerLogSheet(context, slot.name, PrayerState.none);
    if (chosen == null) return;

    await ref.read(databaseProvider).prayerDao.upsertLog(
          date: DateTime.now(),
          prayer: slot.name,
          scheduledTime: slot.time,
          state: chosen,
        );
    ref.invalidate(todayPrayerLogsProvider);
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.entry, required this.onTap});

  final UnansweredPrayer entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: NouriColors.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: NouriColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(arabicPrayerName(entry.slot.name),
                          style:
                              cairo(size: 14.5, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(formatClock(entry.slot.time),
                          style: cairo(
                              size: 11.5, color: NouriColors.muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: NouriColors.border),
                  ),
                  child: Text(chipLabelFor(entry.state),
                      style: cairo(
                          size: 10.5, color: NouriColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NothingPending extends StatelessWidget {
  const _NothingPending();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NouriColors.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'مفيش حاجة مستنية منك. نام وانت مرتاح.',
          textAlign: TextAlign.center,
          style: cairo(size: 12.5, color: NouriColors.muted, height: 1.8),
        ),
      );
}
