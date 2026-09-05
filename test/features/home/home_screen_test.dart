import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/home/home_screen.dart';
import 'package:nouri/features/home/widgets/next_prayer_card.dart';
import 'package:nouri/features/home/widgets/progress_ring.dart';
import 'package:nouri/features/home/widgets/wird_grid.dart';
import 'package:nouri/features/prayers/prayer_row.dart';

import '../../support/harness.dart';

void main() {
  late NouriDatabase db;

  /// Pumps Home against [db]. Reusing the same database across two pumps is
  /// how the persistence test proves a log survives a full screen rebuild.
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(db: db, child: const Scaffold(body: HomeScreen())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders header, ring, prayer list and wird grid', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);

      expect(find.text('نوري'), findsOneWidget);
      expect(find.byType(ProgressRing), findsOneWidget);
      expect(find.byType(PrayerRow), findsNWidgets(5),
          reason: 'all five prayers are listed on Home');
      expect(find.byType(WirdGrid), findsOneWidget);
    });
  });

  testWidgets('the five prayers appear in daily order', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      final rows = t
          .widgetList<PrayerRow>(find.byType(PrayerRow))
          .map((r) => r.slot.name)
          .toList();
      expect(rows, ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']);
    });
  });

  testWidgets('a fresh day starts at zero of nine, with no red', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      expect(find.text('٠/٩'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.error), findsNothing);
    });
  });

  testWidgets('the wird grid lists the four cards in the approved order',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      final grid = t.widget<WirdGrid>(find.byType(WirdGrid));
      expect(grid.morning.label, 'أذكار الصباح');
      expect(grid.tasbeeh.label, 'التسبيح');
      expect(grid.evening.label, 'أذكار المساء');
      expect(grid.quran.label, 'ورد القرآن');
    });
  });

  testWidgets('logging a prayer through the sheet updates the ring',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      expect(find.text('٠/٩'), findsOneWidget);

      await t.tap(find.byType(PrayerRow).first);
      await t.pumpAndSettle();
      await t.tap(find.text('في المسجد').last);
      await t.pumpAndSettle();

      expect(find.text('١/٩'), findsOneWidget,
          reason: 'the ring reflects the new log immediately');
    });
  });

  testWidgets('a logged prayer persists across a rebuild', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      await t.tap(find.byType(PrayerRow).first);
      await t.pumpAndSettle();
      await t.tap(find.text('جماعة').last);
      await t.pumpAndSettle();

      // Rebuild the whole screen from the same database.
      await pumpHome(t);
      expect(find.text('١/٩'), findsOneWidget);
      expect(find.text('جماعة'), findsWidgets);
    });
  });

  testWidgets('shows either a next-prayer card or the day-done note',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      final hasCard = find.byType(NextPrayerCard).evaluate().isNotEmpty;
      final hasDone =
          find.textContaining('صلوات النهاردة خلصت').evaluate().isNotEmpty;
      expect(hasCard || hasDone, isTrue,
          reason: 'one of the two must always be present');
    });
  });
}
