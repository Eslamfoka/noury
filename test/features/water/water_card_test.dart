import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/water/water_card.dart';

import '../../support/harness.dart';

void main() {
  late NouriDatabase db;

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(testApp(
      db: db,
      child: const Scaffold(
        body: Padding(padding: EdgeInsets.all(16), child: WaterCard()),
      ),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('a fresh day starts at zero and invites a first glass',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      expect(find.text('٠ من ٨'), findsOneWidget);
      expect(find.textContaining('ابدأ'), findsOneWidget);
    });
  });

  testWidgets('drinking a glass counts it and persists it', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('water-add')));
      await t.pumpAndSettle();

      expect(find.text('١ من ٨'), findsOneWidget);
      expect((await db.waterDao.forDate(DateTime.now()))!.glasses, 1);
    });
  });

  testWidgets('a mistap can be taken back, and never goes negative',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('water-remove')));
      await t.pumpAndSettle();
      expect(find.text('٠ من ٨'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('water-add')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('water-remove')));
      await t.pumpAndSettle();
      expect(find.text('٠ من ٨'), findsOneWidget);
    });
  });

  testWidgets('reaching the target says so without praise or scolding',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.waterDao.add(DateTime.now(), 8, target: 8);
      await pump(t);

      expect(find.text('٨ من ٨'), findsOneWidget);
      expect(find.textContaining('تمام'), findsOneWidget);
    });
  });

  testWidgets('marking today as a fast is the user saying so, and it sticks',
      (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      // Never inferred: Nouri suggests the sunnah fasts but cannot know
      // whether one was kept.
      expect(await db.waterDao.isFasting(DateTime.now()), isFalse);
      expect(find.text('صايم النهاردة؟'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('water-fasting-switch')));
      await t.pumpAndSettle();

      expect(await db.waterDao.isFasting(DateTime.now()), isTrue);
      expect(find.textContaining('مفيش تنبيه مياه لحد المغرب'), findsOneWidget);
    });
  });

  testWidgets('a fasting day can be unmarked again', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.waterDao.setFasting(DateTime.now(), true);
      await pump(t);

      await t.tap(find.byKey(const ValueKey('water-fasting-switch')));
      await t.pumpAndSettle();
      expect(await db.waterDao.isFasting(DateTime.now()), isFalse);
    });
  });

  testWidgets('nothing on the card is red', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pump(t);

      for (final text in t.widgetList<Text>(find.byType(Text))) {
        final c = text.style?.color;
        if (c == null) continue;
        expect(c.r > 0.75 && c.g < 0.55 && c.b < 0.55, isFalse,
            reason: 'found a red-ish colour on "${text.data}"');
      }
    });
  });
}
