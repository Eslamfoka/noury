import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/knowledge/knowledge_card.dart';

import '../../support/harness.dart';

void main() {
  late NouriDatabase db;

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(testApp(
      db: db,
      child: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: KnowledgeCard(),
        ),
      ),
    ));
    await t.pumpAndSettle();
  }

  group('the card', () {
    testWidgets('offers all three faces of knowledge time', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);

        for (final k in KnowledgeKind.values) {
          expect(find.byKey(ValueKey('knowledge-log-${k.name}')),
              findsOneWidget, reason: k.name);
        }
      });
    });

    testWidgets('a fresh day shows a dash and names the minimum', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);

        expect(find.text('—'), findsOneWidget);
        expect(find.textContaining('١٠ دقايق'), findsOneWidget);
      });
    });

    testWidgets('logging a session records it and shows the total', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);

        await t.tap(find.byKey(
            ValueKey('knowledge-log-${KnowledgeKind.reading.name}')));
        await t.pumpAndSettle();

        await t.tap(find.byKey(const ValueKey('knowledge-minutes-30')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('knowledge-save')));
        await t.pumpAndSettle();

        final rows = await db.knowledgeDao.forDate(DateTime.now());
        expect(rows, hasLength(1));
        expect(rows.single.kind, KnowledgeKind.reading);
        expect(rows.single.minutes, 30);
        expect(find.text('٣٠ دقيقة'), findsOneWidget);
      });
    });

    testWidgets('a note is kept when given, and optional when not', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);

        await t.tap(find.byKey(
            ValueKey('knowledge-log-${KnowledgeKind.skill.name}')));
        await t.pumpAndSettle();
        await t.enterText(
            find.byKey(const ValueKey('knowledge-note-field')), 'Flutter');
        await t.tap(find.byKey(const ValueKey('knowledge-save')));
        await t.pumpAndSettle();

        final rows = await db.knowledgeDao.forDate(DateTime.now());
        expect(rows.single.note, 'Flutter');
        expect(find.textContaining('Flutter'), findsOneWidget);
      });
    });

    testWidgets('a double tap on «سجّل» records one session, not two',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);

        await t.tap(find.byKey(
            ValueKey('knowledge-log-${KnowledgeKind.reading.name}')));
        await t.pumpAndSettle();

        final save = find.byKey(const ValueKey('knowledge-save'));
        await t.tap(save);
        await t.tap(save, warnIfMissed: false);
        await t.pumpAndSettle();

        expect(await db.knowledgeDao.forDate(DateTime.now()), hasLength(1));
      });
    });

    testWidgets('a logged session can be removed again', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        final id = await db.knowledgeDao.add(
          date: DateTime.now(),
          kind: KnowledgeKind.reading,
          minutes: 20,
        );
        await pump(t);

        await t.tap(find.byKey(ValueKey('knowledge-delete-$id')));
        await t.pumpAndSettle();
        expect(await db.knowledgeDao.forDate(DateTime.now()), isEmpty);
      });
    });

    testWidgets('reaching the minimum says so without praise or scolding',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await db.knowledgeDao.add(
          date: DateTime.now(),
          kind: KnowledgeKind.reading,
          minutes: 15,
        );
        await pump(t);

        expect(find.textContaining('كفاية النهاردة'), findsOneWidget);
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

    testWidgets('Nouri does not pretend to recommend a book', (t) async {
      // The brief wants Nouri to suggest books and propose a learning path.
      // That is AI work for Slice 5, and a card that named a title now would
      // be inventing one.
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pump(t);
        for (final claim in ['اقرأ كتاب', 'ننصحك', 'الكتاب المقترح']) {
          expect(find.textContaining(claim), findsNothing, reason: claim);
        }
      });
    });
  });

  group('the DAO', () {
    NouriDatabase fresh() {
      final d = NouriDatabase.forTesting(NativeDatabase.memory());
      addTearDown(d.close);
      return d;
    }

    test('minutes total across all three kinds — it is one block', () async {
      final d = fresh();
      final day = DateTime(2026, 9, 7);
      await d.knowledgeDao
          .add(date: day, kind: KnowledgeKind.reading, minutes: 20);
      await d.knowledgeDao
          .add(date: day, kind: KnowledgeKind.skill, minutes: 15);
      await d.knowledgeDao.add(
          date: day, kind: KnowledgeKind.religiousContent, minutes: 10);

      expect(await d.knowledgeDao.minutesOn(day), 45);
      expect(await d.knowledgeDao.forDate(day), hasLength(3));
    });

    test('an evening session lands on the day it was logged', () async {
      final d = fresh();
      await d.knowledgeDao.add(
        date: DateTime(2026, 9, 7, 23, 40),
        kind: KnowledgeKind.reading,
        minutes: 20,
      );
      expect(await d.knowledgeDao.minutesOn(DateTime(2026, 9, 7)), 20);
      expect(await d.knowledgeDao.minutesOn(DateTime(2026, 9, 8)), 0);
    });

    test('a day with nothing is zero, not an error', () async {
      expect(await fresh().knowledgeDao.minutesOn(DateTime(2026, 9, 7)), 0);
    });

    test('between spans whole days at both ends', () async {
      final d = fresh();
      for (final day in [5, 6, 7, 8]) {
        await d.knowledgeDao.add(
          date: DateTime(2026, 9, day),
          kind: KnowledgeKind.reading,
          minutes: 10,
        );
      }
      final rows = await d.knowledgeDao
          .between(DateTime(2026, 9, 6), DateTime(2026, 9, 7));
      expect(rows, hasLength(2));
    });
  });
}
