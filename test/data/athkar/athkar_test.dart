import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/athkar/athkar_item.dart';
import 'package:nouri/data/athkar/athkar_repository.dart';

void main() {
  group('AthkarItem', () {
    test('parses a complete entry', () {
      final item = AthkarItem.fromJson({
        'id': 'morning-01',
        'text': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
        'count': 1,
        'source': 'رواه مسلم',
        'virtue': null,
      });
      expect(item.id, 'morning-01');
      expect(item.count, 1);
      expect(item.source, 'رواه مسلم');
      expect(item.virtue, isNull);
      expect(item.hasVirtue, isFalse);
    });

    test('an entry with no source is rejected', () {
      expect(
        () => AthkarItem.fromJson(
            {'id': 'x', 'text': 'نص', 'count': 1, 'source': ''}),
        throwsA(isA<FormatException>()),
      );
    });

    test('a count below one is rejected', () {
      expect(
        () => AthkarItem.fromJson(
            {'id': 'x', 'text': 'نص', 'count': 0, 'source': 'رواه البخاري'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('empty text is rejected', () {
      expect(
        () => AthkarItem.fromJson(
            {'id': 'x', 'text': '', 'count': 1, 'source': 'رواه البخاري'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('hasVirtue is false for an empty string as well as null', () {
      final item = AthkarItem.fromJson({
        'id': 'x',
        'text': 'نص',
        'count': 1,
        'source': 'رواه البخاري',
        'virtue': '   ',
      });
      expect(item.hasVirtue, isFalse);
      expect(item.virtue, isNull);
    });

    test('duplicate ids in a set are rejected', () {
      expect(
        () => AthkarSet.fromJson({
          'version': 1,
          'category': 'morning',
          'items': [
            {'id': 'a', 'text': 'ن', 'count': 1, 'source': 'س'},
            {'id': 'a', 'text': 'ن', 'count': 1, 'source': 'س'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('bundled assets', () {
    const expectedMinimums = {
      'assets/athkar/morning.json': 15,
      'assets/athkar/evening.json': 15,
      'assets/athkar/sleep.json': 10,
      'assets/athkar/tasbeeh.json': 1,
    };

    expectedMinimums.forEach((path, minCount) {
      group(path, () {
        late AthkarSet set;

        setUpAll(() {
          set = AthkarSet.fromJson(
              jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);
        });

        test('parses and carries the expected number of items', () {
          expect(set.items.length, greaterThanOrEqualTo(minCount));
        });

        test('every item has a non-empty source', () {
          for (final i in set.items) {
            expect(i.source.trim(), isNotEmpty, reason: i.id);
          }
        });

        test('ids are unique', () {
          expect(set.items.map((i) => i.id).toSet().length, set.items.length);
        });

        test('text is Arabic and carries no western digits', () {
          for (final i in set.items) {
            expect(RegExp(r'[؀-ۿ]').hasMatch(i.text), isTrue,
                reason: i.id);
            expect(RegExp(r'[0-9]').hasMatch(i.text), isFalse, reason: i.id);
          }
        });

        test('counts are sane', () {
          for (final i in set.items) {
            expect(i.count, greaterThanOrEqualTo(1), reason: i.id);
            expect(i.count, lessThanOrEqualTo(100), reason: i.id);
          }
        });

        test('a stated virtue is never an empty placeholder', () {
          // The rule is: ship a virtue only where the wording is
          // well-established, otherwise null. A whitespace-only string would
          // mean someone intended text and left it blank.
          for (final i in set.items) {
            if (i.virtue != null) {
              expect(i.virtue!.trim().length, greaterThan(10), reason: i.id);
            }
          }
        });
      });
    });

    test('every category the repository knows about exists on disk', () {
      for (final c in AthkarRepository.categories) {
        expect(File('assets/athkar/$c.json').existsSync(), isTrue, reason: c);
      }
    });
  });

  group('AthkarRepository', () {
    test('loads a set through the injected loader', () async {
      final repo = AthkarRepository(
        loadAsset: (path) async => File(path).readAsString(),
      );
      final set = await repo.load('morning');
      expect(set.category, 'morning');
      expect(set.items, isNotEmpty);
    });

    test('caches, so the asset is read once', () async {
      var reads = 0;
      final repo = AthkarRepository(loadAsset: (path) async {
        reads++;
        return File(path).readAsString();
      });
      await repo.load('morning');
      await repo.load('morning');
      expect(reads, 1);
    });

    test('totalRepeats sums every dhikr count', () async {
      final repo = AthkarRepository(
        loadAsset: (path) async => File(path).readAsString(),
      );
      final set = await repo.load('sleep');
      final expected =
          set.items.fold<int>(0, (a, i) => a + i.count);
      expect(set.totalRepeats, expected);
    });
  });
}
