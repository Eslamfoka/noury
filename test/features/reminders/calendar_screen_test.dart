import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/home/home_providers.dart';
import 'package:nouri/features/reminders/calendar_screen.dart';
import 'package:nouri/features/reminders/reminder_providers.dart';

import '../../support/harness.dart';

/// Records what the screen asked to be armed, without a platform channel.
class RecordingReminderScheduler implements ReminderSchedulerPort {
  final List<List<int>> armed = [];
  final List<int> cancelled = [];

  @override
  Future<void> arm(List<Reminder> reminders) async =>
      armed.add(reminders.map((r) => r.id).toList());

  @override
  Future<void> cancelFor(int rowId) async => cancelled.add(rowId);
}

void main() {
  late NouriDatabase db;
  late RecordingReminderScheduler scheduler;

  setUp(() {
    scheduler = RecordingReminderScheduler();
  });

  Future<void> pump(WidgetTester t, {DateTime? day}) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reminderSchedulerPortProvider.overrideWithValue(scheduler),
        ],
        child: testShell(CalendarScreen(initialDay: day)),
      ),
    );
    await t.pumpAndSettle();
  }

  String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  testWidgets('renders a month grid with Arabic headings', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t, day: DateTime(2026, 9, 15));

      expect(find.text('التقويم'), findsOneWidget);
      expect(find.text('س'), findsOneWidget, reason: 'Saturday leads the week');
      expect(find.text('ج'), findsOneWidget);
      expect(find.textContaining('سبتمبر'), findsOneWidget);
    });
  });

  testWidgets('shows a dot only on days that carry a reminder', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.reminderDao.add(
        onDate: DateTime(2026, 9, 20),
        minutes: 540,
        title: 'كشف',
        repeat: ReminderRepeat.once,
      );
      await pump(t, day: DateTime(2026, 9, 15));

      expect(find.byKey(ValueKey('day-dot-${dayKey(DateTime(2026, 9, 20))}')),
          findsOneWidget);
      expect(find.byKey(ValueKey('day-dot-${dayKey(DateTime(2026, 9, 21))}')),
          findsNothing);
    });
  });

  testWidgets('a weekly reminder dots every week, not just its first day',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.reminderDao.add(
        onDate: DateTime(2026, 9, 6),
        minutes: 540,
        title: 'اجتماع',
        repeat: ReminderRepeat.weekly,
      );
      await pump(t, day: DateTime(2026, 9, 15));

      for (final d in [6, 13, 20, 27]) {
        expect(
          find.byKey(ValueKey('day-dot-${dayKey(DateTime(2026, 9, d))}')),
          findsOneWidget,
          reason: 'the weekly reminder comes round on the $d',
        );
      }
      expect(find.byKey(ValueKey('day-dot-${dayKey(DateTime(2026, 9, 7))}')),
          findsNothing);
    });
  });

  testWidgets('an empty day says so instead of showing a blank panel',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t, day: DateTime(2026, 9, 15));
      expect(find.textContaining('مفيش حاجة على اليوم ده'), findsOneWidget);
    });
  });

  testWidgets('tapping a day lists that day, not the one before it',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.reminderDao.add(
        onDate: DateTime(2026, 9, 20),
        minutes: 540,
        title: 'ميعاد الدكتور',
        repeat: ReminderRepeat.once,
      );
      await pump(t, day: DateTime(2026, 9, 15));
      expect(find.text('ميعاد الدكتور'), findsNothing);

      await t.tap(find.text('٢٠'));
      await t.pumpAndSettle();
      expect(find.text('ميعاد الدكتور'), findsOneWidget);
    });
  });

  testWidgets('paging moves a month at a time and rolls over the year',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t, day: DateTime(2026, 12, 15));
      expect(find.textContaining('ديسمبر'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('month-next')));
      await t.pumpAndSettle();
      expect(find.textContaining('يناير'), findsOneWidget);
      expect(find.textContaining('٢٠٢٧'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('month-previous')));
      await t.pumpAndSettle();
      expect(find.textContaining('ديسمبر'), findsOneWidget);
    });
  });

  testWidgets('adding a reminder writes it, shows it, and arms it', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t, day: DateTime(2026, 9, 20));

      await t.tap(find.byKey(const ValueKey('add-reminder')));
      await t.pumpAndSettle();

      await t.enterText(
          find.byKey(const ValueKey('reminder-title')), 'أجدد الرخصة');
      await t.tap(find.byKey(const ValueKey('reminder-save')));
      await t.pumpAndSettle();

      final rows = await db.reminderDao.forDay(DateTime(2026, 9, 20));
      expect(rows.single.title, 'أجدد الرخصة');
      expect(find.text('أجدد الرخصة'), findsOneWidget);
      expect(scheduler.armed.last, [rows.single.id],
          reason: 'a saved reminder that was never armed is the worst failure');
    });
  });

  testWidgets('a reminder with no title is not saved', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t, day: DateTime(2026, 9, 20));

      await t.tap(find.byKey(const ValueKey('add-reminder')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('reminder-save')));
      await t.pumpAndSettle();

      expect(await db.reminderDao.all(), isEmpty);
    });
  });

  testWidgets('a chosen repeat is stored', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t, day: DateTime(2026, 9, 20));

      await t.tap(find.byKey(const ValueKey('add-reminder')));
      await t.pumpAndSettle();
      await t.enterText(
          find.byKey(const ValueKey('reminder-title')), 'ورد أسبوعي');
      await t.tap(find.byKey(const ValueKey('repeat-weekly')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('reminder-save')));
      await t.pumpAndSettle();

      final rows = await db.reminderDao.all();
      expect(rows.single.repeat, ReminderRepeat.weekly);
    });
  });

  testWidgets('marking done cancels the alarm and never turns anything red',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      final id = await db.reminderDao.add(
        onDate: DateTime(2026, 9, 20),
        minutes: 540,
        title: 'كشف',
        repeat: ReminderRepeat.once,
      );
      await pump(t, day: DateTime(2026, 9, 20));

      await t.tap(find.byKey(ValueKey('reminder-done-$id')));
      await t.pumpAndSettle();

      final rows = await db.reminderDao.all();
      expect(rows.single.done, isTrue);
      expect(scheduler.cancelled, contains(id),
          reason: 'a reminder marked done must stop asking');

      // Nothing in Nouri is red. A done reminder goes muted, not punished.
      for (final text in t.widgetList<Text>(find.byType(Text))) {
        final colour = text.style?.color;
        if (colour == null) continue;
        expect(colour.g < 0.55 && colour.b < 0.55 && colour.r > 0.75, isFalse,
            reason: 'found a red-ish colour on "${text.data}"');
      }
    });
  });

  testWidgets('the day list is in time order', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      for (final (m, title) in [(18 * 60, 'بالليل'), (7 * 60, 'الصبح')]) {
        await db.reminderDao.add(
          onDate: DateTime(2026, 9, 20),
          minutes: m,
          title: title,
          repeat: ReminderRepeat.once,
        );
      }
      await pump(t, day: DateTime(2026, 9, 20));

      final morning = t.getTopLeft(find.text('الصبح')).dy;
      final evening = t.getTopLeft(find.text('بالليل')).dy;
      expect(morning, lessThan(evening));
    });
  });
}
