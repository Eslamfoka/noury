import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/athkar/athkar_item.dart';
import 'package:nouri/data/athkar/athkar_repository.dart';
import 'package:nouri/data/athkar/quran_passage.dart';
import 'package:nouri/features/athkar/widgets/dhikr_card.dart';
import 'package:nouri/features/athkar/widgets/mushaf_card.dart';

import '../../support/harness.dart';

/// Loads the shipped assets straight from disk.
///
/// rootBundle is not available in a plain widget test, and reading the files
/// is the more honest check anyway: it tests what will be in the APK.
AthkarRepository diskRepository() => AthkarRepository(
      loadAsset: (path) async => File(path).readAsString(),
    );

const _ikhlas = QuranPassage(
  surahNameAr: 'الإخلاص',
  surahNumber: 112,
  bismillah: true,
  ayat: [
    'قُلْ هُوَ اللّٰهُ أَحَدٌ',
    'اللّٰهُ الصَّمَدُ',
    'لَمْ يَلِدْ وَلَمْ يُولَدْ',
    'وَلَمْ يَكُنْ لَهُ كُفُوًا أَحَدٌ',
  ],
);

AthkarItem quranItem() => AthkarItem(
      id: 'test-ikhlas',
      text: _ikhlas.reconstructedText,
      count: 3,
      source: 'سورة الإخلاص',
      passage: _ikhlas,
    );

const _plainItem = AthkarItem(
  id: 'test-plain',
  text: 'سُبْحَانَ اللهِ وَبِحَمْدِهِ',
  count: 100,
  source: 'رواه البخاري ومسلم',
);

