import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../core/time/date_formats.dart';
import '../../core/time/hijri_date.dart';
import '../../core/time/prayer_times_service.dart';
import '../../data/db/nouri_database.dart';
// For the TipPillar.arabicLabel extension used by the daily tip line.
import '../../data/tips/daily_tip.dart';
import '../planner/day_plan.dart';
import '../planner/shift.dart';
import '../planner/example_day.dart';
import '../planner/widgets/day_blocks.dart';
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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
            hijri: hijriFor(now,
                offsetDays: s.hijriOffsetDays, arabic: isArabic),
            gregorian: formatGregorianLong(now, arabic: isArabic),
            greeting: greetingFor(now),
          ),
          const SizedBox(height: 18),

          // Progress ring + Nouri's line, with today's rotating tip beneath it.
          Row(
            children: [
              ProgressRing(done: count.done, total: count.total),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nouriProgressLine(count),
                      style: cairo(
                        size: 13,
                        color: NouriColors.muted,
                        height: 1.65,
                      ),
                    ),
                    const _DailyTipLine(),
                  ],
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

          _DayPreview(plan: exampleDayPlan(date: now, prayers: t), now: now),
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
              subtitle: wirdDone
                  ? 'الختمة ${khatma.percentLabel}'
                  : toArabicDigits('ربع · $kDailyWirdPages صفحات'),
              fraction: khatma.fraction,
              done: wirdDone,
              // Nouri holds no mushaf: the user reads from his own and marks
              // the wird here. Tapping again clears it, so a mistap is
              // reversible rather than permanent.
              onTap: () => _toggleWird(ref, quranToday?.pagesRead ?? 0),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleWird(WidgetRef ref, int currentPages) async {
    await ref.read(databaseProvider).quranDao.upsert(
          date: DateTime.now(),
          pages: currentPages > 0 ? 0 : kDailyWirdPages,
        );
    ref.invalidate(todayQuranProvider);
    ref.invalidate(khatmaTotalPagesProvider);
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

/// A preview of the Slice 2 day view, on real prayer anchors.
///
/// The blocks and their layout are the approved design; the tasks inside them
/// are a hand-written fixture from the worked example, not something Nouri
/// decided. It is marked «معاينة» and is not interactive, because tapping a
/// task would teach a habit the real planner then has to honour.
class _DayPreview extends StatelessWidget {
  const _DayPreview({required this.plan, required this.now});

  final DayPlan plan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 9, right: 2),
          child: Row(
            children: [
              Text('يومك', style: cairo(size: 14, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: NouriColors.surfaceActive,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('معاينة',
                    style: cairo(size: 9.5, color: NouriColors.muted)),
              ),
              const Spacer(),
              Text(plan.shift.type.arabicLabel,
                  style: cairo(size: 11, color: NouriColors.muted)),
            ],
          ),
        ),
        DayBlocks(plan: plan, now: now),
        const SizedBox(height: 8),
        Text(
          'الشكل ده معاينة. لما تدخل مواعيد ورديّاتك، نوري هيرتّب يومك '
          'الحقيقي بنفس الطريقة.',
          style: cairo(size: 11, color: NouriColors.muted, height: 1.75),
        ),
      ],
    );
  }
}

/// The rotating deen / body / wealth line.
///
/// Renders nothing at all until the tips have loaded, so it cannot hold up the
/// first frame — and nothing shifts on screen when it arrives, because it sits
/// at the end of a column that is already laid out.
class _DailyTipLine extends ConsumerWidget {
  const _DailyTipLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = ref.watch(dailyTipProvider).value;
    if (tip == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The pillar is named, not just implied. Without it the
          // deen/body/wealth structure is invisible and Nouri reads as a
          // prayer app with a tip attached.
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: NouriColors.surfaceActive,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tip.pillar.arabicLabel,
              style: cairo(
                size: 9.5,
                weight: FontWeight.w600,
                color: NouriColors.gold,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              tip.text,
              style: cairo(
                size: 11.5,
                color: NouriColors.muted,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
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
