import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_channels_ids.dart';
import 'task_alert.dart';

export 'notification_channels_ids.dart';

/// The `res/raw` resource holding the adhan audio, without extension.
///
/// Referenced by name at playback time, so R8 shortening the file path to
/// `res/d0.wav` is harmless — the resource table still maps the name. What
/// would break it is R8 *stripping* the file, which `res/raw/keep.xml`
/// prevents.
///
/// Changing this value means bumping [channelAdhan] to a new version in the
/// same commit. Android will not apply a new sound to an existing channel, so
/// editing one without the other silently keeps the old audio.
const adhanSoundResource = 'chime';

/// The core channels, kept separate so the user can silence one without
/// killing the others — muting the wird reminder must never mute the adhan.
///
/// Everything in [TaskAlertKind] adds one more, because Android reads a
/// notification's sound off its **channel**. "A different sound per task" and
/// "a channel per task" are the same sentence on Android.
const _coreChannels = <AndroidNotificationChannel>[
  AndroidNotificationChannel(
    channelAdhan,
    'الأذان',
    description: 'إشعار دخول وقت الصلاة',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound(adhanSoundResource),
    // Alarm usage so the adhan plays at alarm volume and is treated as
    // time-critical rather than as chatter.
    audioAttributesUsage: AudioAttributesUsage.alarm,
  ),
  AndroidNotificationChannel(
    channelIqama,
    'الإقامة',
    description: 'تنبيه قبل الإقامة',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    channelAthkar,
    'الأذكار',
    description: 'تذكير أذكار الصباح والمساء والنوم',
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    channelWird,
    'ورد القرآن',
    description: 'تذكير الورد اليومي',
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    channelGeneral,
    'نوري',
    description: 'متابعة نوري اليومية',
    importance: Importance.defaultImportance,
  ),
];

/// Every channel Nouri creates: the core ones plus one per alert kind.
///
/// The per-kind ones are **high** importance and carry alarm audio usage when
/// the kind asks to be heard, because the user's request was for alarms rather
/// than for chatter: «i need alarms for each task». The informational ones —
/// the budget note, the phone cap, the review, the soft «عملتها؟» — stay at
/// notification usage.
final nouriChannels = <AndroidNotificationChannel>[
  ..._coreChannels,
  for (final kind in TaskAlertKind.values)
    AndroidNotificationChannel(
      kind.channelId,
      kind.title,
      description: kind.body,
      importance: Importance.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(kind.sound),
      audioAttributesUsage: kind.asAlarm
          ? AudioAttributesUsage.alarm
          : AudioAttributesUsage.notification,
    ),
];

AndroidNotificationChannel _channelFor(String id) =>
    nouriChannels.firstWhere((c) => c.id == id);

/// The per-notification details for [channelId], **derived from the channel**.
///
/// This exists because the two were previously written out separately, and
/// they drifted: the channel carried the chime at alarm volume while the
/// notification carried nothing but an id. That mattered more than it looks.
/// A scheduled notification is delivered by `ScheduledNotificationReceiver`,
/// a pure-Java broadcast receiver where the app's `init()` has never run — so
/// on a fresh install whose first alarm fires before the app is first opened,
/// or after a reboot, the plugin creates the channel from *these* details.
/// With sound and usage missing, it would have created a permanently silent
/// adhan channel at notification volume, named `adhan_v1` rather than «الأذان».
///
/// Deriving one from the other makes that class of drift unrepresentable.
AndroidNotificationDetails androidDetailsFor(
  String channelId, {
  List<AndroidNotificationAction>? actions,
}) {
  final channel = _channelFor(channelId);
  final isAdhan = channelId == channelAdhan;

  return AndroidNotificationDetails(
    channel.id,
    channel.name,
    channelDescription: channel.description,
    importance: channel.importance,
    priority: isAdhan ? Priority.max : Priority.defaultPriority,
    playSound: channel.playSound,
    sound: channel.sound,
    audioAttributesUsage: channel.audioAttributesUsage,
    category: isAdhan
        ? AndroidNotificationCategory.alarm
        : AndroidNotificationCategory.reminder,
    // Lets the adhan light the screen on a locked phone instead of waiting in
    // the shade. Only the adhan earns this — using it for the wird reminder
    // would be the kind of app that gets uninstalled.
    fullScreenIntent: isAdhan,
    actions: actions,
  );
}
