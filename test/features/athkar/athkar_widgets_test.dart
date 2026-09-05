import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/athkar/athkar_item.dart';
import 'package:nouri/features/athkar/athkar_screen.dart';
import 'package:nouri/features/athkar/widgets/dhikr_card.dart';
import 'package:nouri/features/athkar/widgets/tasbeeh_ring.dart';

import '../../support/harness.dart';

void main() {
  Future<void> pump(WidgetTester t, Widget child) => t.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: child),
          ),
        ),
      );

  group('DhikrCard', () {
    testWidgets('renders the dhikr in Amiri and shows the source', (t) async {
      await pump(
        t,
        DhikrCard(
          item: const AthkarItem(
            id: 'a',
            text: 'سُبْحَانَ اللهِ',
            count: 3,
            source: 'رواه مسلم',
          ),
          repeatsDone: 0,
          onTap: () {},
        ),
      );
      final text = t.widget<Text>(find.text('سُبْحَانَ اللهِ'));
      expect(text.style?.fontFamily, 'Amiri');
      expect(find.text('رواه مسلم'), findsOneWidget);
    });

    testWidgets('shows the repeat pill in Arabic-Indic digits', (t) async {
      await pump(
        t,
        DhikrCard(
          item: const AthkarItem(
              id: 'a', text: 'نص', count: 3, source: 'رواه مسلم'),
          repeatsDone: 1,
          onTap: () {},
        ),
      );
      expect(find.text('١ / ٣'), findsOneWidget);
    });

    testWidgets('the virtue is hidden until tapped', (t) async {
      await pump(
        t,
        DhikrCard(
          item: const AthkarItem(
            id: 'a',
            text: 'نص',
            count: 1,
            source: 'رواه مسلم',
            virtue: 'فضل الذكر المذكور هنا',
          ),
          repeatsDone: 0,
          onTap: () {},
        ),
      );
      expect(find.text('فضل الذكر المذكور هنا'), findsNothing);
      await t.tap(find.text('الفضل'));
      await t.pumpAndSettle();
      expect(find.text('فضل الذكر المذكور هنا'), findsOneWidget);
    });

    testWidgets('no virtue means no reveal control at all', (t) async {
      await pump(
        t,
        DhikrCard(
          item: const AthkarItem(
            id: 'a',
            text: 'نص',
            count: 1,
            source: 'رواه مسلم',
            virtue: null,
          ),
          repeatsDone: 0,
          onTap: () {},
        ),
      );
      expect(find.text('الفضل'), findsNothing);
    });
  });

  group('TasbeehRing', () {
    testWidgets('shows the count and target in Arabic-Indic digits',
        (t) async {
      await pump(t, TasbeehRing(count: 33, target: 100, onTap: () {}));
      expect(find.text('٣٣'), findsOneWidget);
      expect(find.text('من ١٠٠'), findsOneWidget);
    });

    testWidgets('tapping the ring increments', (t) async {
      var taps = 0;
      await pump(t, TasbeehRing(count: 0, target: 100, onTap: () => taps++));
      await t.tap(find.byType(TasbeehRing));
      expect(taps, 1);
    });

    testWidgets('a very large target still renders', (t) async {
      // Above the bead threshold the ring switches to a continuous arc.
      await pump(t, TasbeehRing(count: 500, target: 1000, onTap: () {}));
      expect(find.text('٥٠٠'), findsOneWidget);
    });
  });

  group('AthkarScreen', () {
    testWidgets('opens on the tasbeeh tab with the four tabs shown',
        (tester) async {
      await withLargeSurface(tester, () async {
        final db = inMemoryDatabase(tester);
        await tester.pumpWidget(
          testApp(db: db, child: const Scaffold(body: AthkarScreen())),
        );
        await tester.pumpAndSettle();

        expect(find.text('التسبيح'), findsOneWidget);
        expect(find.text('الصباح'), findsOneWidget);
        expect(find.text('المساء'), findsOneWidget);
        expect(find.text('النوم'), findsOneWidget);
        expect(find.byType(TasbeehRing), findsOneWidget);
      });
    });

    testWidgets('tapping «سبّح» increments the counter', (tester) async {
      await withLargeSurface(tester, () async {
        final db = inMemoryDatabase(tester);
        await tester.pumpWidget(
          testApp(db: db, child: const Scaffold(body: AthkarScreen())),
        );
        await tester.pumpAndSettle();

        expect(find.text('٠'), findsOneWidget);
        await tester.tap(find.text('سبّح'));
        await tester.pumpAndSettle();
        expect(find.text('١'), findsOneWidget);
      });
    });

    testWidgets('the tasbeeh count survives leaving and returning',
        (tester) async {
      await withLargeSurface(tester, () async {
        final db = inMemoryDatabase(tester);

        await tester.pumpWidget(
          testApp(db: db, child: const Scaffold(body: AthkarScreen())),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('سبّح'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('سبّح'));
        await tester.pumpAndSettle();
        expect(find.text('٢'), findsOneWidget);

        // Rebuild the screen from scratch against the same database.
        await tester.pumpWidget(
          testApp(db: db, child: const Scaffold(body: SizedBox())),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          testApp(db: db, child: const Scaffold(body: AthkarScreen())),
        );
        await tester.pumpAndSettle();

        expect(find.text('٢'), findsOneWidget,
            reason: 'the count is persisted, not held in the widget');
      });
    });
  });
}
