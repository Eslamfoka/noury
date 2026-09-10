import '../../data/db/nouri_database.dart';
import 'challenge.dart';

/// Turns the existing logs into challenge progress.
///
/// Nothing about a challenge's progress is stored. It is derived from the
/// prayer, athkar and walk logs every time it is read — two sources of truth
/// for "did I pray in the mosque on the 3rd" is one too many, and a derived
/// one can never drift out of step with the thing it describes.

const _prayerNames = <String>['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [state] is at least as good as [bar].
///
/// [PrayerState] is ordered best to worst, so "at least as good" is a lower
/// index. Congregation at home therefore does not satisfy a mosque challenge,
/// which is the whole point of «أربعين يوم في المسجد».
bool _meets(PrayerState state, PrayerState bar) => state.index <= bar.index;

ChallengeProgress evaluate(
  ChallengeDef def, {
  required DateTime startedOn,
  required DateTime today,
  List<PrayerLog> prayers = const [],
  List<AthkarLog> athkar = const [],
  List<WalkSession> walks = const [],
}) {
  final start = _day(startedOn);
  final now = _day(today);

  // Index the logs by day once rather than scanning per day: forty days times
  // five prayers is a lot of linear searches otherwise.
  final prayersByDay = <DateTime, List<PrayerLog>>{};
  for (final p in prayers) {
    (prayersByDay[_day(p.date)] ??= []).add(p);
  }

  final athkarByDay = <DateTime, List<AthkarLog>>{};
  for (final a in athkar) {
    (athkarByDay[_day(a.date)] ??= []).add(a);
  }

  final walkSecondsByDay = <DateTime, int>{};
  for (final w in walks) {
    final d = _day(w.startedAt);
    walkSecondsByDay[d] = (walkSecondsByDay[d] ?? 0) + w.seconds;
  }

  bool qualifies(DateTime day) {
    switch (def.kind) {
      case ChallengeKind.prayerState:
        final bar = def.minState ?? PrayerState.onTime;
        final logs = prayersByDay[day];
        if (logs == null) return false;
        final byName = {for (final l in logs) l.prayer: l.state};
        // Every one of the five. Four out of five is not a day.
        return _prayerNames.every(
          (n) => byName[n] != null && _meets(byName[n]!, bar),
        );

      case ChallengeKind.athkarType:
        final type = def.athkarType;
        if (type == null) return false;
        final rows = athkarByDay[day];
        if (rows == null) return false;
        for (final r in rows) {
          if (r.type != type) continue;
          if (r.completedAt != null) return true;
          if (r.targetCount > 0 && r.progressCount >= r.targetCount) {
            return true;
          }
        }
        return false;

      case ChallengeKind.tasbeehCount:
        final need = def.minCount ?? 0;
        final rows = athkarByDay[day];
        if (rows == null) return false;
        for (final r in rows) {
          if (r.type == 'tasbeeh' && r.progressCount >= need) return true;
        }
        return false;

      case ChallengeKind.walkMinutes:
        final need = (def.minCount ?? 0) * 60;
        return (walkSecondsByDay[day] ?? 0) >= need;
    }
  }

  // Days from enrolment up to and including today. Days before the enrolment
  // never count — joining a challenge today does not retroactively award last
  // week.
  final qualifyingDays = <DateTime>[];
  var currentStreak = 0;
  var bestStreak = 0;
  var running = 0;
  var completedToday = false;

  for (var i = 0;; i++) {
    final day = DateTime(start.year, start.month, start.day + i);
    if (day.isAfter(now)) break;

    final ok = qualifies(day);
    final isToday = day == now;
    if (ok) {
      qualifyingDays.add(day);
      if (isToday) completedToday = true;
    }

    if (ok) {
      running++;
      if (running > bestStreak) bestStreak = running;
      currentStreak = running;
    } else if (isToday) {
      // Today is never counted against the user. It is not over yet, and
      // breaking a streak at 09:00 for a prayer that has not happened would
      // be Nouri punishing someone for the passage of time.
      break;
    } else {
      running = 0;
      currentStreak = 0;
    }
  }

  final daysDone = def.mode == ChallengeMode.streak
      ? currentStreak
      : qualifyingDays.length;

  return ChallengeProgress(
    daysDone: daysDone.clamp(0, def.targetDays),
    targetDays: def.targetDays,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    completedToday: completedToday,
    qualifyingDays: qualifyingDays,
  );
}
