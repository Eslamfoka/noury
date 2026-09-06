import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/notifications/notification_slot.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';

/// The follow-up slots for each prayer, so an answer can silence them.
const _followUpSlotsFor = <String, List<NotificationSlot>>{
  'fajr': [NotificationSlot.followUpFajr, NotificationSlot.followUp2Fajr],
  'dhuhr': [NotificationSlot.followUpDhuhr, NotificationSlot.followUp2Dhuhr],
  'asr': [NotificationSlot.followUpAsr, NotificationSlot.followUp2Asr],
  'maghrib': [
    NotificationSlot.followUpMaghrib,
    NotificationSlot.followUp2Maghrib,
  ],
  'isha': [NotificationSlot.followUpIsha, NotificationSlot.followUp2Isha],
};

/// Records how a prayer was prayed, and stops asking about it.
///
/// The single place a prayer log is written. It used to be duplicated across
/// Home, the daily review and the notification tap, which is how the second
/// half of this function came to be missing from all three.
///
/// That second half matters. Both follow-ups are armed hours in advance and
/// have no way to learn they have been answered, so an already-logged prayer
/// would still be asked about an hour later. Deterministic ids are what make
/// the fix cheap: the alarm for a given date and slot is derivable, so it can
/// be cancelled without having stored anything.
///
/// Cancelling is best-effort. If it fails the log is still correct and the
/// worst case is one redundant question, so it must never take the write down
/// with it.
Future<void> logPrayer(
  WidgetRef ref, {
  required String prayer,
  required DateTime scheduledTime,
  required PrayerState state,
  DateTime? on,
}) async {
  final date = on ?? DateTime.now();

  await ref.read(databaseProvider).prayerDao.upsertLog(
        date: date,
        prayer: prayer,
        scheduledTime: scheduledTime,
        state: state,
      );
  ref.invalidate(todayPrayerLogsProvider);

  // Clearing an entry should put the questions back, not silence them.
  if (state == PrayerState.none) return;

  final slots = _followUpSlotsFor[prayer];
  if (slots == null) return;

  final service = ref.read(notificationServiceProvider);
  if (service == null) return;

  for (final slot in slots) {
    try {
      await service.cancel(notificationIdFor(date, slot));
    } catch (_) {
      // A failed cancel costs one extra question. A thrown error would cost
      // the user their log entry.
    }
  }
}
