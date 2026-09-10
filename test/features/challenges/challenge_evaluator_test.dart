import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/challenges/challenge.dart';
import 'package:nouri/features/challenges/challenge_catalogue.dart';
import 'package:nouri/features/challenges/challenge_evaluator.dart';

/// Five prayers logged on [day], all at [state].
List<PrayerLog> fiveOn(DateTime day, PrayerState state) => [
      for (final name in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
        PrayerLog(
          id: day.day * 10 + name.hashCode % 10,
          date: DateTime(day.year, day.month, day.day),
          prayer: name,
          scheduledTime: DateTime(day.year, day.month, day.day, 12),
          state: state,
          score: state.score,
          loggedAt: DateTime(day.year, day.month, day.day, 12),
        ),
    ];

AthkarLog athkarOn(
  DateTime day, {
  required String type,
  int progress = 1,
  int target = 1,
  bool completed = true,
}) =>
    AthkarLog(
      id: day.day,
      date: DateTime(day.year, day.month, day.day),
      type: type,
      progressCount: progress,
      targetCount: target,
      completedAt: completed ? DateTime(day.year, day.month, day.day) : null,
    );

WalkSession walkOn(DateTime day, {required int minutes}) => WalkSession(
      id: day.day,
      startedAt: DateTime(day.year, day.month, day.day, 18),
      seconds: minutes * 60,
      steps: minutes * 110,
      metres: minutes * 80,
      kcal: minutes * 4,
      targetMinutes: minutes,
    );

void main() {
  DateTime sept(int d) => DateTime(2026, 9, d);

  group('a day of prayers', () {
    test('counts only when all five meet the bar', () {
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(1),
        today: sept(2),
        prayers: fiveOn(sept(1), PrayerState.mosque),
      );
      expect(p.daysDone, 1);
    });

    test('four of five is not a day', () {
      final logs = fiveOn(sept(1), PrayerState.mosque)..removeLast();
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(1),
        today: sept(2),
        prayers: logs,
      );
      expect(p.daysDone, 0);
    });

    test('congregation at home does not satisfy a mosque challenge', () {
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(1),
        today: sept(2),
        prayers: fiveOn(sept(1), PrayerState.congregation),
      );
      expect(p.daysDone, 0);
    });

    test('the mosque exceeds a congregation bar', () {
      // Better than the bar always counts.
      final p = evaluate(
        kThirtyDaysInCongregation,
        startedOn: sept(1),
        today: sept(2),
        prayers: fiveOn(sept(1), PrayerState.mosque),
      );
      expect(p.daysDone, 1);
    });

    test('late does not satisfy an on-time challenge', () {
      final p = evaluate(
        kThirtyDaysOnTime,
        startedOn: sept(1),
        today: sept(2),
        prayers: fiveOn(sept(1), PrayerState.late_),
      );
      expect(p.daysDone, 0);
    });
  });

  group('streaks', () {
    test('restart after a gap, and remember the best', () {
      // 1-3 kept, 4 missed, 5-6 kept, evaluated on the 7th.
      final prayers = [
        for (final d in [1, 2, 3, 5, 6])
          ...fiveOn(sept(d), PrayerState.mosque),
      ];
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(1),
        today: sept(7),
        prayers: prayers,
      );
      // The 4th broke the run, so the best is the 1st-3rd. The current run is
      // the 5th and 6th: the 7th has nothing logged yet, and today is never
      // counted against the user, so it neither extends nor breaks it.
      expect(p.currentStreak, 2);
      expect(p.bestStreak, 3);
      expect(p.completedToday, isFalse);
    });

    test('a run ending yesterday is still the current streak', () {
      final prayers = [
        for (final d in [4, 5, 6]) ...fiveOn(sept(d), PrayerState.mosque),
      ];
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(4),
        today: sept(7),
        prayers: prayers,
      );
      expect(p.currentStreak, 3);
      expect(p.daysDone, 3);
    });

    test('today is never counted against the user before it ends', () {
      // An unlogged today must not break a streak at 09:00.
      final prayers = [
        for (final d in [1, 2, 3]) ...fiveOn(sept(d), PrayerState.mosque),
      ];
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(1),
        today: sept(4),
        prayers: prayers,
      );
      expect(p.currentStreak, 3);
      expect(p.completedToday, isFalse);
    });

    test('today counts as soon as it qualifies', () {
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(1),
        today: sept(1),
        prayers: fiveOn(sept(1), PrayerState.mosque),
      );
      expect(p.completedToday, isTrue);
      expect(p.currentStreak, 1);
    });

    test('a gap two days ago still breaks the streak', () {
      // The exemption is for today only. A day that is over and was missed
      // is a fact, and the challenge says what it says.
      final prayers = [
        ...fiveOn(sept(1), PrayerState.mosque),
        ...fiveOn(sept(3), PrayerState.mosque),
      ];
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(1),
        today: sept(4),
        prayers: prayers,
      );
      expect(p.currentStreak, 1);
      expect(p.bestStreak, 1);
    });
  });

  group('cumulative', () {
    test('does not restart after a gap', () {
      final athkar = [
        for (final d in [1, 2, 3, 5, 6])
          athkarOn(sept(d), type: 'morning'),
      ];
      final p = evaluate(
        kMorningAthkarForty,
        startedOn: sept(1),
        today: sept(7),
        athkar: athkar,
      );
      expect(p.daysDone, 5);
      expect(p.fraction, closeTo(5 / 40, 1e-9));
    });

    test('an unfinished set does not count', () {
      final p = evaluate(
        kMorningAthkarForty,
        startedOn: sept(1),
        today: sept(2),
        athkar: [
          athkarOn(sept(1),
              type: 'morning', progress: 3, target: 17, completed: false),
        ],
      );
      expect(p.daysDone, 0);
    });

    test('the wrong athkar set does not count', () {
      final p = evaluate(
        kMorningAthkarForty,
        startedOn: sept(1),
        today: sept(2),
        athkar: [athkarOn(sept(1), type: 'evening')],
      );
      expect(p.daysDone, 0);
    });

    test('a dhikr challenge counts a day at the tasbeeh target', () {
      final p = evaluate(
        kTasbeehThirtyDays,
        startedOn: sept(1),
        today: sept(3),
        athkar: [
          athkarOn(sept(1), type: 'tasbeeh', progress: 100, target: 100),
          athkarOn(sept(2), type: 'tasbeeh', progress: 40, target: 100),
        ],
      );
      expect(p.daysDone, 1, reason: 'forty is short of the hundred');
    });

    test('walking counts when the minutes add up across sessions', () {
      final p = evaluate(
        kWalkTwentyOneDays,
        startedOn: sept(1),
        today: sept(3),
        walks: [
          walkOn(sept(1), minutes: 20),
          walkOn(sept(1), minutes: 15),
          walkOn(sept(2), minutes: 12),
        ],
      );
      expect(p.daysDone, 1, reason: '35 minutes on the 1st, 12 on the 2nd');
    });
  });

  group('boundaries', () {
    test('days before enrolment do not count', () {
      // Joining today does not retroactively award last week.
      final prayers = [
        for (final d in [1, 2, 3, 4, 5])
          ...fiveOn(sept(d), PrayerState.mosque),
      ];
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(4),
        today: sept(6),
        prayers: prayers,
      );
      expect(p.daysDone, 2);
    });

    test('progress never exceeds the target', () {
      final athkar = [
        for (var d = 1; d <= 28; d++) athkarOn(DateTime(2026, 9, d), type: 'morning'),
      ];
      final short = ChallengeDef(
        id: 'short',
        nameAr: 'قصير',
        descriptionAr: '',
        kind: ChallengeKind.athkarType,
        mode: ChallengeMode.cumulative,
        targetDays: 5,
        athkarType: 'morning',
      );
      final p = evaluate(short,
          startedOn: sept(1), today: sept(28), athkar: athkar);
      expect(p.daysDone, 5);
      expect(p.fraction, 1.0);
      expect(p.remaining, 0);
      expect(p.isComplete, isTrue);
    });

    test('an empty log is zero rather than a crash', () {
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(1),
        today: sept(20),
      );
      expect(p.daysDone, 0);
      expect(p.currentStreak, 0);
      expect(p.bestStreak, 0);
      expect(p.fraction, 0);
      expect(p.remaining, 40);
    });

    test('enrolling in the future yields nothing rather than looping', () {
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: sept(20),
        today: sept(1),
      );
      expect(p.daysDone, 0);
      expect(p.qualifyingDays, isEmpty);
    });

    test('a timestamped enrolment is still a whole day', () {
      final p = evaluate(
        kFortyDaysInMosque,
        startedOn: DateTime(2026, 9, 1, 22, 40),
        today: DateTime(2026, 9, 2, 6, 10),
        prayers: fiveOn(sept(1), PrayerState.mosque),
      );
      expect(p.daysDone, 1);
    });
  });

  group('the catalogue', () {
    test('every challenge is complete and uniquely identified', () {
      final ids = kChallenges.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final c in kChallenges) {
        expect(c.nameAr.trim(), isNotEmpty, reason: c.id);
        expect(c.descriptionAr.trim(), isNotEmpty, reason: c.id);
        expect(c.targetDays, greaterThan(0), reason: c.id);
      }
    });

    test('every kind carries the field it needs', () {
      for (final c in kChallenges) {
        switch (c.kind) {
          case ChallengeKind.prayerState:
            expect(c.minState, isNotNull, reason: c.id);
          case ChallengeKind.athkarType:
            expect(c.athkarType, isNotNull, reason: c.id);
          case ChallengeKind.tasbeehCount:
          case ChallengeKind.walkMinutes:
            expect(c.minCount, isNotNull, reason: c.id);
        }
      }
    });

    test('a challenge can be found by id', () {
      expect(challengeById('forty-mosque')?.targetDays, 40);
      expect(challengeById('nope'), isNull);
    });
  });
}
