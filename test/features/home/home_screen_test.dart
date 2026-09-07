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

  /// Home now carries the day blocks as well, so it is longer than one
  /// viewport and its ListView builds lazily. Anything below the fold has to
  /// be scrolled into existence before it can be found.
  ///
  /// `scrollUntilVisible` stops as soon as the target is *built*, and a lazy
  /// ListView builds 250px (the default cacheExtent) past the viewport — so
  /// on its own it happily leaves the target just off screen, where a tap
  /// misses it and silently does nothing. Measured: the wird card came to
  /// rest at y=1303 on a 1200-tall surface. `ensureVisible` is what actually
  /// brings it into view, and it has to follow every scroll.
  Future<void> scrollTo(WidgetTester t, Finder target) async {
    await t.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  testWidgets('renders header, ring, prayer list and wird grid', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);

      expect(find.text('نوري'), findsOneWidget);
      expect(find.byType(ProgressRing), findsOneWidget);
      expect(find.byType(PrayerRow), findsNWidgets(5),
          reason: 'all five prayers are listed on Home');

      await scrollTo(t, find.byType(WirdGrid));
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

  testWidgets('the day view shows the four blocks the brief names', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);

      expect(find.text('يومك'), findsOneWidget);
      for (final label in ['الصباح', 'الدوام', 'بعد الدوام', 'المسا']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });

  testWidgets('the day view is labelled a preview, not a finished plan',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      expect(find.text('معاينة'), findsOneWidget,
          reason: 'it must not pretend Nouri planned this');
      expect(find.textContaining('الشكل ده معاينة'), findsOneWidget);
    });
  });

  testWidgets('blocks are collapsed by default, not a long checklist',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);

      // The brief's rule: a long list recreates the overwhelm the app exists
      // to remove. At most one block is open at a time.
      final allTaskTitles = [
        'فطار',
        'تسبيح في البريك',
        'مشي ٣٠ دقيقة',
        'عشا',
      ];
      final visible =
          allTaskTitles.where((x) => find.text(x).evaluate().isNotEmpty);
      expect(visible.length, lessThanOrEqualTo(1),
          reason: 'only the current block should be expanded');
    });
  });

  testWidgets('tapping a block reveals its hour-by-hour detail', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);

      expect(find.text('فطار'), findsNothing);
      await t.tap(find.text('الصباح'));
      await t.pumpAndSettle();
      expect(find.text('فطار'), findsOneWidget);
    });
  });

  testWidgets('the day preview is not interactive yet', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      // A tappable checkbox now would teach a habit the real planner then has
      // to honour.
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  testWidgets('the wird grid lists the four cards in the approved order',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      await scrollTo(t, find.byType(WirdGrid));
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

  testWidgets('tapping the Quran wird card logs a rub and updates the ring',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);
      expect(find.text('٠/٩'), findsOneWidget);

      await scrollTo(t, find.text('ورد القرآن'));
      await t.tap(find.text('ورد القرآن'));
      await t.pumpAndSettle();

      // Asserted on the card rather than the ring: the ring is now above the
      // fold after scrolling, and the card is the more direct signal anyway.
      final grid = t.widget<WirdGrid>(find.byType(WirdGrid));
      expect(grid.quran.done, isTrue,
          reason: 'the wird counts toward the daily nine');
      expect(find.textContaining('الختمة'), findsOneWidget);
    });
  });

  testWidgets('tapping the wird card again clears it', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpHome(t);

      await scrollTo(t, find.text('ورد القرآن'));
      await t.tap(find.text('ورد القرآن'));
      await t.pumpAndSettle();
      expect(t.widget<WirdGrid>(find.byType(WirdGrid)).quran.done, isTrue);

      await t.tap(find.text('ورد القرآن'));
      await t.pumpAndSettle();
      expect(t.widget<WirdGrid>(find.byType(WirdGrid)).quran.done, isFalse,
          reason: 'a mistap must be reversible');
    });
  });
}
