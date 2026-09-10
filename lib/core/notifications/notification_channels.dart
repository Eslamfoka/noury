import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'adhan_sounds.dart';
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
/// The five adhan channels, one per prayer.
///
/// Separate so five different recitations are possible — Android reads the
/// sound off the channel — and so the user can silence one prayer's call
/// without touching the others. All five carry alarm usage and max
/// importance: a prayer call at notification volume is easy to sleep through,
/// and that is the difference between hearing the adhan and missing it.
final adhanChannels = <AndroidNotificationChannel>[
  for (final prayer in adhanPrayers)
    AndroidNotificationChannel(
      adhanChannelFor(prayer),
      'الأذان — ${adhanArabicNames[prayer]}',
      description: 'إشعار دخول وقت ${adhanArabicNames[prayer]}',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(adhanSoundFor(prayer)),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    ),
];

const adhanArabicNames = <String, String>{
  'fajr': 'الفجر',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

final nouriChannels = <AndroidNotificationChannel>[
  ...adhanChannels,
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

/// The channel writes a launch actually has to make, given what the device
/// already holds.
///
/// **Why this is worth computing rather than just doing.** Startup used to
/// delete all 33 retired ids and create all ~30 current ones on every launch,
/// unconditionally, before Flutter was allowed to draw its first frame. Every
/// one of those is a platform round-trip, and on the second launch onward
/// every single one of them is a no-op: the retired channels were deleted the
/// first time and never come back, and creating a channel that already exists
/// changes nothing, because Android freezes a channel's sound, importance and
/// DND bypass at creation. One read of what the device holds costs one
/// round-trip and usually reduces the rest to zero.
///
/// A create is still issued when the **name or description** differs, which
/// are the only two fields Android will let a later create update. Everything
/// else about a channel is settled when it is born — which is why a retuned
/// tone means a new id rather than an edit, and why that rule is safe to lean
/// on here.
///
/// [existing] is what the system reports, not what Nouri asked for. On a
/// device that has never run Nouri it is empty and this returns the full
/// creation list, exactly as before.
({List<String> toDelete, List<AndroidNotificationChannel> toCreate})
    channelWorkFor({
  required Iterable<AndroidNotificationChannel> existing,
  Iterable<String> retired = retiredChannelIds,
  Iterable<AndroidNotificationChannel>? wanted,
}) {
  final live = {for (final c in existing) c.id: c};

  return (
    toDelete: [
      for (final id in retired)
        if (live.containsKey(id)) id,
    ],
    toCreate: [
      // The adhan channels are excluded here and created natively instead —
      // they are the only ones that need `setBypassDnd`, which this plugin
      // cannot express. Creating them from both places is the exact drift this
      // project has already paid for twice.
      for (final channel in wanted ?? nouriChannels)
        if (!isAdhanChannel(channel.id))
          if (_needsWriting(live[channel.id], channel)) channel,
    ],
  );
}

bool _needsWriting(
  AndroidNotificationChannel? live,
  AndroidNotificationChannel wanted,
) {
  if (live == null) return true;
  // Name and description are the whole of what a create can still change on a
  // channel that exists. Comparing more than that would mean re-issuing writes
  // Android is going to ignore.
  return live.name != wanted.name || live.description != wanted.description;
}

/// What a channel *is*, looked up by id.
///
/// An adhan channel has two ids — the ordinary one and the twin that bypasses
/// Do Not Disturb — and exactly one description, held against the base. Both
/// resolve to it, so there is no second place for a name, a sound or an
/// importance to be written down and then drift.
AndroidNotificationChannel _channelFor(String id) =>
    nouriChannels.firstWhere((c) => c.id == adhanBaseChannel(id));

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
  bool preview = false,
}) {
  final channel = _channelFor(channelId);
  // Membership, not equality: the one adhan channel became five, and every one
  // of them has to keep the full-screen intent and the alarm category.
  final isAdhan = isAdhanChannel(channelId);

  return AndroidNotificationDetails(
    // The id asked for, not the base it was described by: a bypassing adhan
    // must post to the channel that actually bypasses.
    channelId,
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
    //
    // **Except when auditioning.** In الأصوات the user plays five adhans in a
    // row to compare them; having each one seize the whole screen would make
    // the screen unusable for the one thing it is for. The sound, the volume
    // and the channel are all still the real ones — only the takeover goes.
    fullScreenIntent: isAdhan && !preview,
    // FLAG_INSISTENT (0x4): loop the sound until the notification is dealt
    // with, instead of playing it once into an empty room.
    //
    // The user asked for this in as many words — «make the adhan loud and
    // persistent, it should ring multiple times» — and his reason is the whole
    // point of the app: he sleeps through the day after a night shift, and a
    // single pass of the adhan at 04:00 is a sound that happens whether or not
    // anyone wakes for it.
    //
    // Only the adhan, and never in a preview. Looping the wird reminder would
    // be the kind of app that gets uninstalled, and looping a sound the user
    // pressed «شغّل» to audition would trap him on the settings screen.
    additionalFlags: isAdhan && !preview ? Int32List.fromList([4]) : null,
    // Persistent, not infinite. FLAG_INSISTENT loops until the notification is
    // dismissed, and the recitations are two to four minutes long — so a phone
    // left in another room would call the adhan over and over until its owner
    // came back to it, which is not devotion, it is a fault.
    //
    // Ten minutes is a little over two passes of the longest of them (fajr, at
    // 4m23s). Long enough to wake someone who is asleep, which is the whole
    // reason the flag is there; short enough that the prayer's own window is
    // never the thing being disturbed.
    timeoutAfter: isAdhan && !preview ? const Duration(minutes: 10).inMilliseconds : null,
    actions: actions,
  );
}
