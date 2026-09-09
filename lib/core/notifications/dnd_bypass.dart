import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// The Dart half of `DndPlugin.kt` — letting the adhan through Do Not Disturb.
///
/// **Why this exists at all.** The user works night shifts and sleeps through
/// the day with Do Not Disturb on. Measured on his phone on 8 September 2026,
/// all five adhan channels reported `mBypassDnd=false`, so every prayer call
/// he most needed was the one DND silenced. `flutter_local_notifications` does
/// not expose `setBypassDnd`, so the capability had to be written natively.
///
/// **Two Android facts shape the whole design**, and neither is negotiable:
///
/// 1. Bypassing DND needs `ACCESS_NOTIFICATION_POLICY`, which the *user* grants
///    on a system screen. No app can raise a dialog for it, and until it is
///    granted `setBypassDnd(true)` is accepted and quietly ignored.
/// 2. A channel's bypass is fixed when the channel is created, exactly like its
///    sound. Creating it again under the same id changes nothing.
///
/// So a channel that bypasses has to be a *different channel*, created after
/// access is held — which is why [adhanChannelSuffix] exists and why granting
/// access has to re-arm the window. Everything Nouri already knows about
/// channel versioning applies here; this is the same rule wearing a new hat.
/// The suffix that marks the bypassing variant lives beside the ids it belongs
/// to, in `adhan_sounds.dart`, and is not repeated here.
class DndBypass {
  const DndBypass();

  static const _channel = MethodChannel('com.nouri.nouri/dnd');

  /// Whether the user has granted notification-policy access.
  ///
  /// **Answers false off Android without touching the channel at all**, which
  /// is not merely a convenience. `schedulingConfigFromDb` calls this, and that
  /// function is exercised by a large number of pure unit tests running on the
  /// desktop VM: reaching for a platform channel there does not politely
  /// return null, it leaves the future hanging, and the re-arm that was
  /// supposed to follow simply never happens. That failure is invisible —
  /// nothing throws, the test just observes that no window was armed — which
  /// is exactly how it presented when this was first written the other way
  /// round.
  ///
  /// False on any failure, for the same reason: every caller is on a path
  /// where the adhan still has to be scheduled, and an adhan that does not
  /// bypass DND beats an adhan that was never armed.
  Future<bool> hasPolicyAccess() async {
    if (!_androidOnly) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPolicyAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Whether the native half can exist at all.
  ///
  /// `Platform.isAndroid` rather than `defaultTargetPlatform`: the latter
  /// reports Android inside `flutter test` on a desktop machine, which is the
  /// one place this must say no.
  static bool get _androidOnly {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Sends the user to the system screen that grants it.
  ///
  /// Returns false when the screen could not be opened — some manufacturers
  /// remove it — so the caller can say so instead of leaving the user staring
  /// at Nouri waiting for something that is never going to appear.
  Future<bool> openPolicySettings() async {
    if (!_androidOnly) return false;
    try {
      return await _channel.invokeMethod<bool>('openPolicySettings') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Creates the adhan channels, bypassing DND where that is permitted.
  ///
  /// Returns the bypass state **read back off each created channel**, never
  /// the state that was requested. The two differ precisely when access has
  /// not been granted, and a screen that reported the request would tell the
  /// user his adhan will wake him when it will not.
  Future<Map<String, bool>> ensureAdhanChannels(
    List<AdhanChannelSpec> specs,
  ) async {
    if (!_androidOnly) return const {};
    try {
      final result = await _channel.invokeMapMethod<String, bool>(
        'ensureAdhanChannels',
        {'channels': [for (final s in specs) s.toMap()]},
      );
      return result ?? const {};
    } catch (_) {
      return const {};
    }
  }

  /// Deletes channels by id — the variant that is no longer current.
  Future<void> deleteChannels(List<String> ids) async {
    if (ids.isEmpty || !_androidOnly) return;
    try {
      await _channel.invokeMethod<bool>('deleteChannels', {'ids': ids});
    } catch (_) {
      // A channel that cannot be deleted is a stale row in system settings,
      // not a broken alarm.
    }
  }

  /// Channels as the *system* holds them, not as the app asked for them.
  ///
  /// The distinction is not academic. MagicOS creates the adhan channels at
  /// importance 4 when the app asks for 5, and locks the field. A settings
  /// screen that printed the request would be wrong on the one device that
  /// matters most here.
  ///
  /// **Pass [ids] when only some are wanted.** Nouri owns about thirty
  /// channels and each crosses the platform boundary as a map of six values;
  /// asking for all of them to answer a question about five is waste, and the
  /// filter runs natively so the other twenty-five never cross at all.
  ///
  /// It is not, however, a fix for anything measured. `readStatus` takes about
  /// 5.5s on a cold-booted emulator, and narrowing this call from thirty
  /// channels to five moved that by 40ms — inside the noise. Whatever costs
  /// those seconds is elsewhere on that path, most likely `permission_handler`
  /// on a cold start, and it was there before this method existed. Worth
  /// chasing; not chased here.
  Future<List<ChannelReport>> channelReport({List<String>? ids}) async {
    if (!_androidOnly) return const [];
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
        'channelReport',
        {'ids': ids},
      );
      return [for (final row in raw ?? const []) ChannelReport.fromMap(row)];
    } catch (_) {
      return const [];
    }
  }
}

/// One adhan channel to create, as the native side wants it.
class AdhanChannelSpec {
  const AdhanChannelSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.sound,
    required this.bypass,
  });

  final String id;
  final String name;
  final String description;
  final String sound;
  final bool bypass;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'sound': sound,
        'bypass': bypass,
      };
}

/// A channel as the system currently holds it.
class ChannelReport {
  const ChannelReport({
    required this.id,
    required this.name,
    required this.importance,
    required this.bypassDnd,
    required this.sound,
  });

  factory ChannelReport.fromMap(Map<Object?, Object?> map) => ChannelReport(
        id: '${map['id']}',
        name: map['name'] == null ? null : '${map['name']}',
        importance: map['importance'] is int ? map['importance'] as int : 0,
        bypassDnd: map['bypassDnd'] == true,
        sound: map['sound'] == null ? null : '${map['sound']}',
      );

  final String id;
  final String? name;

  /// Android's own scale: 0 none … 5 max. MagicOS caps Nouri's adhan at 4.
  final int importance;

  final bool bypassDnd;
  final String? sound;
}
