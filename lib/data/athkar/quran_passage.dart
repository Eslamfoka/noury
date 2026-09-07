import '../../core/format/arabic_numerals.dart';

/// A Qur'anic passage inside an athkar entry, split at its ayah boundaries.
///
/// Additive to the athkar JSON: an entry without a `quran` block renders
/// exactly as it always has. That matters because
/// `docs/athkar-verification.md` lists 45 athkar no human has yet checked
/// against a printed حصن المسلم, and this change must not invalidate that
/// review — so it provably cannot alter a single letter.
///
/// [reconstructedText] is what enforces that. It rebuilds the entry's original
/// `text` from the passage, and a test asserts exact equality for every entry
/// that has one. The split may only move where the ayah breaks fall; it can
/// never add, drop or reword anything.
class QuranPassage {
  const QuranPassage({
    required this.surahNameAr,
    required this.surahNumber,
    required this.ayat,
    this.bismillah = false,
    this.istiadha = false,
    this.ayahNumbers,
  });

  final String surahNameAr;
  final int surahNumber;

  /// The ayat, in order, without their numbers and without the Basmala.
  final List<String> ayat;

  /// Whether the Basmala opens the passage.
  ///
  /// A flag rather than an entry in [ayat], because in a mushaf it sits on its
  /// own line and carries no ayah number of its own.
  final bool bismillah;

  /// Whether الاستعاذة opens the passage.
  ///
  /// Not Qur'an, and not printed on a mushaf page — it is what the reader says
  /// before reciting. It is rendered above the frame rather than inside it.
  final bool istiadha;

  /// Real ayah numbers, when the passage is not a whole surah from its start.
  /// Null means 1…n.
  final List<int>? ayahNumbers;

  static const basmala = 'بِسْمِ اللهِ الرَّحْمَٰنِ الرَّحِيمِ.';
  static const istiadhaText = 'أَعُوذُ بِاللهِ مِنَ الشَّيْطَانِ الرَّجِيمِ.';

  int numberFor(int index) {
    final explicit = ayahNumbers;
    if (explicit != null && index < explicit.length) return explicit[index];
    return index + 1;
  }

  /// Whether this is a whole surah rather than an extract.
  bool get isWholeSurah => ayahNumbers == null;

  /// The entry's original `text`, rebuilt.
  ///
  /// The guard that makes the mushaf rendering safe. See the class comment.
  String get reconstructedText {
    final parts = <String>[
      if (istiadha) istiadhaText,
      if (bismillah) basmala,
      ayat.join('، '),
    ];
    return parts.join(' ');
  }

  factory QuranPassage.fromJson(Map<String, dynamic> j) {
    final surah = (j['surah'] as String?)?.trim() ?? '';
    if (surah.isEmpty) {
      throw const FormatException('quran block has no surah name');
    }

    final ayat = ((j['ayat'] as List?) ?? const [])
        .map((e) => (e as String).trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (ayat.isEmpty) {
      throw FormatException('quran block for $surah has no ayat');
    }

    final rawNumbers = j['ayahNumbers'] as List?;
    final numbers =
        rawNumbers?.map((e) => (e as num).toInt()).toList();
    if (numbers != null && numbers.length != ayat.length) {
      throw FormatException(
        'quran block for $surah has ${numbers.length} ayah numbers '
        'for ${ayat.length} ayat',
      );
    }

    return QuranPassage(
      surahNameAr: surah,
      surahNumber: (j['surahNumber'] as num?)?.toInt() ?? 0,
      ayat: ayat,
      bismillah: j['bismillah'] as bool? ?? false,
      istiadha: j['istiadha'] as bool? ?? false,
      ayahNumbers: numbers,
    );
  }

  Map<String, dynamic> toJson() => {
        'surah': surahNameAr,
        'surahNumber': surahNumber,
        'bismillah': bismillah,
        'istiadha': istiadha,
        'ayat': ayat,
        if (ayahNumbers != null) 'ayahNumbers': ayahNumbers,
      };
}

/// The end-of-ayah ornament as text: ۝ followed by the number.
///
/// U+06DD is the Arabic end-of-ayah mark. This form is used for the semantics
/// label and in tests; the card itself draws the ornament as a circled number
/// so it reads the same whatever the font does with U+06DD.
String ayahMarker(int n) => '۝${toArabicDigits('$n')}';
