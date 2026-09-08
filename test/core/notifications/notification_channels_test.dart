import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_channels.dart';
import 'package:nouri/core/notifications/task_alert.dart';

void main() {
  AndroidNotificationChannel channel(String id) =>
      nouriChannels.firstWhere((c) => c.id == id);

  test('the channel list and the id list agree', () {
    // A channel created but not listed is one nothing ever deletes, leaving a
    // stray row in the user's system notification settings.
    expect(nouriChannels.map((c) => c.id).toSet(), allChannelIds.toSet());
  });

  test('there are five core channels plus one per alert kind', () {
    // The count is not arbitrary: Android reads a notification's sound off its
    // channel, so «a different sound for every task» and «a channel for every
    // task» are the same sentence.
    expect(nouriChannels.length, coreChannelIds.length + TaskAlertKind.values.length);
  });

  test('every alert kind has its channel, carrying its own sound', () {
    for (final kind in TaskAlertKind.values) {
      final c = channel(kind.channelId);
      expect(c.sound, isA<RawResourceAndroidNotificationSound>(),
          reason: kind.name);
      expect((c.sound as RawResourceAndroidNotificationSound).sound, kind.sound,
          reason: kind.name);
      expect(c.playSound, isTrue, reason: kind.name);
    }
  });

  test('no two channels carry the same sound', () {
    // The whole point of the slice: the user must be able to tell which task
    // is calling by ear.
    final sounds = <String>[];
    for (final c in nouriChannels) {
      final s = c.sound;
      if (s is RawResourceAndroidNotificationSound) sounds.add(s.sound);
    }
    expect(sounds.toSet().length, sounds.length);
  });

  test('the kinds that summon you use alarm volume; the rest do not', () {
    // «i need alarms for each task» — but waking someone at alarm volume to
    // mention a budget would be the kind of app that gets uninstalled.
    for (final kind in TaskAlertKind.values) {
      expect(
        channel(kind.channelId).audioAttributesUsage,
        kind.asAlarm
            ? AudioAttributesUsage.alarm
            : AudioAttributesUsage.notification,
        reason: kind.name,
      );
    }
  });

  group('the adhan channel', () {
    test('carries the bundled chime, not the system default', () {
      final sound = channel(channelAdhan).sound;
      expect(sound, isA<RawResourceAndroidNotificationSound>());
      expect((sound as RawResourceAndroidNotificationSound).sound,
          adhanSoundResource);
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

  group('notification details derived from the channel', () {
    // These exist because the two were once written out separately and
    // drifted: the channel carried the chime at alarm volume while the
    // notification carried nothing but an id. On a device where the channel
    // did not yet exist, the receiver would have created a permanently silent
    // adhan channel from those empty details.

    test('the adhan notification carries the sound, not just the channel id',
        () {
      final d = androidDetailsFor(channelAdhan);
      expect(d.sound, isA<RawResourceAndroidNotificationSound>());
      expect((d.sound! as RawResourceAndroidNotificationSound).sound,
          adhanSoundResource);
      expect(d.playSound, isTrue);
    });

    test('the adhan notification keeps alarm usage and max importance', () {
      final d = androidDetailsFor(channelAdhan);
      expect(d.audioAttributesUsage, AudioAttributesUsage.alarm);
      expect(d.importance, Importance.max);
      expect(d.priority, Priority.max);
    });

    test('the adhan can light a locked screen', () {
      expect(androidDetailsFor(channelAdhan).fullScreenIntent, isTrue);
      expect(androidDetailsFor(channelAdhan).category,
          AndroidNotificationCategory.alarm);
    });

    test('nothing but the adhan gets a full-screen intent', () {
      for (final id in [
        channelIqama,
        channelAthkar,
        channelWird,
        channelGeneral,
      ]) {
        expect(androidDetailsFor(id).fullScreenIntent, isFalse, reason: id);
        expect(androidDetailsFor(id).audioAttributesUsage,
            isNot(AudioAttributesUsage.alarm),
            reason: id);
      }
    });

    test('every channel presents a human name, never its raw id', () {
      // The id leaked into the name field before. A user looking for the
      // adhan in system settings would have found a row called "adhan_v1".
      for (final id in allChannelIds) {
        final d = androidDetailsFor(id);
        expect(d.channelName, isNot(id), reason: id);
        expect(d.channelName, isNotEmpty, reason: id);
      }
    });

    test('details agree with the channel they came from', () {
      for (final c in nouriChannels) {
        final d = androidDetailsFor(c.id);
        expect(d.channelId, c.id);
        expect(d.channelName, c.name);
        expect(d.importance, c.importance, reason: c.id);
        expect(d.audioAttributesUsage, c.audioAttributesUsage, reason: c.id);
        expect(d.sound, c.sound, reason: c.id);
      }
    });
  });

  group('retired channels', () {
    test('adhan_v1 is retired so its locked importance is abandoned', () {
      // MagicOS downgraded adhan_v1 to IMPORTANCE_DEFAULT and set
      // mUserLockedFields, which no API can undo. Only a fresh id starts
      // clean, and the old row has to go or the user sees two «الأذان» rows.
      expect(retiredChannelIds, contains('adhan_v1'));
      expect(channelAdhan, isNot('adhan_v1'));
    });

    test('a retired id is never also a live one', () {
      for (final id in retiredChannelIds) {
        expect(allChannelIds, isNot(contains(id)), reason: id);
      }
    });

    test('the adhan sound and the channel version move together', () {
      // A tripwire, not a rule: Android ignores a new sound on an existing
      // channel, so changing the resource without bumping the id would
      // silently keep the old audio. Changing either half must fail here and
      // force the other half to be considered.
      expect(
        [channelAdhan, adhanSoundResource],
        ['adhan_v2', 'chime'],
        reason: 'changing the adhan audio requires a new channel version',
      );
    });
  });
}
