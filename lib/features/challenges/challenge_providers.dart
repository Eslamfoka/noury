import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import 'challenge.dart';
import 'challenge_catalogue.dart';
import 'challenge_evaluator.dart';

/// A challenge the user has joined, with its progress worked out.
class ActiveChallenge {
  const ActiveChallenge({
    required this.enrollmentId,
    required this.def,
    required this.startedOn,
    required this.progress,
  });

  final int enrollmentId;
  final ChallengeDef def;
  final DateTime startedOn;
  final ChallengeProgress progress;
}

/// Every joined challenge, evaluated against the logs.
///
/// The logs are read once and shared across all of them rather than per
/// challenge: a user with five challenges would otherwise run five identical
/// forty-day queries every time the reports tab is opened.
final activeChallengesProvider =
    FutureProvider<List<ActiveChallenge>>((ref) async {
  final db = ref.watch(databaseProvider);
  final enrolments = await db.challengeDao.active();
  if (enrolments.isEmpty) return const [];

  // Watched: a challenge counted to yesterday all night would have said «٣٩
  // يوم» on the fortieth morning.
  final today = ref.watch(currentDayProvider);
  var earliest = dayOf(today);
  for (final e in enrolments) {
    if (e.startedOn.isBefore(earliest)) earliest = dayOf(e.startedOn);
  }

  final prayers = await db.prayerDao.logsBetween(earliest, today);
  final athkar = await db.athkarDao.between(earliest, today);
  final walks = await db.stepsDao.between(earliest, today);

  final out = <ActiveChallenge>[];
  for (final e in enrolments) {
    final def = challengeById(e.challengeId);
    // An enrolment whose definition has since been removed is skipped rather
    // than crashing the whole tab.
    if (def == null) continue;

    out.add(ActiveChallenge(
      enrollmentId: e.id,
      def: def,
      startedOn: e.startedOn,
      progress: evaluate(
        def,
        startedOn: e.startedOn,
        today: today,
        prayers: prayers,
        athkar: athkar,
        walks: walks,
      ),
    ));
  }
  return out;
});

/// Challenges not currently joined — what the user can still take on.
final availableChallengesProvider =
    FutureProvider<List<ChallengeDef>>((ref) async {
  final active = await ref.watch(activeChallengesProvider.future);
  final joined = active.map((a) => a.def.id).toSet();
  return kChallenges.where((c) => !joined.contains(c.id)).toList();
});

class ChallengeController {
  ChallengeController(this._ref);
  final Ref _ref;

  Future<void> join(String challengeId) async {
    await _ref
        .read(databaseProvider)
        .challengeDao
        .enroll(challengeId: challengeId, startedOn: DateTime.now());
    _refresh();
  }

  Future<void> leave(int enrollmentId) async {
    await _ref.read(databaseProvider).challengeDao.abandon(enrollmentId);
    _refresh();
  }

  void _refresh() => _ref
    ..invalidate(activeChallengesProvider)
    ..invalidate(availableChallengesProvider);
}

final challengeControllerProvider =
    Provider<ChallengeController>(ChallengeController.new);
