/// Stride between days in the ID space.
///
/// Must exceed the slot count so `day * stride + slot` can never collide.
/// There is deliberate headroom: adding a slot later must not renumber the
/// alarms already scheduled on the user's device.
const kSlotsPerDay = 32;

/// The ID epoch.
///
/// **Never change this.** It would renumber every alarm already scheduled on
/// the user's device, orphaning them — they would fire under IDs the app no
/// longer recognises and could never be cancelled.
final _idEpoch = DateTime.utc(2020, 1, 1);

enum NotificationSlot {
  adhanFajr,
  iqamaFajr,
  followUpFajr,
  adhanDhuhr,
  iqamaDhuhr,
  followUpDhuhr,
  adhanAsr,
  iqamaAsr,
  followUpAsr,
  adhanMaghrib,
  iqamaMaghrib,
  followUpMaghrib,
  adhanIsha,
  iqamaIsha,
  followUpIsha,
  morningAthkar,
  eveningAthkar,
  sleepAthkar,
  quranWird,

  // Appended, never inserted. IDs derive from `index`, so putting these
  // anywhere but the end would renumber every alarm already on a device.
  // 25 slots against kSlotsPerDay = 32 still leaves headroom.
  followUp2Fajr,
  followUp2Dhuhr,
  followUp2Asr,
  followUp2Maghrib,
  followUp2Isha,

  /// The end-of-day review, offering to log whatever is still unanswered.
  dailySummary,
}

/// A notification's ID, derived purely from its date and slot.
///
/// This is the whole reliability strategy in one function: because the ID is
/// reproducible from the date alone, re-arming after a reboot — with no stored
/// state whatsoever — lands on exactly the same IDs and overwrites the previous
/// alarms instead of duplicating them.
int notificationIdFor(DateTime date, NotificationSlot slot) {
  final days = DateTime.utc(date.year, date.month, date.day)
      .difference(_idEpoch)
      .inDays;
  return days * kSlotsPerDay + slot.index;
}

/// The ceiling of the rolling window's ID range, and the floor of everything
/// scheduled outside it (reminders, today).
///
/// The window numbers alarms `daysSince2020 * 32 + slot`: about 78,000 today,
/// climbing roughly 11,700 a year, so it does not reach this base until some
/// time around the year 2098. **Never change it** — lowering it could collide
/// with a live alarm, and raising it would orphan every reminder already
/// scheduled on the device, leaving alarms the app can no longer cancel.
///
/// This is why [RollingWindowScheduler] clears its window with
/// `cancelAllBelow(kOutOfWindowIdBase)` rather than `cancelAll()`: "clear
/// everything" must mean "clear everything I own", or re-arming the adhan
/// would silently delete the user's reminders.
const kOutOfWindowIdBase = 900000000;

class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.slot,
    required this.when,
    required this.title,
    required this.body,
    required this.channelId,
    this.payload,
  });

  final int id;
  final NotificationSlot slot;
  final DateTime when;
  final String title;
  final String body;
  final String channelId;
  final String? payload;

  @override
  String toString() =>
      'ScheduledNotification($id, ${slot.name}, $when, $channelId)';
}
