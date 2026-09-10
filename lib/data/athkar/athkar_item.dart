import 'quran_passage.dart';

/// A single dhikr.
///
/// [source] is mandatory and always displayed. [virtue] is optional and ships
/// **only** where the wording is well-established — an unverified virtue is
/// stored as null and the UI hides the reveal entirely. A missing virtue is
/// correct; an invented one is a defect.
class AthkarItem {
  const AthkarItem({
    required this.id,
    required this.text,
    required this.count,
    required this.source,
    this.virtue,
    this.note,
    this.passage,
  });

  final String id;
  final String text;
  final int count;
  final String source;
  final String? virtue;
  final String? note;

  /// Present only on Qur'anic entries, and purely a rendering hint: the same
  /// words as [text], split at ayah boundaries so the card can typeset them
  /// like a mushaf page. A test asserts the split reproduces [text] exactly.
  final QuranPassage? passage;

  bool get isQuran => passage != null;

  bool get hasVirtue => virtue != null && virtue!.trim().isNotEmpty;

  factory AthkarItem.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final text = (j['text'] as String?)?.trim() ?? '';
    final count = j['count'] as int? ?? 0;
    final source = (j['source'] as String?)?.trim() ?? '';

    if (id.isEmpty) throw const FormatException('athkar entry has no id');
    if (text.isEmpty) throw FormatException('athkar entry $id has no text');
    if (count < 1) throw FormatException('athkar entry $id has count < 1');
    if (source.isEmpty) throw FormatException('athkar entry $id has no source');

    final virtue = (j['virtue'] as String?)?.trim();
    final note = (j['note'] as String?)?.trim();

    final quran = j['quran'] as Map<String, dynamic>?;
    final passage = quran == null ? null : QuranPassage.fromJson(quran);

    // Loud, never silent: a mushaf rendering that quietly disagreed with the
    // text it came from would be altering religious content on screen.
    if (passage != null && passage.reconstructedText != text) {
      throw FormatException(
        'athkar entry $id: the quran split does not reproduce its text',
      );
    }

    return AthkarItem(
      id: id,
      text: text,
      count: count,
      source: source,
      virtue: (virtue == null || virtue.isEmpty) ? null : virtue,
      note: (note == null || note.isEmpty) ? null : note,
      passage: passage,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'count': count,
        'source': source,
        'virtue': virtue,
        'note': note,
        if (passage != null) 'quran': passage!.toJson(),
      };
}

class AthkarSet {
  const AthkarSet({
    required this.version,
    required this.category,
    required this.items,
  });

  final int version;

  /// morning | evening | sleep | tasbeeh
  final String category;
  final List<AthkarItem> items;

  /// Total taps needed to finish the set — each dhikr counted [count] times.
  int get totalRepeats => items.fold(0, (a, i) => a + i.count);

  factory AthkarSet.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List)
        .map((e) => AthkarItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final ids = items.map((i) => i.id).toSet();
    if (ids.length != items.length) {
      throw FormatException('athkar set ${j['category']} has duplicate ids');
    }

    return AthkarSet(
      version: j['version'] as int,
      category: j['category'] as String,
      items: items,
    );
  }
}
