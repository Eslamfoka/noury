import 'package:hijri/hijri_calendar.dart';

import '../format/arabic_numerals.dart';
import 'date_formats.dart';

class HijriDate {
  const HijriDate({
    required this.day,
    required this.month,
    required this.monthName,
    required this.year,
    required this.formatted,
  });

  final int day;

  /// 1 = المحرم … 12 = ذو الحجة.
  ///
  /// Carried alongside [monthName] because some questions are about *which*
  /// month rather than what it is called — the fasting rules need to know that
  /// ذو الحجة is month 12 without matching on a string.
  final int month;

  final String monthName;
  final int year;

  /// e.g. «٢٣ ربيع الأول ١٤٤٨ هـ» or «23 Rabi' al-Awwal 1448 AH»
  final String formatted;
}

/// Converts a Gregorian date to Hijri.
///
/// The civil calculation can differ from local moon sighting by a day, so the
/// user can nudge it by ±1 in Settings — [offsetDays].
///
/// Month names come from our own table rather than the `hijri` package, whose
/// Arabic spellings are slightly off (see [arabicHijriMonths]). Only the
/// day/month/year arithmetic is taken from the package.
HijriDate hijriFor(
  DateTime gregorian, {
  int offsetDays = 0,
  bool arabic = true,
}) {
  // Constructed, never offset. Adding 24 hours within an hour of midnight on
  // a DST night lands back on the same date, so the user's ±1 sighting nudge
  // would silently do nothing on exactly the kind of day they might use it.
  final nudged = DateTime(
    gregorian.year,
    gregorian.month,
    gregorian.day + offsetDays,
  );
  final h = HijriCalendar.fromDate(nudged);

  final months = arabic ? arabicHijriMonths : englishHijriMonths;
  final monthName = months[h.hMonth] ?? '${h.hMonth}';

  final formatted = arabic
      ? toArabicDigits('${h.hDay} $monthName ${h.hYear} هـ')
      : '${h.hDay} $monthName ${h.hYear} AH';

  return HijriDate(
    day: h.hDay,
    month: h.hMonth,
    monthName: monthName,
    year: h.hYear,
    formatted: formatted,
  );
}
