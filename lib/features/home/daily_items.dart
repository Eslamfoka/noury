import '../../core/format/arabic_numerals.dart';

/// The nine things Nouri tracks each day in this slice: the five prayers, the
/// morning and evening athkar, the tasbeeh wird, and the Qur'an wird.
///
/// The Home ring shows a plain count of these — not a percentage, and never a
/// failure state. It fills; it never turns red.
const kDailyItemTotal = 9;

class DailyItemCount {
  const DailyItemCount(this.done, this.total);

  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
  bool get isComplete => done >= total;
}

abstract final class DailyItems {
  static DailyItemCount count({
    required int loggedPrayers,
    required bool morningAthkarDone,
    required bool eveningAthkarDone,
    required bool tasbeehDone,
    required bool quranWirdDone,
  }) {
    final done = loggedPrayers +
        (morningAthkarDone ? 1 : 0) +
        (eveningAthkarDone ? 1 : 0) +
        (tasbeehDone ? 1 : 0) +
        (quranWirdDone ? 1 : 0);
    return DailyItemCount(done, kDailyItemTotal);
  }
}

String greetingFor(DateTime now) {
  if (now.hour >= 5 && now.hour < 12) return 'صباح الخير';
  if (now.hour >= 12 && now.hour < 23) return 'مساء الخير';
  return 'ليلة طيبة';
}

/// Nouri's line under the progress ring.
///
/// Colloquial, and never a reprimand: a day with nothing done yet is an open
/// door ("الصفحة لسه بيضا"), not a failure. Nothing here counts what was
/// missed — only what is still available.
String nouriProgressLine(DailyItemCount c) {
  final done = toArabicDigits('${c.done}');
  final total = toArabicDigits('${c.total}');

  if (c.isComplete) return 'خلّصت ورد النهاردة كله. تمام.';
  if (c.done == 0) return 'الصفحة لسه بيضا. ابدأ باللي يريّحك.';
  return 'خلّصت $done من $total. لسه فيه وقت.';
}
