import 'arabic_numerals.dart';

/// Counts prayers in grammatical Arabic.
///
/// Arabic does not pluralise the way English does. It has a dual form, and the
/// noun changes shape with the number:
///
///   1 → صلاة واحدة      (singular)
///   2 → صلاتين          (dual — no numeral at all)
///   3–10 → ٣ صلوات      (plural of paucity)
///
/// Writing `'$n صلوات'` for every n produces «١ صلوات», which reads as broken
/// machine Arabic. In an Arabic-first app that is a visible defect, not a
/// rounding error — so the cases are spelled out.
///
/// A day holds five prayers, so [n] never exceeds five and the 11-and-above
/// rule (which reverts to the singular: «١١ صلاة») cannot arise here.
String countPrayers(int n) => switch (n) {
      <= 0 => 'مفيش صلوات',
      1 => 'صلاة واحدة',
      2 => 'صلاتين',
      _ => '${toArabicDigits('$n')} صلوات',
    };

/// Counts days, by the same rules.
///
/// Used by the finance pillar for «باقي ٣ أيام في الشهر». Unlike prayers, a day
/// count can pass ten, so the singular-after-eleven rule applies: «١٥ يوم».
String countDays(int n) => switch (n) {
      <= 0 => 'النهاردة آخر يوم',
      1 => 'يوم واحد',
      2 => 'يومين',
      < 11 => '${toArabicDigits('$n')} أيام',
      _ => '${toArabicDigits('$n')} يوم',
    };
