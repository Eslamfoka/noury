import '../../core/format/arabic_numerals.dart';
import '../../core/time/prayer_times_service.dart';

/// When to nudge the user to drink, and how the day's intake is reading.
///
/// Reminders ride the prayers rather than a clock interval. Five times a day
/// the user already stops what they are doing; hanging the water on that costs
/// no new interruption, and "after every prayer" is a rule someone can keep in
/// their head. A two-hourly alarm is a rule nobody keeps.
///
/// Everything here is pure — no database, no clock, no plugin — so the whole
/// of it is testable without a device.

/// The default target.
///
/// Eight glasses is the familiar figure and a reasonable default for an adult
/// in the Gulf. It is a setting, not a rule: Nouri is not a doctor and the
/// number is a prompt rather than a prescription.
const kDefaultWaterGlasses = 8;

/// How much of the day's target is done.
class WaterProgress {
  const WaterProgress({required this.glasses, required this.target});

  final int glasses;
  final int target;

  double get fraction =>
      target <= 0 ? 0 : (glasses / target).clamp(0.0, 1.0);

  int get remaining => (target - glasses).clamp(0, target);
  bool get isComplete => glasses >= target;

  /// What Nouri says about the day so far.
  ///
  /// Never a reprimand, and never a health claim. Falling short of a target is
  /// not a failure — it is a number, and the user can see it.
  String get arabicNote {
    if (target <= 0) return '';
    if (isComplete) return 'كفاية كده النهاردة — تمام.';
    if (glasses == 0) return 'ابدأ بكوباية.';
    return toArabicDigits('فاضل $remaining كوباية.');
  }
}

/// Whether a water reminder should go out after [prayer] on a day the user is
/// fasting from [fajr] to [maghrib].
///
/// The whole reason this function exists. Water is fine during 16/8
/// intermittent fasting — that window restricts food, not drink — but during a
/// religious fast nothing passes the lips between fajr and maghrib. A reminder
/// to drink at noon on a Monday the user is fasting would be Nouri telling
/// them to break it.
bool waterReminderAllowed({
  required DateTime at,
  required bool fastingToday,
  required DateTime fajr,
  required DateTime maghrib,
}) {
  if (!fastingToday) return true;
  // Outside the fast: before fajr or from maghrib onwards.
  return at.isBefore(fajr) || !at.isBefore(maghrib);
}

/// The times a water reminder should fire on this day.
///
/// One shortly after each prayer, dropped where the fast forbids it. The
/// offset keeps it clear of the prayer itself and of the iqama that follows.
List<DateTime> waterReminderTimes({
  required DailyPrayerTimes prayers,
  required bool fastingToday,
  Duration afterPrayer = const Duration(minutes: 25),
}) {
  final out = <DateTime>[];
  for (final slot in prayers.ordered) {
    final at = slot.time.add(afterPrayer);
    if (!waterReminderAllowed(
      at: at,
      fastingToday: fastingToday,
      fajr: prayers.fajr,
      maghrib: prayers.maghrib,
    )) {
      continue;
    }
    out.add(at);
  }
  return out;
}

/// The line the reminder carries.
///
/// Phrased as an offer. On a fasting evening it says so, because "drink some
/// water" the moment a fast opens reads very differently from the same words
/// at noon.
String waterReminderBody({required bool afterFast}) => afterFast
    ? 'فطرت — اشرب مياه على راحتك.'
    : 'خد كوباية مياه.';
