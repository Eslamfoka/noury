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

  testWidgets('states plainly that this is a local religious summary',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpReports(t);
      expect(find.text('ملخّص ديني محلي'), findsOneWidget);
      expect(find.textContaining('التقرير الكامل'), findsOneWidget);
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
