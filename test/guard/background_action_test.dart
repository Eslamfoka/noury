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
