import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_channels_ids.dart';

export 'notification_channels_ids.dart';

/// The five channels, kept separate so the user can silence one without
/// killing the others — muting the wird reminder must never mute the adhan.
///
/// Channel IDs are versioned (`adhan_v1`). Android freezes a channel's sound
/// at creation and ignores later changes to the same ID, so swapping the adhan
/// sound means creating `adhan_v2` and deleting the old one.
const nouriChannels = <AndroidNotificationChannel>[
  AndroidNotificationChannel(
    channelAdhan,
    'الأذان',
    description: 'إشعار دخول وقت الصلاة',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('chime'),
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
