import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/body/body_providers.dart';
import 'package:nouri/features/body/body_screen.dart';

import '../../support/harness.dart';

void main() {
  late NouriDatabase db;

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(
      testApp(db: db, child: const Scaffold(body: BodyScreen())),
    );
    await t.pumpAndSettle();
  }

  group('weight parsing', () {
    test('reads kilograms with a fraction', () {
      expect(parseWeightKg('87.4'), 87400);
      expect(parseWeightKg('87'), 87000);
    });

    test('accepts Arabic digits and separator', () {
      expect(parseWeightKg('٨٧٫٤'), 87400);
    });

    test('pads a short fraction rather than misreading it', () {
      // "87.4" is 87.4 kg, not 87 kg and 4 grams.
      expect(parseWeightKg('87.4'), 87400);
      expect(parseWeightKg('87.04'), 87040);
    });

    test('rejects a reading no human produces', () {
      // A missed decimal point is the common typo, and 874 kg silently
      // wrecks every later trend.
      expect(parseWeightKg('874'), isNull);
      expect(parseWeightKg('8'), isNull);
      expect(parseWeightKg(''), isNull);
      expect(parseWeightKg('abc'), isNull);
    });

    test('formats the way a scale reads', () {
      expect(formatWeight(87400), contains('كجم'));
      expect(RegExp(r'[0-9]').hasMatch(formatWeight(87400)), isFalse,
          reason: 'numbers are Arabic-Indic throughout the app');
    });
  });

  group('the screen', () {
    testWidgets('leads with logging a meal, not a number', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);
        expect(find.text('سجّل وجبة'), findsOneWidget);
        expect(find.text('سجّل وزنك'), findsOneWidget);
      });
    });

    testWidgets('never mentions calories', (t) async {
      // The brief rules calorie counting out explicitly.
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);
        for (final word in ['سعرة', 'سعرات', 'كالوري']) {
          expect(find.textContaining(word), findsNothing, reason: word);
        }
      });
    });

    testWidgets('states plainly that it is not a doctor', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);
        await t.scrollUntilVisible(
          find.textContaining('مش دكتور'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('مش دكتور'), findsOneWidget);
      });
    });

    testWidgets('a logged meal appears with how it felt', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await db.bodyDao.addMeal(
          at: DateTime.now(),
          feeling: MealFeeling.bloating,
          description: 'فول',
        );

        await pump(t);
        expect(find.text('فول'), findsOneWidget);
        expect(find.text('انتفاخ'), findsOneWidget);
      });
    });

    testWidgets('a symptom is never shown in red', (t) async {
      // Pain is information, not a failure. The no-blame rule applies to the
      // body pillar exactly as it does to prayers.
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await db.bodyDao.addMeal(at: DateTime.now(), feeling: MealFeeling.pain);
        await pump(t);

        bool isRed(Color? c) =>
            c != null && c.r * 255 > 200 && c.g * 255 < 90 && c.b * 255 < 90;
        final reds = t
            .widgetList<Text>(find.byType(Text))
            .where((w) => isRed(w.style?.color));
        expect(reds, isEmpty);
      });
    });

    testWidgets('says nothing about patterns from too few meals', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await db.bodyDao.addMeal(at: DateTime.now(), feeling: MealFeeling.pain);
        await pump(t);
        expect(find.textContaining('من آخر'), findsNothing,
            reason: 'one meal is not a pattern');
      });
    });

    testWidgets('describes a pattern without naming a cause', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        final now = DateTime.now();
        for (var i = 0; i < 4; i++) {
          await db.bodyDao.addMeal(
            at: now.subtract(Duration(hours: i)),
            feeling: i.isEven ? MealFeeling.pain : MealFeeling.good,
          );
        }
        await pump(t);

        await t.scrollUntilVisible(
          find.textContaining('من آخر'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('من آخر'), findsOneWidget);

        // Anything that names a cause or prescribes a change is diagnosis.
        for (final word in ['بسبب', 'تجنب', 'امتنع', 'حساسية', 'التهاب']) {
          expect(find.textContaining(word), findsNothing, reason: word);
        }
      });
    });

    testWidgets('a meal can be swiped away', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await db.bodyDao.addMeal(
          at: DateTime.now(),
          feeling: MealFeeling.good,
          description: 'عشا',
        );
        await pump(t);

        // RTL: endToStart is a drag toward the right.
        await t.drag(find.text('عشا'), const Offset(500, 0));
        await t.pumpAndSettle();

        expect(await db.bodyDao.mealsOn(DateTime.now()), isEmpty);
      });
    });
  });
}
