import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/reports/reports_screen.dart';

import '../../support/harness.dart';

void main() {
  late NouriDatabase db;

  Future<void> pumpReports(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(db: db, child: const Scaffold(body: ReportsScreen())),
    );
    await tester.pumpAndSettle();
  }

  /// Brings [target] fully into view.
  ///
  /// scrollUntilVisible stops as soon as the target is *built*, and a lazy
  /// ListView builds 250px past the viewport, so on its own it can leave the
  /// target just off screen. Same helper, same reason, as in
  /// home_screen_test.
  Future<void> scrollTo(WidgetTester t, Finder target) async {
    await t.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  testWidgets('an empty week renders without any score or error', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpReports(t);

      expect(find.text('—'), findsOneWidget,
          reason: 'no logging means no average, not a zero');
      expect(find.text('لسه مفيش تسجيل'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsNothing);
    });
  });

  testWidgets('states plainly that this is a local summary, not a reading',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpReports(t);
      expect(find.text('ملخّص ديني محلي'), findsOneWidget);

      // Below the fold now that البدن والمالية and التحديات sit above it.
      //
      // The note used to say the report covered «الجانب الديني بس». It no
      // longer does, so the claim changed with it — what is still true is
      // that these are the user's own rows added up, and that Nouri's reading
      // of the week has not arrived yet.
      await scrollTo(t, find.textContaining('سجّلته بنفسك'));
      expect(find.textContaining('سجّلته بنفسك'), findsOneWidget);
      expect(find.textContaining('مرحلة جاية'), findsOneWidget);
    });
  });

  testWidgets('an empty week says so in البدن والمالية too', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpReports(t);
      await scrollTo(t, find.byKey(const ValueKey('body-wealth-empty')));
      expect(find.byKey(const ValueKey('body-wealth-empty')), findsOneWidget);
    });
  });

  testWidgets('a logged walk and workout appear in the weekly report',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.stepsDao.addSession(
        startedAt: DateTime.now(),
        seconds: 1800,
        steps: 3400,
        metres: 2448,
        kcal: 122,
        targetMinutes: 30,
      );
      await db.workoutDao.addSession(
        startedAt: DateTime.now(),
        routineId: 'full-body',
        doneCount: 5,
        totalCount: 20,
        seconds: 300,
      );
      await pumpReports(t);

      await scrollTo(t, find.text('البدن والمعرفة والمالية'));
      expect(find.text('٣٤٠٠'), findsOneWidget, reason: 'the steps');
      expect(find.text('٥'), findsWidgets,
          reason: 'five exercises, even though the routine was twenty');
      expect(find.byKey(const ValueKey('body-wealth-empty')), findsNothing);
    });
  });

  testWidgets('reflects logged prayers in the average and the count',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      final today = DateTime.now();

      await db.prayerDao.upsertLog(
        date: today,
        prayer: 'fajr',
        scheduledTime: today,
        state: PrayerState.mosque,
      );
      await db.prayerDao.upsertLog(
        date: today,
        prayer: 'dhuhr',
        scheduledTime: today,
        state: PrayerState.onTime,
      );

      await pumpReports(t);

      // (100 + 70) / 2 = 85
      expect(find.text('٨٥'), findsOneWidget);
      expect(find.text('٢'), findsWidgets);
    });
  });

  testWidgets('counts the Quran wird streak from logged pages', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      final today = DateTime.now();
      await db.quranDao.upsert(date: today, pages: 3);
      await db.quranDao
          .upsert(date: today.subtract(const Duration(days: 1)), pages: 3);

      await pumpReports(t);
      expect(find.text('أيام ورد القرآن على التوالي'), findsOneWidget);
      expect(find.text('٦'), findsWidgets, reason: '6 pages across two days');
    });
  });

  testWidgets('never renders a failure red', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpReports(t);

      bool isRed(Color? c) =>
          c != null && c.r * 255 > 200 && c.g * 255 < 90 && c.b * 255 < 90;

      final reds = t
          .widgetList<Text>(find.byType(Text))
          .where((w) => isRed(w.style?.color));
      expect(reds, isEmpty);
    });
  });
}
