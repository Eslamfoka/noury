import '../../data/db/tables.dart';
import '../prayers/prayer_scoring.dart';

/// One day's religious record, flattened for the summary.
class DaySnapshot {
  const DaySnapshot({
    required this.date,
    required this.prayerStates,
    required this.morningDone,
    required this.eveningDone,
    required this.tasbeehCount,
    required this.quranPages,
  });

  final DateTime date;

  /// One entry per prayer that has a row; unlogged prayers are
  /// [PrayerState.none].
  final List<PrayerState> prayerStates;
  final bool morningDone;
  final bool eveningDone;
  final int tasbeehCount;
  final int quranPages;

  int get loggedPrayers =>
      prayerStates.where((s) => s != PrayerState.none).length;
}

/// A deterministic, local summary of the last seven days.
///
/// No AI, no network, no cross-pillar scoring — that arrives in Slice 5. This
/// exists so the user can see his own logging add up from day one.
class WeeklySummary {
  const WeeklySummary({
    required this.days,
    required this.prayerAverage,
    required this.prayersLogged,
    required this.wirdStreak,
    required this.tasbeehTotal,
    required this.quranPages,
    required this.athkarSessions,
  });

  final List<DaySnapshot> days;

  /// Null when nothing was logged all week.
  ///
  /// An empty week has **no score**; it is not a zero. Nouri does not grade a
  /// week the user never recorded.
  final double? prayerAverage;

  final int prayersLogged;
  final int wirdStreak;
  final int tasbeehTotal;
  final int quranPages;
  final int athkarSessions;

  static WeeklySummary build({required List<DaySnapshot> days}) {
    final allStates = days.expand((d) => d.prayerStates).toList();

    // The streak runs backwards from the most recent day and stops at the
    // first gap, so it reflects a run that is still alive today.
    var streak = 0;
    for (final d in days.reversed) {
      if (d.quranPages > 0) {
        streak++;
      } else {
        break;
      }
    }

    return WeeklySummary(
      days: days,
      prayerAverage: dailyPrayerAverage(allStates),
      prayersLogged: allStates.where((s) => s != PrayerState.none).length,
      wirdStreak: streak,
      tasbeehTotal: days.fold(0, (a, d) => a + d.tasbeehCount),
      quranPages: days.fold(0, (a, d) => a + d.quranPages),
      athkarSessions: days.fold(
        0,
        (a, d) => a + (d.morningDone ? 1 : 0) + (d.eveningDone ? 1 : 0),
      ),
    );
  }
}
