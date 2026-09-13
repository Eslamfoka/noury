import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/nag_plan.dart';
import 'package:nouri/core/notifications/task_alert.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/daily_tasks.dart';
import 'package:nouri/features/planner/day_planner.dart';
import 'package:nouri/features/planner/shift.dart';

/// «فكّرني تاني» — the decision, stated as a plan, a clock and what is done.
///
///   «لو مش عملته تفضل تذكرني كل فترة مثلا كل ٥ دقايق او ١٠ دقايق زي ما انا
///    اختار لحد معاد التاسك التاني ما ييجي ولما ييجي التاسك التاني تفكرني ان
///    معملتش التاسك اللي فاتني وكده»
void main() {
  NagTask task(String id, String title, int h, int m, {int minutes = 30, String? q}) =>
      NagTask(
        id: id,
        title: title,
        start: DateTime(2026, 9, 13, h, m),
        end: DateTime(2026, 9, 13, h, m + minutes),
        channelId: 'alert_${id}_v9',
        payload: 'task:$id',
        question: q,
      );

  // Wird at 16:00, walk at 17:00, calls at 19:00, bed at 22:30.
  final plan = NagPlan(
    intervalMinutes: 10,
    enabled: true,
    days: {
      '2026-09-13': NagDay(
        tasks: [
          task('quran-wird', 'ورد القرآن', 16, 0),
          task('walk', 'مشي', 17, 0, q: 'مشيت؟'),
          task('calls', 'مكالمات', 19, 0),
        ],
        sleepStart: DateTime(2026, 9, 13, 22, 30),
      ),
    },
  );

  NagDecision? at(int h, int m, {Set<String> done = const {}, Map<String, DateTime> snoozed = const {}}) =>
      decideNag(plan: plan, done: done, snoozedUntil: snoozed, now: DateTime(2026, 9, 13, h, m));

  group('asking again', () {
    test('nothing before the first task', () {
      expect(at(15, 30), isNull);
    });

    test('not in the first interval after a task starts — its alarm just rang', () {
      expect(at(16, 5), isNull);
    });

    test('then every tick, in the task\'s own voice, until it is done', () {
      final d = at(16, 20)!;
      expect(d.title, 'ورد القرآن');
      expect(d.body, contains('لسه معملتهاش'));
      expect(d.channelId, 'alert_quran-wird_v9', reason: 'its own sound');
      expect(d.payload, 'task:quran-wird', reason: 'tapping opens the task');

      expect(at(16, 50), isNotNull);
      expect(at(16, 20, done: {'quran-wird'}), isNull);
    });

    test('uses the kind\'s own question when it has one', () {
      expect(at(17, 30)!.body, contains('مشيت؟'));
      expect(at(16, 20)!.body, contains('عملتها؟'),
          reason: 'a kind with no question gets the plain one');
    });

    test('stops at the next task\'s time — «لحد معاد التاسك التاني ما ييجي»', () {
      // 17:00 the walk starts; the wird is no longer the current task.
      final d = at(17, 30)!;
      expect(d.title, 'مشي');
    });

    test('a task snoozed to later is left alone until then', () {
      final snoozed = {'quran-wird': DateTime(2026, 9, 13, 16, 40)};
      expect(at(16, 30, snoozed: snoozed), isNull);
      expect(at(16, 50, snoozed: snoozed), isNotNull,
          reason: 'past the snooze, it is open again');
    });
  });

  group('when the next task comes', () {
    test('the first tick says the last one was not done, once, in its voice', () {
      // «ولما ييجي التاسك التاني تفكرني ان معملتش التاسك اللي فاتني»
      final d = at(17, 4)!;
      expect(d.title, 'ورد القرآن');
      expect(d.body, contains('فاتك ورد القرآن'));
      expect(d.body, contains('لسه ينفع'), reason: 'never a verdict');
      expect(d.channelId, 'alert_quran-wird_v9');
    });

    test('unless it was done — then the first tick is quiet', () {
      expect(at(17, 4, done: {'quran-wird'}), isNull);
    });

    test('later ticks ask about the new task and add the old one in a clause', () {
      final d = at(17, 30)!;
      expect(d.title, 'مشي');
      expect(d.body, contains('مشيت؟'));
      expect(d.body, contains('وورد القرآن فاتك قبلها'));

      final done = at(17, 30, done: {'quran-wird'})!;
      expect(done.body, isNot(contains('فاتك')));
    });

    test('only the immediately previous task — never a list', () {
      // At 19:30 the wird and the walk are both open. One clause, about the
      // walk. A list of everything undone since morning is the shape of blame.
      final d = at(19, 30)!;
      expect(d.title, 'مكالمات');
      expect(d.body, contains('مشي'));
      expect(d.body, isNot(contains('ورد')));
    });
  });

  group('quiet', () {
    test('after bedtime', () {
      expect(at(22, 30), isNull);
      expect(at(23, 30), isNull);
    });

    test('when the interval is zero, or the task alarms are off', () {
      final off = NagPlan(intervalMinutes: 0, enabled: true, days: plan.days);
      expect(decideNag(plan: off, done: const {}, snoozedUntil: const {}, now: DateTime(2026, 9, 13, 16, 30)), isNull);
      final silent = NagPlan(intervalMinutes: 10, enabled: false, days: plan.days);
      expect(decideNag(plan: silent, done: const {}, snoozedUntil: const {}, now: DateTime(2026, 9, 13, 16, 30)), isNull);
    });

    test('on a day the plan does not know', () {
      expect(decideNag(plan: plan, done: const {}, snoozedUntil: const {}, now: DateTime(2026, 9, 14, 16, 30)), isNull);
    });

    test('nothing accuses', () {
      for (final d in [at(16, 20), at(17, 4), at(17, 30), at(19, 30)]) {
        for (final w in ['فاتتك', 'ضيعت', 'فشل', 'كسلان', 'مقصر', 'متأخر']) {
          expect(d!.body.contains(w), isFalse, reason: '${d.body}: $w');
        }
      }
    });
  });

  group('the file', () {
    test('survives a round trip through JSON', () {
      final text = jsonEncode(plan.toJson());
      final back = NagPlan.fromJson(jsonDecode(text))!;
      expect(back.intervalMinutes, 10);
      expect(back.enabled, isTrue);
      final day = back.days['2026-09-13']!;
      expect(day.tasks.map((t) => t.id), ['quran-wird', 'walk', 'calls']);
      expect(day.tasks[1].question, 'مشيت؟');
      expect(day.sleepStart, DateTime(2026, 9, 13, 22, 30));
      expect(day.tasks.first.start, DateTime(2026, 9, 13, 16, 0));
    });

    test('a corrupt or foreign file is nothing, never a throw', () {
      expect(NagPlan.fromJson('nonsense'), isNull);
      expect(NagPlan.fromJson({'days': {'x': {'tasks': [1, 2]}}})!.days['x']!.tasks, isEmpty);
    });
  });

  group('from the planner\'s own day', () {
    test('carries every task with an alert, in order, and the bedtime', () {
      final date = DateTime(2026, 9, 13);
      final times =
          const PrayerTimesService().forDate(date, GeoConfig.kuwaitCity);
      final day = planDay(
        date: date,
        shift: ShiftPattern.forType(ShiftType.morning),
        prayers: times,
        tasks: dailyTasksFor(date: date, shift: ShiftPattern.forType(ShiftType.morning)),
      );

      final nag = NagPlan.fromDayPlans(plans: [day], intervalMinutes: 10, enabled: true);
      final tasks = nag.days['2026-09-13']!.tasks;

      expect(tasks, isNotEmpty);
      for (final t in tasks) {
        expect(alertKindForTaskId(t.id), isNotNull, reason: t.id);
        expect(t.id.startsWith('prayer-'), isFalse, reason: 'prayers are anchors, not tasks');
        expect(t.channelId, alertKindForTaskId(t.id)!.channelId);
      }
      for (var i = 1; i < tasks.length; i++) {
        expect(tasks[i].start.isBefore(tasks[i - 1].start), isFalse);
      }
      expect(nag.days['2026-09-13']!.sleepStart, day.sleep?.start);
    });
  });
}
