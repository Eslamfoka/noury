import '../../core/format/arabic_numerals.dart';

/// The daily wird: a rubʿ, roughly three pages of a standard mushaf.
const kDailyWirdPages = 3;

/// Pages in a standard (Madinah) mushaf.
const kDefaultKhatmaPages = 604;

/// Progress through a full khatma.
///
/// Nouri does not contain a mushaf — the user reads from his own, marks the
/// wird done, and this tracks the running total toward a khatma.
class KhatmaProgress {
  const KhatmaProgress({
    required this.pagesRead,
    required this.totalPages,
  });

  final int pagesRead;
  final int totalPages;

  double get fraction =>
      totalPages == 0 ? 0 : (pagesRead / totalPages).clamp(0.0, 1.0);

  bool get isComplete => pagesRead >= totalPages;

  String get percentLabel => toArabicDigits('${(fraction * 100).round()}٪');
}
