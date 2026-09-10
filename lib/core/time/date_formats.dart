import '../format/arabic_numerals.dart';

/// Weekday names, indexed by `DateTime.weekday` (1 = Monday … 7 = Sunday).
const _arabicWeekdays = <int, String>{
  1: 'الإثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
  7: 'الأحد',
};

const _englishWeekdays = <int, String>{
  1: 'Monday',
  2: 'Tuesday',
  3: 'Wednesday',
  4: 'Thursday',
  5: 'Friday',
  6: 'Saturday',
  7: 'Sunday',
};

/// Gregorian month names as used in Egypt and the Gulf (يناير, not كانون الثاني).
const _arabicGregorianMonths = <int, String>{
  1: 'يناير',
  2: 'فبراير',
  3: 'مارس',
  4: 'أبريل',
  5: 'مايو',
  6: 'يونيو',
  7: 'يوليو',
  8: 'أغسطس',
  9: 'سبتمبر',
  10: 'أكتوبر',
  11: 'نوفمبر',
  12: 'ديسمبر',
};

const _englishGregorianMonths = <int, String>{
  1: 'January',
  2: 'February',
  3: 'March',
  4: 'April',
  5: 'May',
  6: 'June',
  7: 'July',
  8: 'August',
  9: 'September',
  10: 'October',
  11: 'November',
  12: 'December',
};

/// Hijri month names, spelled our own way rather than taken from the `hijri`
/// package, which ships `ربيع الاول` (missing the hamza) and the masculine
/// `جمادى الأول` where the correct form is feminine, `جمادى الأولى`.
///
/// Months 4 and 6 use the classical الآخر / الآخرة. ربيع الثاني and
/// جمادى الثانية are equally acceptable and common in Egypt — change here if
/// you prefer them.
const arabicHijriMonths = <int, String>{
  1: 'محرم',
  2: 'صفر',
  3: 'ربيع الأول',
  4: 'ربيع الآخر',
  5: 'جمادى الأولى',
  6: 'جمادى الآخرة',
  7: 'رجب',
  8: 'شعبان',
  9: 'رمضان',
  10: 'شوال',
  11: 'ذو القعدة',
  12: 'ذو الحجة',
};

const englishHijriMonths = <int, String>{
  1: 'Muharram',
  2: 'Safar',
  3: "Rabi' al-Awwal",
  4: "Rabi' al-Akhir",
  5: 'Jumada al-Ula',
  6: 'Jumada al-Akhirah',
  7: 'Rajab',
  8: "Sha'ban",
  9: 'Ramadan',
  10: 'Shawwal',
  11: "Dhu al-Qi'dah",
  12: 'Dhu al-Hijjah',
};

/// The full Gregorian date, e.g. «الأحد، ٦ سبتمبر ٢٠٢٦» or
/// «Sunday, 6 September 2026».
///
/// Arabic renders with Arabic-Indic numerals; English keeps western digits.
String formatGregorianLong(DateTime date, {bool arabic = true}) {
  if (arabic) {
    final weekday = _arabicWeekdays[date.weekday]!;
    final month = _arabicGregorianMonths[date.month]!;
    return toArabicDigits('$weekday، ${date.day} $month ${date.year}');
  }

  final weekday = _englishWeekdays[date.weekday]!;
  final month = _englishGregorianMonths[date.month]!;
  return '$weekday, ${date.day} $month ${date.year}';
}
