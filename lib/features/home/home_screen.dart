import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../core/time/hijri_date.dart';
import '../../core/time/prayer_times_service.dart';
import '../../data/db/nouri_database.dart';
import '../prayers/prayer_log_sheet.dart';
import '../prayers/prayer_row.dart';
import '../quran/khatma.dart';
import 'daily_items.dart';
import 'home_providers.dart';
import 'widgets/home_header.dart';
import 'widgets/next_prayer_card.dart';
import 'widgets/progress_ring.dart';
import 'widgets/wird_grid.dart';

/// Home / النهاردة.
///
/// Layout is a fixed contract: header, progress ring, next-prayer card, then
/// the middle section. Phase 2 replaces only the middle (prayer list + wird
/// grid become the four expandable day-blocks); everything above stays.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final times = ref.watch(todayPrayerTimesProvider);
    final logs = ref.watch(todayPrayerLogsProvider);
    final athkar = ref.watch(todayAthkarProvider);
    final quran = ref.watch(todayQuranProvider);
    final khatmaPages = ref.watch(khatmaTotalPagesProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    if (settings.isLoading || times.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: NouriColors.gold),
      );
    }

    final s = settings.value;
    final t = times.value;
    if (s == null || t == null) {
      return const _HomeUnavailable();
    }

    final logMap = logs.value ?? const <String, PrayerState>{};
    final athkarMap = athkar.value ?? const <String, AthkarLog>{};
    final quranToday = quran.value;

    final loggedCount =
        logMap.values.where((v) => v != PrayerState.none).length;
    final morningDone = athkarMap['morning']?.completedAt != null;
    final eveningDone = athkarMap['evening']?.completedAt != null;
    final tasbeehDone = athkarMap['tasbeeh']?.completedAt != null;
    final wirdDone = (quranToday?.pagesRead ?? 0) > 0;

    final count = DailyItems.count(
      loggedPrayers: loggedCount,
      morningAthkarDone: morningDone,
      eveningAthkarDone: eveningDone,
      tasbeehDone: tasbeehDone,
      quranWirdDone: wirdDone,
    );

    final next = t.next(now);
    final offsets = decodeIqamaOffsets(s.iqamaOffsetsJson);

    final khatma = KhatmaProgress(
      pagesRead: khatmaPages.value ?? 0,
      totalPages: s.khatmaTotalPages,
    );
    final tasbeehRow = athkarMap['tasbeeh'];
    final tasbeehProgress = tasbeehRow?.progressCount ?? 0;
    final tasbeehTarget = tasbeehRow?.targetCount ?? s.tasbeehTarget;

    return RefreshIndicator(
      color: NouriColors.gold,
      backgroundColor: NouriColors.surface,
      onRefresh: () async {
        ref.invalidate(todayPrayerLogsProvider);
        ref.invalidate(todayAthkarProvider);
        ref.invalidate(todayQuranProvider);
        ref.invalidate(khatmaTotalPagesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          HomeHeader(
            hijri: hijriFor(now, offsetDays: s.hijriOffsetDays),
            greeting: greetingFor(now),
          ),
          const SizedBox(height: 18),

          // Progress ring + Nouri's line.
          Row(
            children: [
              ProgressRing(done: count.done, total: count.total),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  nouriProgressLine(count),
                  style: cairo(
                    size: 13,
                    color: NouriColors.muted,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (next != null)
            NextPrayerCard(
              slot: next,
              iqama: iqamaFor(next, offsets),
              remaining: next.time.difference(now),
            )
          else
            const _AllPrayersDone(),
          const SizedBox(height: 18),

          _SectionLabel(text: 'صلوات اليوم'),
          for (final slot in t.ordered)
            PrayerRow(
              slot: slot,
              state: logMap[slot.name] ?? PrayerState.none,
              isNext: next?.name == slot.name,
              onTap: () => _logPrayer(context, ref, slot,
                  logMap[slot.name] ?? PrayerState.none),
            ),
          const SizedBox(height: 14),

          _SectionLabel(text: 'الورد اليومي'),
          WirdGrid(
            morning: WirdState(
              label: 'أذكار الصباح',
              subtitle: morningDone ? 'تمّت' : 'الصبح',
              fraction: morningDone ? 1 : 0,
              done: morningDone,
            ),
            tasbeeh: WirdState(
              label: 'التسبيح',
              subtitle: toArabicDigits('$tasbeehProgress من $tasbeehTarget'),
              fraction:
                  tasbeehTarget == 0 ? 0 : tasbeehProgress / tasbeehTarget,
              done: tasbeehDone,
            ),
            evening: WirdState(
              label: 'أذكار المساء',
              subtitle: eveningDone ? 'تمّت' : 'بعد المغرب',
              fraction: eveningDone ? 1 : 0,
              done: eveningDone,
            ),
            quran: WirdState(
              label: 'ورد القرآن',
              subtitle: 'الختمة ${khatma.percentLabel}',
              fraction: khatma.fraction,
              done: wirdDone,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logPrayer(
    BuildContext context,
    WidgetRef ref,
    PrayerSlot slot,
    PrayerState current,
  ) async {
    final chosen = await showPrayerLogSheet(context, slot.name, current);
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9, right: 2),
        child: Text(text, style: cairo(size: 14, weight: FontWeight.w600)),
      );
}

class _AllPrayersDone extends StatelessWidget {
  const _AllPrayersDone();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: NouriColors.surfaceActive,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NouriColors.border),
        ),
        child: Text(
          'صلوات النهاردة خلصت. الفجر بكرة إن شاء الله.',
          style: cairo(size: 13.5, color: NouriColors.muted, height: 1.6),
        ),
      );
}

/// Shown only if settings or prayer times could not be read at all.
///
/// States the fact plainly and offers the next step; it does not apologise
/// and does not present itself as the user's fault.
class _HomeUnavailable extends StatelessWidget {
  const _HomeUnavailable();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'مش قادر أحسب مواقيت النهاردة دلوقتي. جرّب تفتح التطبيق تاني.',
            textAlign: TextAlign.center,
            style: cairo(size: 14, color: NouriColors.muted, height: 1.8),
          ),
        ),
      );
}
