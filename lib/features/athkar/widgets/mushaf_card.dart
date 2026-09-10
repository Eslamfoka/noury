import 'package:flutter/material.dart';

import '../../../core/format/arabic_numerals.dart';
import '../../../core/theme/nouri_colors.dart';
import '../../../core/theme/nouri_theme.dart';
import '../../../data/athkar/athkar_item.dart';
import '../../../data/athkar/quran_passage.dart';

/// A Qur'anic athkar entry, typeset like a mushaf page.
///
/// Not an image. An image cannot scale with the user's text size, cannot be
/// selected or read aloud, and would add megabytes for a handful of surahs.
/// Amiri is already bundled and is a mushaf-style face, so the page is set in
/// text — which also means the words on screen are provably the same words in
/// the asset.
///
/// The three things that make it read as a mushaf rather than as a paragraph:
/// the Basmala sits on its own centred line and carries no number, the ayat
/// run together in one justified block rather than one per line, and each ayah
/// ends in a circled number instead of a comma.
class MushafCard extends StatelessWidget {
  const MushafCard({
    super.key,
    required this.item,
    required this.repeatsDone,
  });

  final AthkarItem item;
  final int repeatsDone;

  QuranPassage get passage => item.passage!;

  @override
  Widget build(BuildContext context) {
    final p = passage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Said before reciting, but not printed on a mushaf page — so it sits
        // outside the frame, in interface type rather than in Amiri.
        if (p.istiadha) ...[
          Text(
            QuranPassage.istiadhaText,
            key: const ValueKey('mushaf-istiadha'),
            textAlign: TextAlign.center,
            style: cairo(size: 12, color: NouriColors.muted, height: 1.9),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          decoration: BoxDecoration(
            color: NouriColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NouriColors.gold.withValues(alpha: 0.55)),
          ),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
          child: Column(
            children: [
              _SurahBand(passage: p),
              const SizedBox(height: 14),
              if (p.bismillah) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    // Without the trailing full stop: on a mushaf page the
                    // Basmala is a line of its own, not a sentence in a
                    // paragraph.
                    'بِسْمِ اللهِ الرَّحْمَٰنِ الرَّحِيمِ',
                    key: const ValueKey('mushaf-bismillah'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 19,
                      height: 1.9,
                      color: NouriColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                child: _AyatBlock(passage: p),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.source,
          textAlign: TextAlign.center,
          style: cairo(size: 11, color: NouriColors.muted),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: NouriColors.surfaceActive,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: NouriColors.border),
            ),
            child: Text(
              // «من», not a slash — see _RepeatPill in dhikr_card.dart.
              toArabicDigits('$repeatsDone من ${item.count}'),
              style: cairo(size: 13, weight: FontWeight.w600),
            ),
          ),
        ),
        if (item.note != null) ...[
          const SizedBox(height: 10),
          Text(
            item.note!,
            textAlign: TextAlign.center,
            style: cairo(size: 10.5, color: NouriColors.muted),
          ),
        ],
      ],
    );
  }
}

/// The surah name in a header band, the way a mushaf heads a surah.
class _SurahBand extends StatelessWidget {
  const _SurahBand({required this.passage});

  final QuranPassage passage;

  @override
  Widget build(BuildContext context) {
    final p = passage;
    final label = p.isWholeSurah
        ? 'سورة ${p.surahNameAr}'
        : toArabicDigits(
            'سورة ${p.surahNameAr} — ${p.numberFor(0)}',
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
      decoration: BoxDecoration(
        color: NouriColors.surfaceActive,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: NouriColors.border),
      ),
      child: Text(
        label,
        key: const ValueKey('mushaf-surah-band'),
        textAlign: TextAlign.center,
        style: cairo(size: 12.5, weight: FontWeight.w700,
            color: NouriColors.gold),
      ),
    );
  }
}

/// Every ayah in one justified block, each closed by a circled number.
///
/// One block, not one line per ayah: a mushaf does not break the line at every
/// ayah, and doing so is exactly what made the old rendering read as a list of
/// fragments separated by commas.
class _AyatBlock extends StatelessWidget {
  const _AyatBlock({required this.passage});

  final QuranPassage passage;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];

    for (var i = 0; i < passage.ayat.length; i++) {
      // The space belongs *before* the next ayah, never between an ayah and
      // its own number. A space there is a line-break opportunity, and the
      // ornament would wrap onto a line of its own — which also leaves the
      // line before it justified, and Flutter justifies Arabic by stretching
      // word gaps rather than with kashida, so it comes out full of holes.
      if (i > 0) spans.add(const TextSpan(text: ' '));

      spans.add(TextSpan(text: passage.ayat[i]));
      spans.add(TextSpan(
        text: ayahMarker(passage.numberFor(i)),
        style: const TextStyle(
          fontFamily: 'Amiri',
          fontSize: 21,
          color: NouriColors.gold,
        ),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
      style: NouriText.dhikr,
    );
  }
}
