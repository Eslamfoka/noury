import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/home/home_providers.dart';
import 'package:nouri/features/planner/day_plan.dart';
import 'package:nouri/features/prayers/prayer_row.dart';
import 'package:nouri/features/tasks/prayers_line.dart';
import 'package:nouri/features/tasks/task_status.dart';
import 'package:nouri/features/tasks/tasks_providers.dart';
import 'package:nouri/features/tasks/tasks_screen.dart';

import '../../support/harness.dart';

/// المهام, as the user asked for it:
///
///   «Show every task for today ... with its planned time ... Clearly show the
///    status: completed, upcoming, currently due, delayed/snoozed, or still
///    not done ... do not use shameful language, red colors, or "failed"
///    states.»
TaskLine line(
  String id,
  String title,
  TaskStatus status, {
  DateTime? at,
  DateTime? showAt,
}) {
  final planned = at ?? DateTime(2026, 9, 8, 16, 30);
  return TaskLine(
    taskId: id,
    title: title,
    plannedAt: planned,
    showAt: showAt ?? planned,
    status: status,
    pillar: TaskPillar.body,
  );
}

void main() {
  late NouriDatabase db;

  Future<void> pump(WidgetTester t, List<TaskLine> lines) async {
    db = inMemoryDatabase(t);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          todayTaskLinesProvider.overrideWith((ref) async => lines),
          // These tests are about the task list as given. The prayers line
          // has its own group below, with a real line; here it is absent so
          // every count and finder means what it did before it existed.
          todayPrayersLineProvider.overrideWithValue(null),
        ],
        child: testShell(const Scaffold(body: TasksScreen())),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('it lists every task with its time', (t) async {
    await withLargeSurface(t, () async {
      await pump(t, [
        line('walk', 'مشي ٣٠ دقيقة', TaskStatus.upcoming),
        line('first-meal', 'أول وجبة', TaskStatus.done,
            at: DateTime(2026, 9, 8, 13, 0)),
      ]);

      expect(find.text('مشي ٣٠ دقيقة'), findsOneWidget);
      expect(find.text('أول وجبة'), findsOneWidget);
      expect(find.byKey(const ValueKey('task-time-walk')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-time-first-meal')), findsOneWidget);
    });
  });

  testWidgets('a done task is ticked and counted', (t) async {
    await withLargeSurface(t, () async {
      await pump(t, [
        line('walk', 'مشي', TaskStatus.done),
        line('tasbeeh', 'تسبيح', TaskStatus.upcoming),
      ]);

      expect(find.byKey(const ValueKey('task-done-walk')), findsOneWidget);
      expect(find.byKey(const ValueKey('task-done-tasbeeh')), findsNothing);

      final count = t.widget<Text>(
          find.byKey(const ValueKey('tasks-summary-count')));
      expect(count.data, contains('١'));
      expect(count.data, contains('٢'));
    });
  });

  testWidgets('the count reads «من», never a slash', (t) async {
    // «١ / ٢» lays out right to left and says two of one. Held app-wide by
    // counter_form_test; stated here because this is a new counter.
    await withLargeSurface(t, () async {
      await pump(t, [line('walk', 'مشي', TaskStatus.done)]);
      final count = t.widget<Text>(
          find.byKey(const ValueKey('tasks-summary-count')));
      expect(count.data, contains('من'));
      expect(count.data, isNot(contains('/')));
    });
  });

  testWidgets('a snoozed task shows its new time and where it came from',
      (t) async {
    // «When I tap Snooze 5 minutes, update the task's displayed time/status in
    // Tasks so I can see the new time.»
    await withLargeSurface(t, () async {
      await pump(t, [
        line('walk', 'مشي', TaskStatus.snoozed,
            at: DateTime(2026, 9, 8, 16, 30),
            showAt: DateTime(2026, 9, 8, 16, 35)),
      ]);

      expect(find.byKey(const ValueKey('task-was-walk')), findsOneWidget,
          reason: 'the day still reads as the day that was planned');
      expect(find.text('مأجّلة'), findsOneWidget);
    });
  });

  testWidgets('an unsnoozed task does not claim it was moved', (t) async {
    await withLargeSurface(t, () async {
      await pump(t, [line('walk', 'مشي', TaskStatus.upcoming)]);
      expect(find.byKey(const ValueKey('task-was-walk')), findsNothing);
    });
  });

  testWidgets('every status is named on screen', (t) async {
    await withLargeSurface(t, () async {
      await pump(t, [
        line('walk', 'مشي', TaskStatus.done),
        line('tasbeeh', 'تسبيح', TaskStatus.due),
        line('calls', 'مكالمات', TaskStatus.upcoming),
        line('quran-wird', 'ورد', TaskStatus.open),
        line('first-meal', 'وجبة', TaskStatus.snoozed,
            showAt: DateTime(2026, 9, 8, 17, 0)),
      ]);

      for (final s in TaskStatus.values) {
        expect(find.text(s.arabicLabel), findsWidgets, reason: s.name);
      }
    });
  });

  testWidgets('nothing on the screen is red', (t) async {
    // A day with a red row on it reads as a day gone wrong. palette_test holds
    // this app-wide; this states it where the statuses are drawn.
    await withLargeSurface(t, () async {
      await pump(t, [
        line('walk', 'مشي', TaskStatus.open),
        line('tasbeeh', 'تسبيح', TaskStatus.due),
      ]);

      for (final text in t.widgetList<Text>(find.byType(Text))) {
        final c = text.style?.color;
        if (c == null) continue;
        expect(c.r > 0.75 && c.g < 0.4 && c.b < 0.4, isFalse,
            reason: '${text.data} is red');
      }
    });
  });

  testWidgets('a task whose time has passed is «لسه», not a failure',
      (t) async {
    await withLargeSurface(t, () async {
      await pump(t, [line('walk', 'مشي', TaskStatus.open)]);

      expect(find.text('لسه'), findsOneWidget);
      for (final w in ['فاتتك', 'ضيعت', 'فشل', 'متأخر']) {
        expect(find.textContaining(w), findsNothing, reason: w);
      }
    });
  });

  testWidgets('an empty day says so plainly rather than showing an error',
      (t) async {
    await withLargeSurface(t, () async {
      await pump(t, const []);
      expect(find.textContaining('مفيش مهام'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);
    });
  });

  testWidgets('there is no checkbox — المهام does not log anything',
      (t) async {
    // Every status is derived from the log the user already keeps. Making a
    // task tickable here would be a second place for the truth to live, which
    // is the decision still waiting on the user.
    await withLargeSurface(t, () async {
      await pump(t, [line('walk', 'مشي', TaskStatus.upcoming)]);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });
  });

  testWidgets('the due task is the one that stands out', (t) async {
    await withLargeSurface(t, () async {
      await pump(t, [
        line('walk', 'مشي', TaskStatus.due),
        line('tasbeeh', 'تسبيح', TaskStatus.upcoming),
      ]);

      // `.first` — the status chip is a Container too, and the card's own
      // decoration is the outermost one.
      final due = t.widget<Container>(find.descendant(
        of: find.byKey(const ValueKey('task-card-walk')),
        matching: find.byType(Container),
      ).first);
      final decoration = due.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull,
          reason: 'the thing to be doing now carries the gold edge');
      expect(decoration.color, NouriColors.surfaceActive);
    });
  });

  /// The five prayers as one line, at twenty percent each — asked for on 13
  /// September 2026: «عايز اخلي الصلاه ككل الخمس فروض في قايمة المهام وتنقسم
  /// بنسب في المية».
  group('the prayers line', () {
    final times = DailyPrayerTimes(
      fajr: DateTime(2026, 9, 13, 4, 10),
      sunrise: DateTime(2026, 9, 13, 5, 30),
      dhuhr: DateTime(2026, 9, 13, 11, 45),
      asr: DateTime(2026, 9, 13, 15, 10),
      maghrib: DateTime(2026, 9, 13, 17, 55),
      isha: DateTime(2026, 9, 13, 19, 15),
    );

    Future<void> pumpWithPrayers(
      WidgetTester t,
      List<TaskLine> lines,
      Map<String, PrayerState> logs, {
      DateTime? now,
    }) async {
      db = inMemoryDatabase(t);
      final line = prayersLineFor(
        times: times,
        logs: logs,
        now: now ?? DateTime(2026, 9, 13, 12, 0),
      );
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            todayTaskLinesProvider.overrideWith((ref) async => lines),
            todayPrayersLineProvider.overrideWithValue(line),
          ],
          child: testShell(const Scaffold(body: TasksScreen())),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('sits first in the list and shows the percentage', (t) async {
      await withLargeSurface(t, () async {
        await pumpWithPrayers(
          t,
          [line('walk', 'مشي', TaskStatus.upcoming)],
          {'fajr': PrayerState.mosque, 'dhuhr': PrayerState.onTime},
        );

        expect(find.byKey(const ValueKey('task-card-prayers')), findsOneWidget);
        expect(find.text('٤٠٪'), findsOneWidget);

        // First, above the walk: the day's frame before the day's tasks.
        final prayersY =
            t.getTopLeft(find.byKey(const ValueKey('task-card-prayers'))).dy;
        final walkY =
            t.getTopLeft(find.byKey(const ValueKey('task-card-walk'))).dy;
        expect(prayersY, lessThan(walkY));
      });
    });

    testWidgets('an empty plan still carries the prayers', (t) async {
      // There is no day without them. «مفيش مهام» is for a day with nothing
      // planned *and* no prayer times, which in practice is never.
      await withLargeSurface(t, () async {
        await pumpWithPrayers(t, const [], {});
        expect(find.byKey(const ValueKey('task-card-prayers')), findsOneWidget);
        expect(find.textContaining('مفيش مهام'), findsNothing);
        final count = t.widget<Text>(
            find.byKey(const ValueKey('tasks-summary-count')));
        expect(count.data, '٠ من ١');
      });
    });

    testWidgets('his example: fajr marked is twenty, dhuhr forty', (t) async {
      await withLargeSurface(t, () async {
        await pumpWithPrayers(t, const [], {'fajr': PrayerState.mosque});
        expect(find.text('٢٠٪'), findsOneWidget);
      });
    });

    testWidgets('counts as one task in the summary, done at a hundred',
        (t) async {
      await withLargeSurface(t, () async {
        await pumpWithPrayers(
          t,
          [line('walk', 'مشي', TaskStatus.done)],
          {
            for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
              p: PrayerState.mosque,
          },
          now: DateTime(2026, 9, 13, 21, 0),
        );

        final count = t.widget<Text>(
            find.byKey(const ValueKey('tasks-summary-count')));
        expect(count.data, '٢ من ٢');
        expect(find.text('١٠٠٪'), findsOneWidget);
        expect(find.byKey(const ValueKey('task-done-prayers')), findsOneWidget);
      });
    });

    testWidgets('and as not yet done at anything less', (t) async {
      await withLargeSurface(t, () async {
        await pumpWithPrayers(
          t,
          [line('walk', 'مشي', TaskStatus.done)],
          {'fajr': PrayerState.mosque},
        );
        final count = t.widget<Text>(
            find.byKey(const ValueKey('tasks-summary-count')));
        expect(count.data, '١ من ٢');
      });
    });

    testWidgets('draws all five prayers by name, prayed ones marked',
        (t) async {
      await withLargeSurface(t, () async {
        await pumpWithPrayers(t, const [], {'fajr': PrayerState.mosque});
        for (final name in ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']) {
          expect(find.text(name), findsOneWidget, reason: name);
        }
        expect(find.byKey(const ValueKey('prayer-dot-fajr-prayed')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('prayer-dot-dhuhr-prayed')),
            findsNothing);
      });
    });

    testWidgets('a missed prayer neither counts nor turns anything red',
        (t) async {
      await withLargeSurface(t, () async {
        await pumpWithPrayers(
          t,
          const [],
          {'fajr': PrayerState.missed, 'dhuhr': PrayerState.mosque},
        );
        expect(find.text('٢٠٪'), findsOneWidget);
        for (final text in t.widgetList<Text>(find.byType(Text))) {
          final c = text.style?.color;
          if (c == null) continue;
          expect(c.r > 0.75 && c.g < 0.4 && c.b < 0.4, isFalse,
              reason: '${text.data} is red');
        }
      });
    });

    testWidgets('tapping it opens the five to log, and logging writes the row',
        (t) async {
      await withLargeSurface(t, () async {
        await pumpWithPrayers(t, const [], {});

        await t.tap(find.byKey(const ValueKey('task-card-prayers')));
        await t.pumpAndSettle();

        expect(find.byType(PrayerRow), findsNWidgets(5),
            reason: 'the sheet lists the five, like Home');

        await t.tap(find.byType(PrayerRow).first);
        await t.pumpAndSettle();
        await t.tap(find.text('في المسجد جماعة').last);
        await t.pumpAndSettle();

        final logs = await db.prayerDao.logsForDate(DateTime.now());
        expect(logs.map((l) => l.prayer), contains('fajr'));
        expect(logs.single.state, PrayerState.mosque);
      });
    });
  });
}
