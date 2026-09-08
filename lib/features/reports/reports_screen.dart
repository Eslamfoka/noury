import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../challenges/challenges_panel.dart';
import 'body_wealth_panel.dart';
import '../home/home_providers.dart';
import '../prayers/prayer_scoring.dart';
import '../shared/nouri_avatar.dart';
import 'weekly_summary.dart';

/// The last seven days, assembled from local rows only.
final weeklySummaryProvider = FutureProvider<WeeklySummary>((ref) async {
  final db = ref.watch(databaseProvider);
  // Watched, not read: a report left open past midnight has to become the
  // new week's report. `DateTime.now()` here would cache the date once and
  // keep showing the old seven days until something else invalidated it —
  // which matters most for a user who works nights.
  final today = ref.watch(currentDayProvider);
  // Constructed, never offset — a day is a calendar day, not 24 hours.
  final from = DateTime(today.year, today.month, today.day - 6);

  final prayers = await db.prayerDao.logsBetween(from, today);
  final athkar = await db.athkarDao.between(from, today);
  final quran = await db.quranDao.between(from, today);

  final days = <DaySnapshot>[];
  for (var i = 0; i < 7; i++) {
    // Same reason: offsetting across a DST night would put the same day in
    // the week twice and drop another, so seven days would show six.
    final d = DateTime(from.year, from.month, from.day + i);

    final states = prayers
        .where((p) => dayOf(p.date) == d)
        .map((p) => p.state)
        .toList();

    final athkarForDay = {
      for (final a in athkar.where((a) => dayOf(a.date) == d)) a.type: a
    };

    days.add(DaySnapshot(
      date: d,
      prayerStates: states,
      morningDone: athkarForDay['morning']?.completedAt != null,
      eveningDone: athkarForDay['evening']?.completedAt != null,
      tasbeehCount: athkarForDay['tasbeeh']?.progressCount ?? 0,
      quranPages: quran
          .where((q) => dayOf(q.date) == d)
          .fold(0, (a, q) => a + q.pagesRead),
    ));
  }

  return WeeklySummary.build(days: days);
});

/// التقارير — in this slice, a deterministic local religious summary.
///
/// The full six-pillar bi-weekly and monthly reports, with Nouri's written
/// guidance, arrive with the AI layer in Slice 5. This screen says so plainly
/// rather than pretending to be them.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weeklySummaryProvider);

    return summary.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NouriColors.gold),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'مش قادر أقرا سجل الأسبوع دلوقتي.',
            textAlign: TextAlign.center,
            style: cairo(size: 14, color: NouriColors.muted),
          ),
        ),
      ),
      data: (s) => ListView(
        padding: const EdgeInsets.fromLTRB(15, 18, 15, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('آخر ٧ أيام'.replaceAll('7', '٧'),
                      style: cairo(size: 17, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('ملخّص ديني محلي',
                      style: cairo(size: 11.5, color: NouriColors.muted)),
                ],
              ),
              const NouriAvatar(size: 36),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'متوسط الصلاة',
                  value: s.prayerAverage == null
                      ? '—'
                      : toArabicDigits('${s.prayerAverage!.round()}'),
                  hint: s.prayerAverage == null
                      ? 'لسه مفيش تسجيل'
                      : 'من ١٠٠',
                  accent: NouriColors.gold,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _StatCard(
                  label: 'صلوات مسجّلة',
                  value: toArabicDigits('${s.prayersLogged}'),
                  hint: toArabicDigits('من ٣٥'),
                  accent: NouriColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('كل يوم', style: cairo(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          _DayStrip(days: s.days),
          const SizedBox(height: 18),
          _StatRow(
            label: 'أيام ورد القرآن على التوالي',
            value: toArabicDigits('${s.wirdStreak}'),
          ),
          _StatRow(
            label: 'صفحات القرآن',
            value: toArabicDigits('${s.quranPages}'),
          ),
          _StatRow(
            label: 'إجمالي التسبيح',
            value: toArabicDigits('${s.tasbeehTotal}'),
          ),
          _StatRow(
            label: 'جلسات الأذكار',
            value: toArabicDigits('${s.athkarSessions}'),
          ),
          const SizedBox(height: 22),
          const BodyWealthPanel(),
          const SizedBox(height: 22),
          const ChallengesPanel(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NouriColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'ده ملخّص محلي من اللي سجّلته بنفسك. قراءة نوري للأسبوع، '
              'والربط بين الجوانب، هييجي في مرحلة جاية.',
              style: cairo(size: 12, color: NouriColors.muted, height: 1.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.accent,
  });

  final String label;
  final String value;
  final String hint;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          color: NouriColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(label, style: cairo(size: 11, color: NouriColors.muted)),
            const SizedBox(height: 8),
            Text(value,
                style: cairo(size: 34, weight: FontWeight.w700, color: accent)),
            const SizedBox(height: 6),
            Text(hint, style: cairo(size: 11, color: NouriColors.muted)),
          ],
        ),
      );
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: cairo(size: 13)),
            Text(value,
                style: cairo(size: 14, weight: FontWeight.w700)),
          ],
        ),
      );
}

/// Seven columns of five dots — one dot per prayer, coloured by how it was
/// prayed. A day with nothing logged shows empty outlines, never red.
class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.days});

  final List<DaySnapshot> days;

  static const _weekdayNames = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final d in days)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: _Dot(
                      state: i < d.prayerStates.length
                          ? d.prayerStates[i]
                          : null,
                    ),
                  ),
                const SizedBox(height: 7),
                Text(
                  _weekdayNames[(d.date.weekday - 1) % 7],
                  style: cairo(size: 10, color: NouriColors.muted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  final PrayerState? state;

  @override
  Widget build(BuildContext context) {
    final logged = state != null && state != PrayerState.none;
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: logged ? chipColorFor(state!) : Colors.transparent,
        border: logged ? null : Border.all(color: NouriColors.border),
      ),
    );
  }
}
