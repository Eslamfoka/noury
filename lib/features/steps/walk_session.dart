import '../../core/format/arabic_numerals.dart';

/// What a walking session has amounted to so far.
///
/// Every number is an integer for the same reason money is stored in fils: a
/// total accumulated from floating-point parts drifts, and a drifting total is
/// worse than a coarse one.
class WalkStats {
  const WalkStats({
    required this.steps,
    required this.metres,
    required this.kcal,
    required this.elapsed,
  });

  final int steps;
  final int metres;
  final int kcal;
  final Duration elapsed;
}

/// MET values for walking, chosen from pace.
///
/// The compendium of physical activities puts a slow stroll near 2.8, an
/// ordinary walk near 3.5, and a brisk one near 5.0. Three bands rather than a
/// curve: the input is a step counter and a stride guess, and a more precise
/// formula would only be more precisely wrong.
const _metStroll = 2.8;
const _metWalk = 3.5;
const _metBrisk = 5.0;

double _metFor(double kmPerHour) {
  if (kmPerHour < 4.0) return _metStroll;
  if (kmPerHour <= 5.5) return _metWalk;
  return _metBrisk;
}

/// Distance, calories and pace for a session.
///
/// [steps] may arrive negative: `TYPE_STEP_COUNTER` resets to zero on reboot,
/// so the delta against the session's start reading goes below zero if the
/// phone restarts mid-walk. Clamped rather than propagated — a walk must never
/// run backwards.
///
/// [weightGrams] of zero means the user has not logged a weight yet. Distance
/// does not need it; calories do, and Nouri returns zero rather than inventing
/// a figure from a weight it does not have.
WalkStats walkStats({
  required int steps,
  required Duration elapsed,
  required int strideCm,
  required int weightGrams,
}) {
  final safeSteps = steps < 0 ? 0 : steps;
  final metres = (safeSteps * strideCm) ~/ 100;

  // No steps means no walking, whatever the clock says. The MET formula is
  // per-minute and would otherwise credit a few calories to a phone lying
  // still on a table -- activity the user did not do.
  final seconds = elapsed.inSeconds;
  if (seconds <= 0 || weightGrams <= 0 || safeSteps == 0) {
    return WalkStats(
      steps: safeSteps,
      metres: metres,
      kcal: 0,
      elapsed: elapsed,
    );
  }

  final hours = seconds / 3600.0;
  final kmPerHour = (metres / 1000.0) / hours;
  final kg = weightGrams / 1000.0;

  // kcal/min = MET x 3.5 x kg / 200, the standard form.
  final kcalPerMinute = _metFor(kmPerHour) * 3.5 * kg / 200.0;
  final kcal = (kcalPerMinute * (seconds / 60.0)).round();

  return WalkStats(
    steps: safeSteps,
    metres: metres,
    kcal: kcal,
    elapsed: elapsed,
  );
}

/// «٤٥٠ م» under a kilometre, «١٫٢ كم» at or above one.
String formatDistance(int metres) {
  if (metres >= 1000) {
    final km = metres / 1000.0;
    return toArabicDigits('${km.toStringAsFixed(1).replaceAll('.', '٫')} كم');
  }
  return toArabicDigits('$metres م');
}

/// Average pace in km/h, or a dash before there is anything to average.
String formatPace(int metres, Duration elapsed) {
  final seconds = elapsed.inSeconds;
  if (seconds <= 0) return '—';
  final kmPerHour = (metres / 1000.0) / (seconds / 3600.0);
  return toArabicDigits(
    '${kmPerHour.toStringAsFixed(1).replaceAll('.', '٫')} كم/س',
  );
}

/// `m:ss` — a walk is measured in minutes, so hours would be noise.
String formatWalkClock(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  final m = safe.inMinutes;
  final s = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return toArabicDigits('$m:$s');
}

/// How far through the chosen target the session is, clamped to one.
///
/// Clamped because walking past the target is a good thing, not an overflow —
/// the ring fills and stays full while the count keeps rising.
double walkFraction(Duration elapsed, int targetMinutes) {
  if (targetMinutes <= 0) return 0;
  final f = elapsed.inSeconds / (targetMinutes * 60);
  return f.clamp(0.0, 1.0);
}
