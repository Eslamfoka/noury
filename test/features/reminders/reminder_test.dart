import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/reminders/reminder.dart';
import 'package:nouri/features/reminders/reminder_ids.dart';

Reminder aReminder({
  int id = 1,
  DateTime? on,
  int minutes = 9 * 60,
  ReminderRepeat repeat = ReminderRepeat.once,
  bool done = false,
}) =>
    Reminder(
      id: id,
      onDate: on ?? DateTime(2026, 9, 20),
      minutes: minutes,
      title: 'كشف',
      note: null,
      repeat: repeat,
      done: done,
      createdAt: DateTime(2026, 9, 7),
    );

void main() {
  group('the ID space', () {
    test('never collides with the rolling window, even a century out', () {
      // The window numbers alarms as daysSince2020 * 32 + slot, which climbs
      // about 11,700 a year. Reminders sit far above anything it can reach.
      final farOff = notificationIdFor(
          DateTime(2126, 1, 1), NotificationSlot.dailySummary);
      expect(farOff, lessThan(kReminderIdBase));
    });

    test('stays inside a 32-bit int, which is what Android takes', () {
      expect(reminderNotificationId(999999), lessThan(2147483647));
    });

    test('is recognisable, so a tapped notification can be routed', () {
      expect(isReminderNotificationId(reminderNotificationId(7)), isTrue);
      expect(
        isReminderNotificationId(
            notificationIdFor(DateTime(2026, 9, 7), NotificationSlot.adhanFajr)),
        isFalse,
      );
    });

    test('is derived from the row id, so re-arming overwrites', () {
      // The same reliability trick the rolling window uses: a reproducible id
      // means re-arming lands on the existing alarm instead of duplicating it.
      expect(reminderNotificationId(7), reminderNotificationId(7));
      expect(reminderNotificationId(7), isNot(reminderNotificationId(8)));
    });

    test('recovers the row id, so a payload is not the only route back', () {
      expect(rowIdFromReminderNotificationId(reminderNotificationId(42)), 42);
    });
  });

  group('fire time', () {
    test('is the reminder day at its minute', () {
      expect(
        reminderFireTime(aReminder(on: DateTime(2026, 9, 20), minutes: 570)),
        DateTime(2026, 9, 20, 9, 30),
      );
    });

    test('midnight is minute zero, not the end of the day', () {
      expect(
        reminderFireTime(aReminder(on: DateTime(2026, 9, 20), minutes: 0)),
        DateTime(2026, 9, 20, 0, 0),
      );
    });
  });

  group('occurrences', () {
    test('a one-off appears once, and only inside the range', () {
      final one =
          aReminder(repeat: ReminderRepeat.once, on: DateTime(2026, 9, 20));
      expect(
        occurrencesOf(one,
            from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)),
        [DateTime(2026, 9, 20, 9, 0)],
      );
      expect(
        occurrencesOf(one,
            from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 30)),
        isEmpty,
      );
    });

    test('a daily reminder never starts before its own date', () {
      final daily =
          aReminder(repeat: ReminderRepeat.daily, on: DateTime(2026, 9, 20));
      expect(
        occurrencesOf(daily,
            from: DateTime(2026, 9, 18), to: DateTime(2026, 9, 22)),
        [
          DateTime(2026, 9, 20, 9, 0),
          DateTime(2026, 9, 21, 9, 0),
          DateTime(2026, 9, 22, 9, 0),
        ],
      );
    });

    test('a daily reminder crosses a month end by construction', () {
      final daily =
          aReminder(repeat: ReminderRepeat.daily, on: DateTime(2026, 9, 29));
      expect(
        occurrencesOf(daily,
            from: DateTime(2026, 9, 29), to: DateTime(2026, 10, 2)),
        [
          DateTime(2026, 9, 29, 9, 0),
          DateTime(2026, 9, 30, 9, 0),
          DateTime(2026, 10, 1, 9, 0),
          DateTime(2026, 10, 2, 9, 0),
        ],
      );
    });

    test('a weekly reminder keeps its weekday', () {
      final weekly =
          aReminder(repeat: ReminderRepeat.weekly, on: DateTime(2026, 9, 20));
      final got = occurrencesOf(weekly,
          from: DateTime(2026, 9, 20), to: DateTime(2026, 10, 11));
      expect(got.map((d) => d.weekday).toSet(),
          {DateTime(2026, 9, 20).weekday});
      expect(got, hasLength(4));
    });

    test('a monthly reminder on the 31st skips months without one', () {
      // Never silently slides to the 1st of the next month — that would fire
      // a reminder on a day the user did not choose.
      final monthly =
          aReminder(repeat: ReminderRepeat.monthly, on: DateTime(2026, 1, 31));
      final got = occurrencesOf(monthly,
          from: DateTime(2026, 1, 1), to: DateTime(2026, 4, 30));
      expect(got.map((d) => d.month), [1, 3]);
    });

    test('a monthly reminder on the 29th survives a leap February', () {
      final monthly =
          aReminder(repeat: ReminderRepeat.monthly, on: DateTime(2024, 1, 29));
      final got = occurrencesOf(monthly,
          from: DateTime(2024, 1, 1), to: DateTime(2024, 3, 31));
      expect(got.map((d) => d.month), [1, 2, 3]);
    });

    test('crossing a DST boundary keeps the wall-clock minute', () {
      // Dates are constructed, never offset: 09:00 stays 09:00 whatever the
      // day is worth in hours.
      final daily = aReminder(
          repeat: ReminderRepeat.daily,
          on: DateTime(2026, 4, 23),
          minutes: 540);
      final got = occurrencesOf(daily,
          from: DateTime(2026, 4, 23), to: DateTime(2026, 4, 26));
      expect(got.every((d) => d.hour == 9 && d.minute == 0), isTrue);
      expect(got, hasLength(4));
    });

    test('an empty range yields nothing rather than looping forever', () {
      final daily =
          aReminder(repeat: ReminderRepeat.daily, on: DateTime(2026, 9, 20));
      expect(
        occurrencesOf(daily,
            from: DateTime(2026, 9, 25), to: DateTime(2026, 9, 20)),
        isEmpty,
      );
    });
  });

  group('nextOccurrence', () {
    test('is null once a one-off has passed', () {
      final one =
          aReminder(repeat: ReminderRepeat.once, on: DateTime(2026, 9, 20));
      expect(nextOccurrence(one, after: DateTime(2026, 9, 21)), isNull);
    });

    test('is the reminder itself when it is still ahead', () {
      final one =
          aReminder(repeat: ReminderRepeat.once, on: DateTime(2026, 9, 20));
      expect(nextOccurrence(one, after: DateTime(2026, 9, 19, 23, 59)),
          DateTime(2026, 9, 20, 9, 0));
    });

    test('an occurrence exactly now has passed, and is not re-fired', () {
      final one =
          aReminder(repeat: ReminderRepeat.once, on: DateTime(2026, 9, 20));
      expect(nextOccurrence(one, after: DateTime(2026, 9, 20, 9, 0)), isNull);
    });

    test('rolls forward for a repeat', () {
      final daily =
          aReminder(repeat: ReminderRepeat.daily, on: DateTime(2026, 9, 20));
      expect(nextOccurrence(daily, after: DateTime(2026, 9, 25, 10)),
          DateTime(2026, 9, 26, 9, 0));
    });

    test('rolls forward across a year for a monthly repeat', () {
      final monthly =
          aReminder(repeat: ReminderRepeat.monthly, on: DateTime(2026, 12, 5));
      expect(nextOccurrence(monthly, after: DateTime(2026, 12, 6)),
          DateTime(2027, 1, 5, 9, 0));
    });

    test('a done reminder has no next occurrence', () {
      final daily = aReminder(
          repeat: ReminderRepeat.daily,
          on: DateTime(2026, 9, 20),
          done: true);
      expect(nextOccurrence(daily, after: DateTime(2026, 9, 19)), isNull);
    });
  });

  group('occursOn', () {
    test('answers for the calendar, which asks per day', () {
      final weekly =
          aReminder(repeat: ReminderRepeat.weekly, on: DateTime(2026, 9, 20));
      expect(occursOn(weekly, DateTime(2026, 9, 20)), isTrue);
      expect(occursOn(weekly, DateTime(2026, 9, 27)), isTrue);
      expect(occursOn(weekly, DateTime(2026, 9, 21)), isFalse);
      expect(occursOn(weekly, DateTime(2026, 9, 13)), isFalse,
          reason: 'before it was ever created');
    });

    test('a one-off occurs on exactly one day', () {
      final one =
          aReminder(repeat: ReminderRepeat.once, on: DateTime(2026, 9, 20));
      expect(occursOn(one, DateTime(2026, 9, 20)), isTrue);
      expect(occursOn(one, DateTime(2026, 9, 21)), isFalse);
    });
  });
}
