import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the notification sound against R8's resource shrinker.
///
/// The chime is referenced only from Dart, by name, at runtime
/// (`RawResourceAndroidNotificationSound('chime')`). The shrinker cannot see
/// that reference, so without a keep rule it strips `res/raw/chime.wav` from
/// **release builds only** — no build error, no crash, just a silent adhan in
/// the one artefact that ships.
///
/// This was caught by diffing the debug and release APKs. Debug had
/// `res/raw/chime.wav`; release had only the Flutter asset copy, which cannot
/// be used as a notification channel sound.
void main() {
  test('the sound file exists where Android expects it', () {
    // Android resolves channel sounds from res/raw, not from Flutter assets.
    expect(File('android/app/src/main/res/raw/chime.wav').existsSync(), isTrue,
        reason: 'the adhan channel points at android.resource://…/raw/chime');
  });

  test('a keep rule protects res/raw from the resource shrinker', () {
    final keep = File('android/app/src/main/res/raw/keep.xml');
    expect(keep.existsSync(), isTrue,
        reason: 'without keep.xml, release builds ship a silent adhan');

    final contents = keep.readAsStringSync();
    expect(contents, contains('tools:keep'));
    expect(contents, contains('@raw/'),
        reason: 'the keep rule must actually name the raw resources');
  });

  test('the keep rule covers future sounds, not just the current chime', () {
    // Dropping a real adhan.mp3 into res/raw should need no build changes.
    final contents =
        File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    expect(contents, contains('@raw/*'),
        reason: 'a wildcard keeps any sound added later');
  });

  test('every file in res/raw is a sound, not a stray asset', () {
    final rawDir = Directory('android/app/src/main/res/raw');
    final unexpected = rawDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) =>
            name != 'keep.xml' &&
            !name.endsWith('.wav') &&
            !name.endsWith('.mp3') &&
            !name.endsWith('.ogg'))
        .toList();

    expect(unexpected, isEmpty,
        reason: 'res/raw is for notification sounds: $unexpected');
  });
}
