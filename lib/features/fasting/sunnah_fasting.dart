import '../../core/format/arabic_numerals.dart';
import '../../core/time/hijri_date.dart';

/// Why a day is a sunnah fast.
///
/// Only what the brief names: Mondays, Thursdays, and the white days. Other
/// occasions — Arafah, Ashura, the six of Shawwal — are deliberately **not**
/// here. Deciding which further days Nouri should suggest fasting is a
/// religious question, and this file follows the same rule as the athkar: an
/// AI does not settle those alone. See `docs/fasting-verification.md`.
enum SunnahFastKind { monday, thursday, whiteDay }

/// A day Nouri may suggest fasting, and why.
class SunnahFastDay {
  const SunnahFastDay({required this.date, required this.kinds});

  final DateTime date;
  final List<SunnahFastKind> kinds;

  bool get isWhiteDay => kinds.contains(SunnahFastKind.whiteDay);
}

/// Days on which fasting is prohibited.
///
/// This is the half that matters most. The white days are the 13th, 14th and
/// 15th of every Hijri month — but in ذو الحجة the 13th is one of أيام
/// التشريق, when fasting is forbidden. A naive "13, 14, 15 every month" would
/// have Nouri suggest a forbidden fast once a year, which is far worse than
/// suggesting nothing.
///
/// Covered: عيد الفطر (1 Shawwal), عيد الأضحى (10 Dhul-Hijjah) and the three
/// days of التشريق that follow it (11, 12, 13 Dhul-Hijjah).
bool isFastingProhibited(DateTime day, {int hijriOffsetDays = 0}) {
  final h = hijriFor(day, offsetDays: hijriOffsetDays);

  // 1 شوال — عيد الفطر.
  if (h.month == 10 && h.day == 1) return true;

  // 10 ذو الحجة — عيد الأضحى — and 11-13, أيام التشريق.
  if (h.month == 12 && h.day >= 10 && h.day <= 13) return true;

  return false;
}

/// Whether [day] is a sunnah fast, and why — or null if it is neither, or if
/// fasting that day is prohibited.
SunnahFastDay? sunnahFastFor(DateTime day, {int hijriOffsetDays = 0}) {
  if (isFastingProhibited(day, hijriOffsetDays: hijriOffsetDays)) return null;

  final kinds = <SunnahFastKind>[];

  if (day.weekday == DateTime.monday) kinds.add(SunnahFastKind.monday);
  if (day.weekday == DateTime.thursday) kinds.add(SunnahFastKind.thursday);

  final h = hijriFor(day, offsetDays: hijriOffsetDays);
  if (h.day >= 13 && h.day <= 15) kinds.add(SunnahFastKind.whiteDay);

  if (kinds.isEmpty) return null;
  return SunnahFastDay(date: day, kinds: kinds);
}

/// The line shown the evening before, naming tomorrow.
///
/// Phrased as an offer, never an instruction: Nouri says what tomorrow is and
/// leaves the decision alone. The brief's rule for the whole app — encourage,
/// never oblige — applies to worship most of all.
String fastingEveBody(SunnahFastDay day) {
  final parts = <String>[];

  if (day.kinds.contains(SunnahFastKind.monday)) parts.add('الاتنين');
  if (day.kinds.contains(SunnahFastKind.thursday)) parts.add('الخميس');
  if (day.isWhiteDay) {
    parts.add(toArabicDigits('من الأيام البيض (١٣ و١٤ و١٥)'));
  }

  final what = parts.join(' و');
  return 'بكرة $what. لو حابب تصوم، دي نيّتك من دلوقتي.';
}
