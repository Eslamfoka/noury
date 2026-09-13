import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the two receiver declarations that scheduled notifications depend on.
///
/// This exists because their absence fails **silently and completely**:
/// `zonedSchedule` succeeds, `dumpsys alarm` shows the alarm correctly armed
/// with the right time and exact-alarm permission, and then nothing happens at
/// the appointed moment. AlarmManager fires, finds no such component, and
/// drops the intent without an error or a log line.
///
/// That is exactly what happened on the HONOR device: 262 prayer alarms were
/// armed and not one of them could ever have been delivered, because
/// `ScheduledNotificationReceiver` was missing from the manifest. Nothing in
/// the Dart test suite could see it, and the emulator pass had only exercised
/// the instant-notification path, which does not use a receiver at all.
void main() {
  late String manifest;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  bool declaresReceiver(String className) => manifest.contains(
        RegExp(
          '<receiver[^>]*android:name="com\\.dexterous\\.flutterlocalnotifications\\.$className"',
          multiLine: true,
        ),
      );

  test('the delivery receiver is declared', () {
    // Without this, every scheduled notification is silently dropped.
    expect(declaresReceiver('ScheduledNotificationReceiver'), isTrue,
        reason: 'ScheduledNotificationReceiver missing — scheduled '
            'notifications will arm correctly and never fire');
  });

  test('the boot receiver is declared', () {
    expect(declaresReceiver('ScheduledNotificationBootReceiver'), isTrue,
        reason: 'without this, alarms are lost on reboot');
  });

  test('the boot receiver listens for the boot broadcasts', () {
    for (final action in const [
      'android.intent.action.BOOT_COMPLETED',
      'android.intent.action.MY_PACKAGE_REPLACED',
      'android.intent.action.QUICKBOOT_POWERON',
    ]) {
      expect(manifest.contains(action), isTrue, reason: action);
    }
  });

  test('none of the receivers is exported', () {
    // They are internal to the app; exporting them would let any app on the
    // device trigger Nouri's notifications — or, for the action receiver,
    // snooze the user's reminders.
    final receivers = RegExp(r'<receiver[^>]*>', multiLine: true)
        .allMatches(manifest)
        .map((m) => m.group(0)!)
        .where((r) => r.contains('flutterlocalnotifications'));

    // Three: the scheduled one, the boot one, and the action one. The plugin
    // declares none of them itself, so all three are this app's to get right.
    expect(receivers, hasLength(3));
    for (final r in receivers) {
      expect(r.contains('android:exported="false"'), isTrue, reason: r);
    }
  });

  test('the prayer-silence receiver is declared, listens for boot, and is not exported',
      () {
    // Added 13 September 2026. Its silence and restore edges are exact alarms
    // that AlarmManager forgets on reboot; the boot action is how the stored
    // windows come back. Exported would let any app silence the phone.
    final receiver = RegExp(
      r'<receiver[^>]*android:name="\.PrayerSilenceReceiver"[^>]*>',
    ).firstMatch(manifest)?.group(0);
    expect(receiver, isNotNull, reason: 'PrayerSilenceReceiver missing');
    expect(receiver!.contains('android:exported="false"'), isTrue);

    final block = manifest.substring(manifest.indexOf(receiver));
    final end = block.indexOf('</receiver>');
    expect(block.substring(0, end), contains('BOOT_COMPLETED'));
    expect(block.substring(0, end), contains('MY_PACKAGE_REPLACED'));
  });

  test('the alarm-manager plugin has its three components, none exported', () {
    // android_alarm_manager_plus runs the «فكّرني تاني» tick. Like the
    // notifications plugin it declares nothing itself; a missing service
    // means the tick never runs and nothing says so.
    for (final name in [
      'AlarmService',
      'AlarmBroadcastReceiver',
      'RebootBroadcastReceiver',
    ]) {
      final tag = RegExp(
        '<(service|receiver)[^>]*androidalarmmanager\\.$name"[^>]*>',
      ).firstMatch(manifest)?.group(0);
      expect(tag, isNotNull, reason: name);
      expect(tag!.contains('android:exported="false"'), isTrue, reason: name);
    }
  });

  test('every receiver in the manifest is unexported', () {
    final receivers = RegExp(r'<receiver[^>]*>', multiLine: true)
        .allMatches(manifest)
        .map((m) => m.group(0)!);
    expect(receivers, isNotEmpty);
    for (final r in receivers) {
      expect(r.contains('android:exported="false"'), isTrue, reason: r);
    }
  });
}
