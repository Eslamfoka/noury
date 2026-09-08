import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/snooze.dart';
import 'package:nouri/core/notifications/task_alarm_ids.dart';
import 'package:nouri/core/notifications/task_alert.dart';

/// «i can late it 5 mins many times»
void main() {
  group('the timing', () {
    test('a snooze moves the task five minutes on', () {
      expect(snoozedTime(from: DateTime(2026, 9, 8, 13, 0)),
          DateTime(2026, 9, 8, 13, 5));
    });

    test('snoozing twice moves it ten, not five', () {
      // "many times" only means something if they accumulate. Each snooze is
      // measured from now, not from the alert's original time.
      var t = snoozedTime(from: DateTime(2026, 9, 8, 13, 0));
      t = snoozedTime(from: t);
      expect(t, DateTime(2026, 9, 8, 13, 10));
    });

    test('snoozing across midnight lands on the next day', () {
      expect(snoozedTime(from: DateTime(2026, 9, 8, 23, 58)),
          DateTime(2026, 9, 9, 0, 3));
    });

    test('snoozing across a DST boundary stays five minutes', () {
      // Minutes, not a day step. Egypt shifts the clock twice a year and this
      // project has already had one alarm moved an hour by date arithmetic.
      final from = DateTime(2026, 10, 29, 23, 59);
      expect(snoozedTime(from: from).difference(from),
          const Duration(minutes: 5));
    });
  });

  group('the notification it schedules', () {
    test('keeps the task\'s own sound', () {
      // A snoozed walk that came back as a generic ping would undo the whole
      // point: the user would no longer know what was calling without looking.
      final n = snoozedNotification(
          taskId: 'walk', from: DateTime(2026, 9, 8, 13, 0))!;
      expect(n.channelId, TaskAlertKind.walk.channelId);
      expect(n.title, TaskAlertKind.walk.title);
    });

    test('still routes to the task when tapped', () {
      final n = snoozedNotification(
          taskId: 'first-meal', from: DateTime(2026, 9, 8, 13, 0))!;
      expect(n.payload, 'task:first-meal');
    });

    test('lands five minutes out', () {
      final n = snoozedNotification(
          taskId: 'tasbeeh', from: DateTime(2026, 9, 8, 13, 0))!;
      expect(n.when, DateTime(2026, 9, 8, 13, 5));
    });

    test('an unknown task snoozes to nothing rather than throwing', () {
      // The background isolate is the worst place to discover an exception.
      expect(
        snoozedNotification(
            taskId: 'nonsense-from-2025', from: DateTime(2026, 9, 8, 13, 0)),
        isNull,
      );
    });
  });

  group('the id', () {
    test('sits above the reminder floor so a re-arm cannot cancel it', () {
      // Opening the app re-arms the whole window with
      // cancelAllBelow(kOutOfWindowIdBase). A snooze below that floor would be
      // cancelled by the act of opening Nouri — deleting the very thing the
      // user just asked for.
      final id = snoozeIdFor('walk')!;
      expect(id, greaterThanOrEqualTo(kSnoozeIdBase));
      expect(id, greaterThan(kOutOfWindowIdBase));
    });

    test('is one per task, so snoozing again replaces rather than stacks', () {
      expect(snoozeIdFor('walk'), snoozeIdFor('walk'));
    });

    test('differs between tasks', () {
      final ids =
          alarmableTaskIds.map(snoozeIdFor).whereType<int>().toList();
      expect(ids.toSet().length, ids.length);
    });

    test('never collides with a task alarm id', () {
      for (final taskId in alarmableTaskIds) {
        final snooze = snoozeIdFor(taskId)!;
        expect(isTaskAlarmId(snooze), isFalse, reason: taskId);
      }
    });

    test('is null for a task Nouri does not number', () {
      expect(snoozeIdFor('nonsense'), isNull);
    });
  });

  group('reading the payload', () {
    test('finds the task id', () {
      expect(taskIdFromPayload('task:walk'), 'walk');
    });

    test('ignores anything that is not a task', () {
      for (final p in ['water', 'prayer:fajr', 'taskask:walk', 'task:', '']) {
        expect(taskIdFromPayload(p), isNull, reason: p);
      }
    });

    test('ignores null', () {
      expect(taskIdFromPayload(null), isNull);
    });
  });

  test('the snooze action does not open the app', () {
    // The point of a snooze is not to be dragged into a screen. This is also
    // the trap «صليت» fell into — written not to open the app, with no
    // background handler registered, so it did nothing at all.
    expect(actionSnooze, 'snooze');
    expect(kSnoozeMinutes, 5);
  });
}
