import '../../data/db/nouri_database.dart';
import 'challenge.dart';

/// The bundled challenges.
///
/// A definition is content, not data: it lives here where it can be read and
/// reviewed in a diff, and only the enrolment is written to the database. The
/// same reasoning as the athkar assets.

const kFortyDaysInMosque = ChallengeDef(
  id: 'forty-mosque',
  nameAr: 'أربعين يوم في المسجد',
  descriptionAr: 'الصلوات الخمس في المسجد، أربعين يوم ورا بعض',
  kind: ChallengeKind.prayerState,
  mode: ChallengeMode.streak,
  targetDays: 40,
  minState: PrayerState.mosque,
);

const kThirtyDaysInCongregation = ChallengeDef(
  id: 'thirty-congregation',
  nameAr: 'شهر جماعة',
  descriptionAr: 'كل الصلوات جماعة، في المسجد أو في البيت، تلاتين يوم',
  kind: ChallengeKind.prayerState,
  mode: ChallengeMode.streak,
  targetDays: 30,
  minState: PrayerState.congregation,
);

const kThirtyDaysOnTime = ChallengeDef(
  id: 'thirty-on-time',
  nameAr: 'الصلاة في وقتها',
  descriptionAr: 'الخمس صلوات في وقتها، تلاتين يوم',
  kind: ChallengeKind.prayerState,
  mode: ChallengeMode.streak,
  targetDays: 30,
  minState: PrayerState.onTime,
);

const kMorningAthkarForty = ChallengeDef(
  id: 'morning-athkar-40',
  nameAr: 'أذكار الصباح ٤٠ يوم',
  descriptionAr: 'تكمّل ورد الصباح أربعين يوم — مش لازم ورا بعض',
  kind: ChallengeKind.athkarType,
  mode: ChallengeMode.cumulative,
  targetDays: 40,
  athkarType: 'morning',
);

const kEveningAthkarForty = ChallengeDef(
  id: 'evening-athkar-40',
  nameAr: 'أذكار المساء ٤٠ يوم',
  descriptionAr: 'تكمّل ورد المساء أربعين يوم — مش لازم ورا بعض',
  kind: ChallengeKind.athkarType,
  mode: ChallengeMode.cumulative,
  targetDays: 40,
  athkarType: 'evening',
);

const kTasbeehThirtyDays = ChallengeDef(
  id: 'tasbeeh-100-30',
  nameAr: 'مية تسبيحة كل يوم',
  descriptionAr: 'مية تسبيحة في اليوم، تلاتين يوم',
  kind: ChallengeKind.tasbeehCount,
  mode: ChallengeMode.cumulative,
  targetDays: 30,
  minCount: 100,
);

const kWalkTwentyOneDays = ChallengeDef(
  id: 'walk-30-21',
  nameAr: 'مشي كل يوم',
  descriptionAr: 'تلاتين دقيقة مشي، واحد وعشرين يوم',
  kind: ChallengeKind.walkMinutes,
  mode: ChallengeMode.cumulative,
  targetDays: 21,
  minCount: 30,
);

const kChallenges = <ChallengeDef>[
  kFortyDaysInMosque,
  kThirtyDaysInCongregation,
  kThirtyDaysOnTime,
  kMorningAthkarForty,
  kEveningAthkarForty,
  kTasbeehThirtyDays,
  kWalkTwentyOneDays,
];

ChallengeDef? challengeById(String id) {
  for (final c in kChallenges) {
    if (c.id == id) return c;
  }
  return null;
}
