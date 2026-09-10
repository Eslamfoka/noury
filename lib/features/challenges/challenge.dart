import '../../data/db/nouri_database.dart';

/// What a challenge measures.
///
/// Stored nowhere — a challenge's definition lives in the bundled catalogue,
/// and only the enrolment is written to the database. So this enum is free to
/// change, unlike the ones in `tables.dart`.
enum ChallengeKind { prayerState, athkarType, tasbeehCount, walkMinutes }

/// How the days add up.
///
/// [streak] resets after a missed day; [cumulative] does not. The forty days in
/// the mosque is a streak because that is what the challenge actually is — a
/// fact about the challenge, not a punishment Nouri invented. Everything
/// around it stays encouraging: a broken streak is «ابدأ من تاني», never a
/// failure notice, and never red.
enum ChallengeMode { streak, cumulative }

class ChallengeDef {
  const ChallengeDef({
    required this.id,
    required this.nameAr,
    required this.descriptionAr,
    required this.kind,
    required this.mode,
    required this.targetDays,
    this.minState,
    this.athkarType,
    this.minCount,
  });

  final String id;
  final String nameAr;
  final String descriptionAr;
  final ChallengeKind kind;
  final ChallengeMode mode;
  final int targetDays;

  /// For [ChallengeKind.prayerState]: the least good state that still counts.
  /// All five prayers must reach it for the day to count.
  final PrayerState? minState;

  /// For [ChallengeKind.athkarType]: which set — morning, evening, sleep.
  final String? athkarType;

  /// For [ChallengeKind.tasbeehCount], the tasbeeh count; for
  /// [ChallengeKind.walkMinutes], the minutes.
  final int? minCount;
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.daysDone,
    required this.targetDays,
    required this.currentStreak,
    required this.bestStreak,
    required this.completedToday,
    required this.qualifyingDays,
  });

  final int daysDone;
  final int targetDays;
  final int currentStreak;
  final int bestStreak;

  /// Whether today already counts. Used to say «النهاردة تمام» without
  /// implying anything about a day that is not over yet.
  final bool completedToday;

  /// Every day that counted, for a calendar strip.
  final List<DateTime> qualifyingDays;

  double get fraction =>
      targetDays == 0 ? 0 : (daysDone / targetDays).clamp(0.0, 1.0);

  int get remaining => (targetDays - daysDone).clamp(0, targetDays);

  bool get isComplete => daysDone >= targetDays;
}
