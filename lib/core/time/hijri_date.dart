import 'package:hijri/hijri_calendar.dart';

import '../format/arabic_numerals.dart';
import 'date_formats.dart';

class HijriDate {
  const HijriDate({
    required this.day,
    required this.monthName,
    required this.year,
    required this.formatted,
  });

  final int day;
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
  final h = HijriCalendar.fromDate(gregorian.add(Duration(days: offsetDays)));

  final months = arabic ? arabicHijriMonths : englishHijriMonths;
  final monthName = months[h.hMonth] ?? '${h.hMonth}';

  final formatted = arabic
      ? toArabicDigits('${h.hDay} $monthName ${h.hYear} هـ')
      : '${h.hDay} $monthName ${h.hYear} AH';

  return HijriDate(
    day: h.hDay,
    monthName: monthName,
    year: h.hYear,
    formatted: formatted,
  );
}