void main() {
  group('QuranPassage', () {
    test('numbers a whole surah from one', () {
      expect(_ikhlas.numberFor(0), 1);
      expect(_ikhlas.numberFor(3), 4);
      expect(_ikhlas.isWholeSurah, isTrue);
    });

    test('an extract carries its real ayah numbers', () {
      // Ayat al-Kursi is 2:255, not verse 1 of anything.
      const kursi = QuranPassage(
        surahNameAr: 'البقرة',
        surahNumber: 2,
        ayat: ['اللّٰهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ'],
        istiadha: true,
        ayahNumbers: [255],
      );
      expect(kursi.numberFor(0), 255);
      expect(kursi.isWholeSurah, isFalse);
    });

    test('bismillah is a flag, never an ayah', () {
      expect(_ikhlas.bismillah, isTrue);
      expect(_ikhlas.ayat.any((a) => a.contains('بِسْمِ')), isFalse);
      expect(_ikhlas.ayat, hasLength(4),
          reason: 'الإخلاص is four ayat, and the Basmala is not one of them');
    });

    test('the marker is Arabic-Indic inside the ayah mark', () {
      expect(ayahMarker(4), '۝٤');
      expect(RegExp(r'[0-9]').hasMatch(ayahMarker(12)), isFalse);
    });

    test('rejects a block with no ayat', () {
      expect(
        () => QuranPassage.fromJson({'surah': 'الإخلاص', 'ayat': <String>[]}),
        throwsFormatException,
      );
    });

    test('rejects ayah numbers that do not match the ayat', () {
      expect(
        () => QuranPassage.fromJson({
          'surah': 'الفلق',
          'ayat': ['أ', 'ب'],
          'ayahNumbers': [1],
        }),
        throwsFormatException,
      );
    });
  });

  group('the shipped assets', () {
    test('every passage reproduces its entry text exactly', () async {
      // The guard that makes this change safe. docs/athkar-verification.md
      // lists athkar no human has checked yet, and the mushaf rendering must
      // not invalidate that review — so it may only move where the ayah breaks
      // fall, never add, drop or reword a single letter.
      final repo = diskRepository();
      var checked = 0;

      for (final c in AthkarRepository.categories) {
        for (final item in (await repo.load(c)).items) {
          final p = item.passage;
          if (p == null) continue;
          expect(p.reconstructedText, item.text,
              reason: '${item.id}: the mushaf split changed the text');
          checked++;
        }
      }

      expect(checked, 12,
          reason: 'all four Quranic entries in each of the three sets');
    });

    test('a malformed split is rejected at load, not rendered', () async {
      // Loudly, never silently: a card quietly disagreeing with its asset
      // would be altering religious content on screen.
      final raw = jsonDecode(
        await File('assets/athkar/morning.json').readAsString(),
      ) as Map<String, dynamic>;

      final items = raw['items'] as List;
      final item = items.firstWhere((e) => e['id'] == 'morning-02')
          as Map<String, dynamic>;
      (item['quran'] as Map<String, dynamic>)['ayat'] = ['قُلْ هُوَ اللّٰهُ أَحَدٌ'];

      expect(() => AthkarItem.fromJson(item), throwsFormatException);
    });

    test('the non-Quranic entries still have no passage', () async {
      final repo = diskRepository();
      final sleep = await repo.load('sleep');
      final first = sleep.items.firstWhere((i) => i.id == 'sleep-01');
      expect(first.isQuran, isFalse);
    });
  });

  group('MushafCard', () {
    testWidgets('puts the Basmala on its own centred line', (t) async {
      await t.pumpWidget(testShell(
        Scaffold(body: MushafCard(item: quranItem(), repeatsDone: 0)),
      ));
      await t.pumpAndSettle();

      final basmala = find.byKey(const ValueKey('mushaf-bismillah'));
      expect(basmala, findsOneWidget);
      expect(t.widget<Text>(basmala).textAlign, TextAlign.center);
      // Its own Text, above the ayat — not inline in the flow.
      expect(t.widget<Text>(basmala).data, isNot(contains('قُلْ')));
    });

    testWidgets('heads the passage with its surah name', (t) async {
      await t.pumpWidget(testShell(
        Scaffold(body: MushafCard(item: quranItem(), repeatsDone: 0)),
      ));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('mushaf-surah-band')), findsOneWidget);
      expect(find.text('سورة الإخلاص'), findsWidgets);
    });

    testWidgets('closes every ayah with its number', (t) async {
      await t.pumpWidget(testShell(
        Scaffold(body: MushafCard(item: quranItem(), repeatsDone: 0)),
      ));
      await t.pumpAndSettle();

      final block = t.widget<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.textAlign == TextAlign.justify));
      final plain = block.textSpan!.toPlainText();

      for (var n = 1; n <= 4; n++) {
        expect(plain, contains(ayahMarker(n)),
            reason: 'ayah $n should end in its own mark');
      }
      expect(RegExp(r'[0-9]').hasMatch(plain), isFalse,
          reason: 'ayah numbers are Arabic-Indic like every other number');
    });

    testWidgets('never puts a break between an ayah and its number',
        (t) async {
      // A space there is a line-break opportunity: the mark would wrap onto a
      // line of its own and leave the line before it stretched, because
      // Flutter justifies Arabic by widening word gaps rather than with
      // kashida.
      await t.pumpWidget(testShell(
        Scaffold(body: MushafCard(item: quranItem(), repeatsDone: 0)),
      ));
      await t.pumpAndSettle();

      final block = t.widget<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.textAlign == TextAlign.justify));
      final plain = block.textSpan!.toPlainText();

      for (final ayah in _ikhlas.ayat) {
        expect(plain, contains('$ayah۝'),
            reason: 'the mark must follow "$ayah" with no space between');
      }
    });

    testWidgets('sets the ayat as one justified block, not a line each',
        (t) async {
      // A mushaf does not break the line at every ayah, and doing so is what
      // made the old rendering read as fragments separated by commas.
      await t.pumpWidget(testShell(
        Scaffold(body: MushafCard(item: quranItem(), repeatsDone: 0)),
      ));
      await t.pumpAndSettle();

      final rich = t.widgetList<Text>(find.byType(Text)).where(
            (w) => w.textSpan != null && w.textAlign == TextAlign.justify,
          );
      expect(rich, hasLength(1));
    });

    testWidgets('shows الاستعاذة outside the frame when the entry has it',
        (t) async {
      const kursi = QuranPassage(
        surahNameAr: 'البقرة',
        surahNumber: 2,
        ayat: ['اللّٰهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ'],
        istiadha: true,
        ayahNumbers: [255],
      );
      final item = AthkarItem(
        id: 'test-kursi',
        text: kursi.reconstructedText,
        count: 1,
        source: 'آية الكرسي',
        passage: kursi,
      );

      await t.pumpWidget(
          testShell(Scaffold(body: MushafCard(item: item, repeatsDone: 0))));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('mushaf-istiadha')), findsOneWidget);
      expect(find.byKey(const ValueKey('mushaf-bismillah')), findsNothing,
          reason: 'an extract from the middle of a surah carries no Basmala');

      final block = t.widget<Text>(find.byWidgetPredicate(
          (w) => w is Text && w.textAlign == TextAlign.justify));
      expect(block.textSpan!.toPlainText(), contains(ayahMarker(255)));
    });

    testWidgets('still shows the source and the repeat count', (t) async {
      await t.pumpWidget(testShell(
        Scaffold(body: MushafCard(item: quranItem(), repeatsDone: 2)),
      ));
      await t.pumpAndSettle();

      expect(find.text('سورة الإخلاص'), findsWidgets);
      expect(find.text('٢ من ٣'), findsOneWidget);
    });
  });

  group('DhikrCard routing', () {
    testWidgets('a Quranic entry renders as a mushaf', (t) async {
      await t.pumpWidget(testShell(Scaffold(
        body: DhikrCard(item: quranItem(), repeatsDone: 0, onTap: () {}),
      )));
      await t.pumpAndSettle();
      expect(find.byType(MushafCard), findsOneWidget);
    });

    testWidgets('a plain dhikr renders exactly as before', (t) async {
      await t.pumpWidget(testShell(Scaffold(
        body: DhikrCard(item: _plainItem, repeatsDone: 0, onTap: () {}),
      )));
      await t.pumpAndSettle();

      expect(find.byType(MushafCard), findsNothing);
      expect(find.text('سُبْحَانَ اللهِ وَبِحَمْدِهِ'), findsOneWidget);
      expect(find.text('٠ من ١٠٠'), findsOneWidget);
    });
  });
}
