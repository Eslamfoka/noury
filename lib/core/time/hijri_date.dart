import 'package:hijri/hijri_calendar.dart';

import '../format/arabic_numerals.dart';

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

  /// e.g. ١٢ صفر ١٤٤٧ هـ
  final String formatted;
}

/// Converts a Gregorian date to Hijri.
///
/// The civil calculation can differ from local moon sighting by a day, so the
/// user can nudge it by ±1 in Settings — [offsetDays].
HijriDate hijriFor(DateTime gregorian, {int offsetDays = 0}) {
  // The package keeps its locale in a static field, so set it every call
  // rather than relying on initialisation order elsewhere.
  HijriCalendar.setLocal('ar');

  final h = HijriCalendar.fromDate(gregorian.add(Duration(days: offsetDays)));

  return HijriDate(
    day: h.hDay,
    monthName: h.longMonthName,
    year: h.hYear,
    formatted: toArabicDigits('${h.hDay} ${h.longMonthName} ${h.hYear} هـ'),
  );
}
