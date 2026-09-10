import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_service.dart';
import 'package:nouri/core/notifications/armed_window.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/task_alarm_ids.dart';
import 'package:nouri/core/notifications/task_alert.dart';

/// Reading back what is *actually* armed, rather than what was intended.
///
/// This exists because of 10 September 2026. The user's phone held 137 alarms
/// with nothing at all for the next four days, and every screen in the app
/// looked completely normal. Nouri could tell him whether the permissions were
/// granted and could not tell him that the thing those permissions exist for
/// had quietly gone missing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final today = DateTime(2026, 9, 10);
  DateTime day(int d) => DateTime(2026, 9, d);

  /// The ids a healthy day of the window would hold.
  List<int> healthyDay(DateTime d) => [
        notificationIdFor(d, NotificationSlot.adhanFajr),
        notificationIdFor(d, NotificationSlot.adhanDhuhr),
        notificationIdFor(d, NotificationSlot.adhanAsr),
        notificationIdFor(d, NotificationSlot.adhanMaghrib),
        notificationIdFor(d, NotificationSlot.adhanIsha),
      ];

  List<int> healthyWindow({int days = 14, Set<int> skip = const {}}) => [
        for (var i = 0; i < days; i++)
          if (!skip.contains(i)) ...healthyDay(day(10 + i)),
      ];

  group('what it counts', () {
    test('counts only the window, not reminders or snoozes', () {
      final w = armedWindowFrom([
        ...healthyDay(day(11)),
        kOutOfWindowIdBase + 1, // a reminder the user set
        kSnoozeIdBase + 3, // a snooze they pressed
      ]);

      expect(w.count, 5,
          reason: 'a reminder is not part of the window and its presence must '
              'not make a gutted window look healthy');
    });

    test('task alarms are counted separately from the prayer window', () {
      // They live in their own range and cover three days rather than
      // fourteen, so folding them in would make a short window look long.
      final w = armedWindowFrom([
        ...healthyDay(day(11)),
        taskAlarmId(day(11), alarmableTaskIds.first)!,
      ]);

      expect(w.count, 5);
      expect(w.days, {day(11)});
    });

    test('an empty device reads as empty rather than throwing', () {
      final w = armedWindowFrom(const []);
      expect(w.count, 0);
      expect(w.days, isEmpty);
      expect(w.coversThrough, isNull);
      expect(w.gapsAfter(today), isEmpty,
          reason: 'nothing armed is not a gap — it is a different problem, '
              'and the permission rows above already speak to it');
    });
  });

  group('the gap that actually happened', () {
    test('a healthy fortnight has no gaps', () {
      final w = armedWindowFrom(healthyWindow());
      expect(w.gapsAfter(today), isEmpty);
      expect(w.coversThrough, day(23));
    });

    test('the user phone on 10 September, reconstructed', () {
      // 137 alarms, nothing from the 10th to the 13th, the rest intact. The
      // shape an interrupted cancel pass leaves behind.
      final w = armedWindowFrom(healthyWindow(skip: {0, 1, 2, 3}));

      expect(w.gapsAfter(today), [day(11), day(12), day(13)],
          reason: 'the days with no alarm at all, in order');
      expect(w.coversThrough, day(23),
          reason: 'the far end looked perfectly healthy, which is exactly why '
              'reach is the wrong thing to measure');
    });

    test('today is never called a gap', () {
      // Today's alarms are consumed as the day passes, so by the evening today
      // legitimately holds none. Calling that a fault would put a warning in
      // front of every user every night.
      final w = armedWindowFrom(healthyWindow(skip: {0}));
      expect(w.gapsAfter(today), isEmpty);
    });

    test('a gap beyond the armed range is not invented', () {
      // A window that stops at the 16th has no gap on the 17th — it simply
      // does not reach, which is a different statement and a milder one.
      final w = armedWindowFrom(healthyWindow(days: 7));
      expect(w.gapsAfter(today), isEmpty);
      expect(w.coversThrough, day(16));
    });

    test('a hole in the middle is found', () {
      final w = armedWindowFrom(healthyWindow(skip: {5, 6}));
      expect(w.gapsAfter(today), [day(15), day(16)]);
    });
  });

  group('how far it reaches', () {
    test('reports the last day it holds anything for', () {
      expect(armedWindowFrom(healthyWindow(days: 3)).coversThrough, day(12));
    });

    test('days ahead is counted from today, never negative', () {
      expect(armedWindowFrom(healthyWindow(days: 3)).daysAhead(today), 2);
      // A window entirely in the past reaches zero days ahead, not minus four.
      final stale = armedWindowFrom(healthyDay(DateTime(2026, 9, 6)));
      expect(stale.daysAhead(today), 0);
    });
  });

  group('when it is safe to report', () {
    test('says nothing until the launch arm has finished', () async {
      // Measured on the emulator: opening الإعدادات while the window was still
      // being written reported «١٣٤ — لحد ١٩ سبتمبر» for a device that ended
      // the same second at 232 through the 23rd. Read a moment earlier still
      // and the count is low enough to be reported as *missing days* — the app
      // raising a false alarm against itself about the one thing this row
      // exists to be trusted about, while it was busy doing the right thing.
      final service = NotificationService(FlutterLocalNotificationsPlugin());
      final arming = Completer<void>();
      service.attachWarmUp(arming.future);

      var reported = false;
      unawaited(service.readArmedWindow().then((_) => reported = true));
      await pumpEventQueue();

      expect(reported, isFalse,
          reason: 'a count read mid-arm is a count of a half-written window');

      arming.complete();
      await pumpEventQueue();
      expect(reported, isTrue, reason: 'and once arming is done it answers');
    });

    test('answers straight away once the arm is long done', () async {
      // The wait is only ever paid by someone who opens the settings screen
      // within a few seconds of launching.
      final service = NotificationService(FlutterLocalNotificationsPlugin());
      service.attachWarmUp(Future<void>.value());

      await service.readArmedWindow().timeout(const Duration(seconds: 1));
    });

    test('a device that cannot be asked reads as empty, not as broken',
        () async {
      // There is no platform channel here, so the plugin call fails. An
      // unreadable window must not surface as a gap: «مفيش» is honest,
      // «فيه ١٤ يوم من غير أذان» is a lie about the user's device.
      final service = NotificationService(FlutterLocalNotificationsPlugin());
      service.attachWarmUp(Future<void>.value());

      final w = await service.readArmedWindow();
      expect(w.count, 0);
      expect(w.gapsAfter(today), isEmpty);
    });
  });
}
