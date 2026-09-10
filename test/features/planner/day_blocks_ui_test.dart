import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/planner/day_plan.dart';
import 'package:nouri/features/planner/example_day.dart';
import 'package:nouri/features/planner/widgets/day_blocks.dart';
import 'package:nouri/core/theme/nouri_theme.dart';

DailyPrayerTimes _times(DateTime d) => DailyPrayerTimes(
      fajr: DateTime(d.year, d.month, d.day, 4, 5),
      sunrise: DateTime(d.year, d.month, d.day, 5, 30),
      dhuhr: DateTime(d.year, d.month, d.day, 11, 46),
      asr: DateTime(d.year, d.month, d.day, 15, 18),
      maghrib: DateTime(d.year, d.month, d.day, 18, 4),
      isha: DateTime(d.year, d.month, d.day, 19, 23),
    );

void main() {
  final day = DateTime(2026, 9, 7);

  Future<void> pump(
    WidgetTester t,
    DateTime now, {
    Set<String> done = const {},
  }) async {
    final plan = exampleDayPlan(date: now, prayers: _times(day));
    await t.pumpWidget(
      MaterialApp(
        theme: nouriTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: DayBlocks(plan: plan, now: now, done: done),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('a collapsed block shows the shape of its tasks', (t) async {
    // "4 مهام" says nothing about whether the block is all work or a mix.
    // The strip is the smallest thing that makes the balance visible.
    await pump(t, DateTime(2026, 9, 7, 4, 20));
    final pillarColours = {for (final p in TaskPillar.values) pillarColour(p)};
    expect(
      t
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((b) => pillarColours.contains(b.color)),
      isNotEmpty,
    );
  });

  testWidgets('the current block names what is next, not a count',
      (t) async {
    await pump(t, DateTime(2026, 9, 7, 4, 20));
    expect(find.textContaining('الجاي:'), findsOneWidget,
        reason: 'a count is no help when you are standing in the block');
  });

  testWidgets('blocks that are not current still show their range and count',
      (t) async {
    await pump(t, DateTime(2026, 9, 7, 4, 20));
    expect(find.textContaining('مهام'), findsWidgets);
  });

  testWidgets('every pillar has a distinct colour', (t) async {
    final seen = <Color>{};
    for (final p in TaskPillar.values) {
      seen.add(pillarColour(p));
    }
    expect(seen.length, TaskPillar.values.length,
        reason: 'two pillars sharing a colour makes the strip unreadable');
  });

  testWidgets('no task is dropped from the strip', (t) async {
    // Without the clamp a ten-minute dhikr beside a seven-hour shift would
    // round to nothing, and the strip would quietly lie about the day.
    final now = DateTime(2026, 9, 7, 4, 20);
    final plan = exampleDayPlan(date: now, prayers: _times(day));
    await pump(t, now);

    // The current block auto-expands, so only the collapsed ones draw a strip.
    final current = plan.blocks.firstWhere(
      (b) => now.isAfter(b.start) && now.isBefore(b.end),
    );
    final collapsedTasks = plan.blocks
        .where((b) => b.kind != current.kind)
        .fold(0, (a, b) => a + b.tasks.length);

    // Filter to the strip's own boxes: the framework contributes a
    // transparent ColoredBox of its own.
    final pillarColours = {for (final p in TaskPillar.values) pillarColour(p)};
    final segments = t
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((b) => pillarColours.contains(b.color));

    expect(segments.length, collapsedTasks);
  });
  group('showing what is already done', () {
    // The plan can *show* what has happened without becoming a second place to
    // record it. The truth stays in the logs; this is a window onto them — so
    // it costs none of the decisions that «should the plan be tappable» is
    // still waiting on.

    testWidgets('a done task carries a tick', (t) async {
      await pump(t, DateTime(2026, 9, 7, 20, 0), done: const {'reading'});
      expect(find.byKey(const ValueKey('task-done-reading')), findsOneWidget);
    });

    testWidgets('a day with nothing done carries none', (t) async {
      // The block-level ticks that mark a finished block are a different
      // thing and are expected; this looks only for a task's own.
      await pump(t, DateTime(2026, 9, 7, 20, 0));
      expect(find.byKey(const ValueKey('task-done-reading')), findsNothing);
    });

    testWidgets('nothing is ever crossed out', (t) async {
      // A tick, not a strikethrough. The day is a plan, not a list of things
      // to have failed at — the same rule that keeps anything from being red.
      await pump(t, DateTime(2026, 9, 7, 20, 0), done: const {'reading'});

      for (final text in t.widgetList<Text>(find.byType(Text))) {
        expect(text.style?.decoration, isNot(TextDecoration.lineThrough),
            reason: text.data);
      }
    });

    testWidgets('the plan is still read-only — a task is not a button',
        (t) async {
      // Whether the plan should also be a place to log is an open question
      // about where the truth lives. Showing does not answer it.
      await pump(t, DateTime(2026, 9, 7, 20, 0), done: const {'reading'});

      expect(
        find.descendant(
          of: find.byType(DayBlocks),
          matching: find.byType(Checkbox),
        ),
        findsNothing,
      );
    });
  });
}
