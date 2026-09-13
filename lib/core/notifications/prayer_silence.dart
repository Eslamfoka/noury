import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../time/prayer_times_service.dart';

/// The phone going silent for the prayer.
///
/// The user's request of 13 September 2026: «عايزك تظبط الصامت من بعد الأذان
/// لحد ميعاد بعد الصلاة يعني من الاذان للأقامة ومثلا ١٠ دقايق صلاه وبعدين
/// يرجع تاني عام مش صامت». From the adhan, through the iqama gap, through
/// the prayer itself, then back to normal.
///
/// **Two halves.** This file computes *when* — one window per prayer per
/// day, from the same prayer times and iqama offsets the alarms use, so the
/// silence and the adhan can never disagree. `PrayerSilencePlugin.kt` does
/// the *what*: it holds the windows in AlarmManager, and at each edge its
/// receiver sets or lifts Do-Not-Disturb — without the app running, which is
/// the whole reason it is native.
///
/// **Alarms-only, not silent-silent.** The receiver uses the interruption
/// filter `ALARMS`, which is what Android itself does when you drag the
/// ringer to silent on a modern phone: calls and notifications are muted,
/// alarms still sound. The adhan, the iqama and every task tone are on the
/// alarm stream, so they get through; a phone call during the prayer does
/// not. And it **only touches a phone that was not already in a DND mode**,
/// so a night-shift user asleep with DND on keeps his DND after fajr —
/// setting the ringer to normal at the restore edge would have switched his
/// DND off, which is the one thing this must never do.
class SilenceWindow {
  const SilenceWindow({
    required this.prayer,
    required this.silenceAt,
    required this.restoreAt,
  });

  /// fajr | dhuhr | asr | maghrib | isha
  final String prayer;

  /// The adhan. Silence begins here.
  final DateTime silenceAt;

  /// Iqama plus the prayer's own minutes. Silence lifts here.
  final DateTime restoreAt;

  Map<String, Object?> toMap() => {
        'prayer': prayer,
        'silenceAt': silenceAt.millisecondsSinceEpoch,
        'restoreAt': restoreAt.millisecondsSinceEpoch,
      };

  @override
  String toString() => 'SilenceWindow($prayer $silenceAt → $restoreAt)';
}

/// How many days ahead the silence is armed.
///
/// Three, like the task alarms: every launch re-arms, and each window is two
/// exact alarms, so three days is thirty alarms against the platform's cap
/// of five hundred per app — the fortnight the adhan gets would be a hundred
/// and forty, and the alarm list is already near three hundred.
const kSilenceWindowDays = 3;

/// One window per prayer over [days], skipping any already over.
///
/// A window whose adhan has passed but whose restore has not is **kept**:
/// the app may have been opened mid-prayer, the phone may already be silent
/// from the earlier alarm, and the restore is the half that matters then.
/// The native side will not silence for a start that is already stale.
List<SilenceWindow> silenceWindowsFor({
  required List<(DateTime, DailyPrayerTimes)> days,
  required Map<String, int> iqamaOffsets,
  required int prayerMinutes,
  required DateTime now,
}) {
  final out = <SilenceWindow>[];
  for (final (_, times) in days) {
    for (final slot in times.ordered) {
      final iqama = iqamaFor(slot, iqamaOffsets);
      final restoreAt = iqama.add(Duration(minutes: prayerMinutes));
      if (!restoreAt.isAfter(now)) continue;
      out.add(SilenceWindow(
        prayer: slot.name,
        silenceAt: slot.time,
        restoreAt: restoreAt,
      ));
    }
  }
  return out;
}

/// What the scheduler needs from the platform.
///
/// An interface so the scheduler's many pure tests never touch a channel;
/// null there, [MethodChannelPrayerSilence] in `main()`.
abstract interface class PrayerSilencePort {
  /// Replaces every armed window with these.
  Future<void> schedule(List<SilenceWindow> windows);

  /// Disarms everything, and lifts a silence this app set if one is on.
  Future<void> cancelAll();
}

/// The Dart half of `PrayerSilencePlugin.kt`.
class MethodChannelPrayerSilence implements PrayerSilencePort {
  const MethodChannelPrayerSilence();

  static const _channel = MethodChannel('com.nouri.nouri/silence');

  static bool get _androidOnly {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> schedule(List<SilenceWindow> windows) async {
    if (!_androidOnly) return;
    try {
      await _channel.invokeMethod<void>('schedule', {
        'windows': [for (final w in windows) w.toMap()],
      });
    } catch (_) {
      // The silence is a courtesy on top of a working app. Losing a re-arm
      // of it costs one prayer's quiet, never an adhan.
    }
  }

  @override
  Future<void> cancelAll() async {
    if (!_androidOnly) return;
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } catch (_) {
      // Same: best-effort.
    }
  }
}
