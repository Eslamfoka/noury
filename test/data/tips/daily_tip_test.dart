import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/tips/daily_tip.dart';

void main() {
  late Map<TipPillar, TipSet> sets;

  setUpAll(() async {
    final repo = TipRepository(
      loadAsset: (path) async => File(path).readAsString(),
    );
    sets = await repo.loadAll();
  });

  group('bundled content', () {
    test('all three pillars are present with enough items', () {
      for (final pillar in TipPillar.values) {
        expect(sets[pillar], isNotNull, reason: pillar.name);
        expect(sets[pillar]!.items.length, greaterThanOrEqualTo(30),
            reason: pillar.name);
      }
    });

    test('ids are unique within and across pillars', () {
      final all = sets.values.expand((s) => s.items).map((t) => t.id).toList();
      expect(all.toSet().length, all.length);
    });

    test('every tip is Arabic and free of western digits', () {
      for (final tip in sets.values.expand((s) => s.items)) {
        expect(RegExp(r'[؀-ۿ]').hasMatch(tip.text), isTrue, reason: tip.id);
        expect(RegExp(r'[0-9]').hasMatch(tip.text), isFalse, reason: tip.id);
      }
    });

    test('no tip blames or scolds', () {
      const forbidden = ['فاتتك', 'ضيعت', 'فشل', 'كسول', 'مقصّر'];
      for (final tip in sets.values.expand((s) => s.items)) {
        for (final w in forbidden) {
          expect(tip.text.contains(w), isFalse, reason: '${tip.id}: $w');
        }
      }
    });

    test('body and wealth carry their required disclaimers', () {
      // The brief is explicit: Nouri is neither a doctor nor a financial
      // adviser, and must say so.
      expect(sets[TipPillar.body]!.note, isNotNull);
      expect(sets[TipPillar.body]!.note, contains('دكتور'));
      expect(sets[TipPillar.wealth]!.note, isNotNull);
      expect(sets[TipPillar.wealth]!.note, contains('مستشار'));
      expect(sets[TipPillar.deen]!.note, isNull,
          reason: 'the deen set needs no disclaimer');
    });

    test('no body tip diagnoses or prescribes', () {
      const clinical = ['علاج', 'دواء', 'جرعة', 'تشخيص', 'مرض'];
      for (final tip in sets[TipPillar.body]!.items) {
        for (final w in clinical) {
          expect(tip.text.contains(w), isFalse, reason: '${tip.id}: $w');
        }
      }
    });
  });

  test('every pillar has a short visible label', () {
    // The label is what makes the holistic structure legible on Home.
    expect(TipPillar.deen.arabicLabel, 'دين');
    expect(TipPillar.body.arabicLabel, 'بدن');
    expect(TipPillar.wealth.arabicLabel, 'مال');
    for (final p in TipPillar.values) {
      expect(p.arabicLabel.length, lessThanOrEqualTo(4),
          reason: 'a long label would compete with the tip itself');
    }
  });

  group('rotation', () {
    test('cycles deen, body, wealth across consecutive days', () {
      final start = DateTime(2026, 9, 6);
      final seen = [
        for (var i = 0; i < 3; i++)
          pillarForDay(start.add(Duration(days: i))),
      ];
      expect(seen.toSet().length, 3, reason: 'all three within three days');
    });

    test('the same day always yields the same tip', () {
      final a = tipForDay(DateTime(2026, 9, 6, 6), sets);
      final b = tipForDay(DateTime(2026, 9, 6, 23), sets);
      expect(a!.id, b!.id,
          reason: 'the line must not flicker as the day goes on');
    });

    test('consecutive days give different tips', () {
      final a = tipForDay(DateTime(2026, 9, 6), sets)!;
      final b = tipForDay(DateTime(2026, 9, 7), sets)!;
      expect(a.id, isNot(b.id));
    });

    test('the whole of each list is used before anything repeats', () {
      // A naive index would show only a third of each list forever, because a
      // pillar comes round every third day.
      final ids = <String>{};
      var date = DateTime(2026, 1, 1);
      for (var i = 0; i < 90; i++) {
        final tip = tipForDay(date, sets);
        if (tip != null && tip.pillar == TipPillar.deen) ids.add(tip.id);
        date = date.add(const Duration(days: 1));
      }
      expect(ids.length, 30, reason: 'all 30 deen tips seen in 90 days');
    });

    test('an empty set yields no tip rather than throwing', () {
      final empty = {
        for (final p in TipPillar.values)
          p: TipSet(pillar: p, items: const []),
      };
      expect(tipForDay(DateTime(2026, 9, 6), empty), isNull);
    });
  });

  group('parsing', () {
    test('a tip with no text is rejected', () {
      expect(
        () => Tip.fromJson({'id': 'x', 'text': ''}, TipPillar.deen),
        throwsA(isA<FormatException>()),
      );
    });

    test('duplicate ids in one set are rejected', () {
      expect(
        () => TipSet.fromJson({
          'version': 1,
          'pillar': 'deen',
          'items': [
            {'id': 'a', 'text': 'نص'},
            {'id': 'a', 'text': 'نص'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('an unknown pillar is rejected', () {
      expect(
        () => TipSet.fromJson(
            {'version': 1, 'pillar': 'nonsense', 'items': []}),
        throwsA(isA<FormatException>()),
      );
    });

    test('the repository caches, reading each asset once', () async {
      var reads = 0;
      final repo = TipRepository(loadAsset: (path) async {
        reads++;
        return File(path).readAsString();
      });
      await repo.loadAll();
      await repo.loadAll();
      expect(reads, 3, reason: 'three files, read once each');
    });
  });
}
