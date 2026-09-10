import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An action that does not open the app is dead without a handler.
///
/// **This guard exists because it already happened.** The «صليت» action on the
/// prayer follow-up was declared `showsUserInterface: false`, meaning to write
/// the log straight from the shade. Android delivers such a tap to a
/// **background isolate**, and no background handler was ever registered — so
/// the button did nothing at all. Nobody noticed until the action was rewritten
/// to open the app instead. `local_notification_gateway.dart` still carries the
/// note.
///
/// «فكّرني بعد ٥ دقايق» has to be `showsUserInterface: false` — being dragged
/// into a screen is the opposite of putting something off — so the same trap is
/// open again, and this time it is nailed shut.
void main() {
  final gateway =
      File('lib/core/notifications/local_notification_gateway.dart')
          .readAsStringSync();
  final main = File('lib/main.dart').readAsStringSync();

  test('the guard is looking at real files', () {
    // A guard reading an empty string would pass forever while guarding
    // nothing.
    expect(gateway.length, greaterThan(1000));
    expect(main.length, greaterThan(1000));
  });

  test('an action that does not open the app implies a background handler',
      () {
    // The implication, stated directly. If any action anywhere is declared
    // `showsUserInterface: false`, then `initialize` must be given an
    // `onDidReceiveBackgroundNotificationResponse`.
    final hasSilentAction = gateway.contains('showsUserInterface: false');
    if (!hasSilentAction) return;

    expect(
      main.contains('onBackgroundResponse:'),
      isTrue,
      reason: 'a silent action is delivered only to a background isolate; '
          'without a handler the button does nothing at all',
    );
  });

  test('a silent action also needs its Android receiver declared', () {
    // **The half that was still missing after the handler was added.**
    //
    // A registered Dart handler is not enough: the tap is delivered by
    // `ActionBroadcastReceiver`, and `flutter_local_notifications` declares no
    // receivers of its own — every one is this app's responsibility. Without
    // it the press reaches the app process (dumpsys shows it unfrozen) and
    // then stops. No engine, no handler, no log, no error.
    //
    // Observed on the emulator: «فكّرني بعد ٥ دقايق» was completely dead.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    if (!gateway.contains('showsUserInterface: false')) return;

    expect(
      manifest.contains(
          'com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver'),
      isTrue,
      reason: 'a silent action is delivered by ActionBroadcastReceiver; '
          'without it declared, the button does nothing at all',
    );
  });

  test('the receivers the plugin needs are all declared', () {
    // The plugin ships a manifest with no receivers in it, so all three are
    // the app's to declare. Missing the scheduled one means nothing ever
    // appears; missing the boot one means nothing survives a restart; missing
    // the action one means buttons do nothing.
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    for (final receiver in [
      'ScheduledNotificationReceiver',
      'ScheduledNotificationBootReceiver',
      'ActionBroadcastReceiver',
    ]) {
      expect(manifest.contains(receiver), isTrue, reason: receiver);
    }
  });

  test('the handler is a real entry point, not just a function', () {
    // Without @pragma('vm:entry-point') the tree-shaker removes it from a
    // release build, and the button dies again — in release only, which is
    // the worst place for it.
    expect(main.contains("@pragma('vm:entry-point')"), isTrue);
    expect(
      main.contains('Future<void> onNotificationActionInBackground('),
      isTrue,
    );
  });

  test('the handler must be top-level, since the isolate has no app', () {
    // A method on a class or a closure over `main()` state cannot be an entry
    // point: the background isolate starts with none of it alive.
    final i = main.indexOf('Future<void> onNotificationActionInBackground(');
    expect(i, greaterThan(0));

    final lineStart = main.lastIndexOf('\n', i) + 1;
    expect(main.substring(lineStart, i), isEmpty,
        reason: 'indented means nested, and a nested handler is unreachable');
  });

  test('a snooze pressed in the foreground is handled too', () {
    // Android delivers the action to the running app when there is one, and
    // to the isolate when there is not. Handling only the isolate would make
    // the button work only while the app was closed.
    expect(main.contains('snoozeFromResponse'), isTrue);
    expect(main.contains('actionSnooze'), isTrue);
  });
}
