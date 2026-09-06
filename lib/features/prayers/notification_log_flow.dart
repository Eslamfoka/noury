import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/prayer_times_service.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import 'prayer_log_sheet.dart';

/// Opens the log sheet for [prayerName] after the user taps a follow-up.
///
/// The notification only knows which prayer it asked about, so the scheduled
/// time is looked up here rather than carried in the payload — a payload is a
/// wire format read back days later, and the less it has to stay true about,
/// the better.
///
/// Silently does nothing if the prayer is unknown or today's times cannot be
/// computed. A tap that opens the app and shows nothing is a poor outcome, but
/// far better than a crash launched from the notification shade.
Future<void> logPrayerFromNotification(
  BuildContext context,
  WidgetRef ref,
  String prayerName,
) async {
  final times = ref.read(todayPrayerTimesProvider).value;
  if (times == null) return;

  PrayerSlot? slot;
  for (final s in times.ordered) {
    if (s.name == prayerName) slot = s;
  }
  if (slot == null) return;

  final current =
      (ref.read(todayPrayerLogsProvider).value ?? const {})[prayerName] ??
          PrayerState.none;

  if (!context.mounted) return;
  final chosen = await showPrayerLogSheet(context, prayerName, current);
  if (chosen == null) return;

  await ref.read(databaseProvider).prayerDao.upsertLog(
        date: DateTime.now(),
        prayer: prayerName,
        scheduledTime: slot.time,
        state: chosen,
      );
  ref.invalidate(todayPrayerLogsProvider);
}
