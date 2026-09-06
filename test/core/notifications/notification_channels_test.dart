import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_channels.dart';

void main() {
  AndroidNotificationChannel channel(String id) =>
      nouriChannels.firstWhere((c) => c.id == id);

  test('there is exactly one channel per concern', () {
    expect(nouriChannels.map((c) => c.id).toSet(), allChannelIds.toSet());
    expect(nouriChannels.length, 5);
  });

  group('the adhan channel', () {
    test('carries the bundled chime, not the system default', () {
      final sound = channel(channelAdhan).sound;
      expect(sound, isA<RawResourceAndroidNotificationSound>());
      expect((sound as RawResourceAndroidNotificationSound).sound, 'chime');
      expect(channel(channelAdhan).playSound, isTrue);
    });

    test('uses alarm audio so it plays at alarm volume', () {
      // A prayer call at notification volume is easy to sleep through; this
      // is the difference between hearing the adhan and missing it.
      expect(
        channel(channelAdhan).audioAttributesUsage,
        AudioAttributesUsage.alarm,
      );
    });

    test('is the most important channel', () {
      expect(channel(channelAdhan).importance, Importance.max);
      // Note: an OEM may downgrade this on the device. HONOR/MagicOS was
      // observed running it at HIGH with mUserLockedFields=importance. HIGH
      // still sounds and shows a heads-up, so this is a degradation rather
      // than a failure — and it cannot be overridden from code once locked.
    });
  });

  group('the other channels', () {
    test('deliberately use the system default sound', () {
      for (final id in [
        channelIqama,
        channelAthkar,
        channelWird,
        channelGeneral,
      ]) {
        expect(channel(id).sound, isNull,
            reason: '$id should not carry a custom sound');
      }
    });

    test('are quieter than the adhan', () {
      for (final id in [channelAthkar, channelWird, channelGeneral]) {
        expect(channel(id).importance.value,
            lessThan(channel(channelAdhan).importance.value),
            reason: id);
      }
    });

    test('none of them uses alarm audio', () {
      // Only the adhan earns alarm volume. An athkar reminder at alarm volume
      // would be the kind of thing that makes people uninstall an app.
      for (final id in [
        channelIqama,
        channelAthkar,
        channelWird,
        channelGeneral,
      ]) {
        expect(channel(id).audioAttributesUsage,
            isNot(AudioAttributesUsage.alarm),
            reason: id);
      }
    });
  });

  test('every channel id is versioned', () {
    // Android freezes a channel's sound at creation, so changing the adhan
    // sound means creating adhan_v2 and deleting v1 — never editing v1.
    for (final id in allChannelIds) {
      expect(id, matches(RegExp(r'_v\d+$')), reason: id);
    }
  });
}
