import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/data/db/tables.dart';
import 'package:nouri/features/tasks/prayers_line.dart';
import 'package:nouri/features/tasks/task_status.dart';

/// The five prayers as one line of المهام, the way the user asked on 13
/// September 2026:
///
///   «عايز اخلي الصلاه ككل الخمس فروض في قايمة المهام وتنقسم بنسب في المية
///    يعني لو صليت الفجر وعلمت عليها تبقى ٢٠٪ الضهر كمان ٤٠٪ وهكذا لحد
///    العشا ١٠٠٪»
///
/// Twenty percent a prayer, one hundred at isha. Pure, like `taskLinesFor`:
/// a day's times, the logs, a clock.
void main() {
  final times = DailyPrayerTimes(
    fajr: DateTime(2026, 9, 13, 4, 10),
    sunrise: DateTime(2026, 9, 13, 5, 30),
    dhuhr: DateTime(2026, 9, 13, 11, 45),
    asr: DateTime(2026, 9, 13, 15, 10),
    maghrib: DateTime(2026, 9, 13, 17, 55),
    isha: DateTime(2026, 9, 13, 19, 15),
  );

  PrayersLine at(DateTime now, Map<String, PrayerState> logs) =>
      prayersLineFor(times: times, logs: logs, now: now);

  group('the percentage', () {
    test('is twenty a prayer, in his own example', () {
      // «لو صليت الفجر وعلمت عليها تبقى ٢٠٪ الضهر كمان ٤٠٪»
      final noon = DateTime(2026, 9, 13, 12, 0);
      expect(at(noon, {}).percent, 0);
      expect(at(noon, {'fajr': PrayerState.mosque}).percent, 20);
      expect(
        at(noon, {'fajr': PrayerState.mosque, 'dhuhr': PrayerState.onTime})
            .percent,
        40,
      );
    });

    test('reaches one hundred at the fifth, «لحد العشا ١٠٠٪»', () {
      final night = DateTime(2026, 9, 13, 21, 0);
      final all = {
        'fajr': PrayerState.mosque,
        'dhuhr': PrayerState.congregation,
        'asr': PrayerState.onTime,
        'maghrib': PrayerState.late_,
        'isha': PrayerState.mosque,
      };
      final line = at(night, all);
      expect(line.percent, 100);
      expect(line.fraction, 1.0);
      expect(line.status, TaskStatus.done);
    });

    test('a late prayer still counts — he prayed it', () {
      // The percentage is about whether the prayer happened, not how well.
      // The score on Home already grades the how; this is a count.
      final line = at(DateTime(2026, 9, 13, 12, 0), {
        'fajr': PrayerState.late_,
      });
      expect(line.percent, 20);
    });

    test('a missed prayer does not', () {
      // «صليت ... وعلمت عليها» — prayed, then marked. «فاتتني» is marked but
      // not prayed, so it moves nothing. The day can then end at eighty,
      // which is the honest number, and the status stays «لسه» rather than
      // anything that names a failure.
      final line = at(DateTime(2026, 9, 13, 21, 0), {
        'fajr': PrayerState.missed,
        'dhuhr': PrayerState.mosque,
        'asr': PrayerState.mosque,
        'maghrib': PrayerState.mosque,
        'isha': PrayerState.mosque,
      });
      expect(line.percent, 80);
      expect(line.status, isNot(TaskStatus.done));
    });

    test('an unlogged prayer counts as nothing, never as zero against', () {
      expect(at(DateTime(2026, 9, 13, 12, 0), {'fajr': PrayerState.none})
          .percent, 0);
    });
  });

  group('the status', () {
    test('is «جاية» before fajr', () {
      expect(at(DateTime(2026, 9, 13, 3, 0), {}).status, TaskStatus.upcoming);
    });

    test('is «دلوقتي» while the current prayer is still unlogged', () {
      // Dhuhr has entered and has not been logged: this is the prayer to
      // pray, so the line is due — the same gold edge a task gets for the
      // length of its own window.
      expect(
        at(DateTime(2026, 9, 13, 12, 0), {'fajr': PrayerState.mosque}).status,
        TaskStatus.due,
      );
    });

    test('settles to «لسه» once the current prayer is logged', () {
      // Dhuhr logged, asr not yet in: nothing is due, the day goes on.
      expect(
        at(DateTime(2026, 9, 13, 12, 30), {
          'fajr': PrayerState.mosque,
          'dhuhr': PrayerState.mosque,
        }).status,
        TaskStatus.open,
      );
    });

    test('is «لسه» — not overdue, not failed — when an earlier one is open',
        () {
      // Fajr never logged, dhuhr logged, asr not in yet. Something is still
      // open, and the wording for that is the one Home has always used.
      final line = at(DateTime(2026, 9, 13, 12, 30), {
        'dhuhr': PrayerState.mosque,
      });
      expect(line.status, TaskStatus.open);
    });

    test('done outranks the clock', () {
      final all = {
        for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
          p: PrayerState.mosque,
      };
      expect(at(DateTime(2026, 9, 13, 20, 0), all).status, TaskStatus.done);
    });
  });

  group('what the card draws', () {
    test('carries all five, in order, with their state', () {
      final line = at(DateTime(2026, 9, 13, 12, 0), {
        'fajr': PrayerState.mosque,
        'dhuhr': PrayerState.none,
      });
      expect(line.slots.map((s) => s.prayer),
          ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']);
      expect(line.slots.first.state, PrayerState.mosque);
      expect(line.slots.first.prayed, isTrue);
      expect(line.slots[1].state, PrayerState.none);
      expect(line.slots[1].prayed, isFalse);
      expect(line.slots.last.state, PrayerState.none);
    });

    test('sorts at fajr, the start of the day it spans', () {
      expect(at(DateTime(2026, 9, 13, 12, 0), {}).showAt, times.fajr);
    });

    test('names the next thing to pray, or nothing once isha is logged', () {
      expect(
        at(DateTime(2026, 9, 13, 12, 0), {'fajr': PrayerState.mosque})
            .nextToPray,
        'dhuhr',
      );
      // Fajr open, dhuhr done: the next thing to pray is the one still open.
      expect(
        at(DateTime(2026, 9, 13, 12, 30), {'dhuhr': PrayerState.mosque})
            .nextToPray,
        'fajr',
      );
      final all = {
        for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
          p: PrayerState.mosque,
      };
      expect(at(DateTime(2026, 9, 13, 21, 0), all).nextToPray, isNull);
    });
  });
}
