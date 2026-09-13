import 'package:flutter/material.dart';

import '../../core/theme/nouri_colors.dart';
import '../../data/db/tables.dart';

/// Chip colour per prayer state.
///
/// Gold for the mosque, green for congregation, muted for on-time and for
/// not-yet, warm orange for late. **No state is ever red**, and "not yet" is
/// deliberately the same muted tone as "on time" rather than anything that
/// reads as a warning.
Color chipColorFor(PrayerState s) => switch (s) {
      PrayerState.mosque => NouriColors.gold,
      PrayerState.congregation => NouriColors.success,
      PrayerState.onTime => NouriColors.muted,
      PrayerState.late_ => NouriColors.attention,
      // Deliberately identical to «متأخرة». It is the only label that names a
      // failure, so it must not look like one.
      PrayerState.missed => NouriColors.attention,
      PrayerState.none => NouriColors.muted,
    };

/// Arabic label per state.
///
/// The five, as the user wrote them on 13 September 2026 — «اعدل ع تسجيل
/// الصلوات تبقى: في المسجد جماعة، جماعة في البيت، فردي في البيت، متأخرة عن
/// وقتها، فاتتني الصلاة». Each names *where and how* rather than only a grade,
/// so the sheet reads as a description of what happened and not as marks.
///
/// Only the wording moved. The enum, its order and its scores are untouched:
/// drift stores the state by index, so every prayer already logged keeps
/// meaning what it meant.
String chipLabelFor(PrayerState s) => switch (s) {
      PrayerState.mosque => 'في المسجد جماعة',
      PrayerState.congregation => 'جماعة في البيت',
      PrayerState.onTime => 'فردي في البيت',
      PrayerState.late_ => 'متأخرة عن وقتها',
      PrayerState.missed => 'فاتتني الصلاة',
      PrayerState.none => 'لسه',
    };

/// The states a user can choose, best first. `none` is offered separately as a
/// way to clear an entry, not as a rating.
const loggablePrayerStates = <PrayerState>[
  PrayerState.mosque,
  PrayerState.congregation,
  PrayerState.onTime,
  PrayerState.late_,
  PrayerState.missed,
];

/// The average score of the prayers that were actually logged.
///
/// Unlogged prayers are **excluded**, never counted as zero: Nouri measures how
/// you prayed, not how many boxes are still empty. A day with nothing logged
/// has no average at all rather than a score of zero.
double? dailyPrayerAverage(List<PrayerState> states) {
  final logged = states.where((s) => s != PrayerState.none).toList();
  if (logged.isEmpty) return null;
  return logged.map((s) => s.score).reduce((a, b) => a + b) / logged.length;
}
