import 'dart:ui' show Offset;

import 'exercise.dart';
import 'pose.dart';

/// The bundled exercises, drawn as pose keyframes.
///
/// Coordinates are in a unit box, (0,0) top-left. Front-facing poses put the
/// figure upright in the middle; the floor exercises are drawn side-on, facing
/// left, which is the only way a push-up reads as a push-up.
///
/// Every pose here is exercised by a test that checks it stays inside the box
/// and defines all thirteen joints — a stray coordinate would put a limb off
/// the edge of the card, and it is far easier to see in a test than on screen.
Pose _p(Map<Joint, Offset> j) => Pose(j);

// ------------------------------------------------------------ front-facing

const _standing = <Joint, Offset>{
  Joint.head: Offset(0.50, 0.11),
  Joint.neck: Offset(0.50, 0.20),
  Joint.shoulderL: Offset(0.41, 0.23),
  Joint.shoulderR: Offset(0.59, 0.23),
  Joint.elbowL: Offset(0.37, 0.36),
  Joint.elbowR: Offset(0.63, 0.36),
  Joint.handL: Offset(0.35, 0.49),
  Joint.handR: Offset(0.65, 0.49),
  Joint.hip: Offset(0.50, 0.53),
  Joint.kneeL: Offset(0.45, 0.73),
  Joint.kneeR: Offset(0.55, 0.73),
  Joint.footL: Offset(0.44, 0.92),
  Joint.footR: Offset(0.56, 0.92),
};

final _squatDown = _p(const {
  Joint.head: Offset(0.50, 0.25),
  Joint.neck: Offset(0.50, 0.34),
  Joint.shoulderL: Offset(0.41, 0.37),
  Joint.shoulderR: Offset(0.59, 0.37),
  // Arms come forward for balance, which is the cue as much as the picture.
  Joint.elbowL: Offset(0.34, 0.40),
  Joint.elbowR: Offset(0.66, 0.40),
  Joint.handL: Offset(0.30, 0.32),
  Joint.handR: Offset(0.70, 0.32),
  Joint.hip: Offset(0.50, 0.64),
  Joint.kneeL: Offset(0.40, 0.71),
  Joint.kneeR: Offset(0.60, 0.71),
  Joint.footL: Offset(0.43, 0.92),
  Joint.footR: Offset(0.57, 0.92),
});

final _jackOpen = _p(const {
  Joint.head: Offset(0.50, 0.11),
  Joint.neck: Offset(0.50, 0.20),
  Joint.shoulderL: Offset(0.41, 0.23),
  Joint.shoulderR: Offset(0.59, 0.23),
  Joint.elbowL: Offset(0.28, 0.14),
  Joint.elbowR: Offset(0.72, 0.14),
  Joint.handL: Offset(0.19, 0.05),
  Joint.handR: Offset(0.81, 0.05),
  Joint.hip: Offset(0.50, 0.53),
  Joint.kneeL: Offset(0.38, 0.72),
  Joint.kneeR: Offset(0.62, 0.72),
  Joint.footL: Offset(0.28, 0.91),
  Joint.footR: Offset(0.72, 0.91),
});

final _lungeDown = _p(const {
  Joint.head: Offset(0.50, 0.16),
  Joint.neck: Offset(0.50, 0.25),
  Joint.shoulderL: Offset(0.42, 0.28),
  Joint.shoulderR: Offset(0.58, 0.28),
  Joint.elbowL: Offset(0.39, 0.40),
  Joint.elbowR: Offset(0.61, 0.40),
  Joint.handL: Offset(0.38, 0.52),
  Joint.handR: Offset(0.62, 0.52),
  Joint.hip: Offset(0.50, 0.58),
  // Front knee forward and bent, back knee dropped toward the floor.
  Joint.kneeL: Offset(0.32, 0.74),
  Joint.kneeR: Offset(0.66, 0.82),
  Joint.footL: Offset(0.30, 0.92),
  Joint.footR: Offset(0.76, 0.90),
});

final _highKneeL = _p(const {
  Joint.head: Offset(0.50, 0.11),
  Joint.neck: Offset(0.50, 0.20),
  Joint.shoulderL: Offset(0.41, 0.23),
  Joint.shoulderR: Offset(0.59, 0.23),
  Joint.elbowL: Offset(0.34, 0.32),
  Joint.elbowR: Offset(0.66, 0.30),
  Joint.handL: Offset(0.38, 0.22),
  Joint.handR: Offset(0.62, 0.40),
  Joint.hip: Offset(0.50, 0.53),
  Joint.kneeL: Offset(0.42, 0.55),
  Joint.kneeR: Offset(0.56, 0.73),
  Joint.footL: Offset(0.40, 0.68),
  Joint.footR: Offset(0.57, 0.92),
});

final _highKneeR = _p(const {
  Joint.head: Offset(0.50, 0.11),
  Joint.neck: Offset(0.50, 0.20),
  Joint.shoulderL: Offset(0.41, 0.23),
  Joint.shoulderR: Offset(0.59, 0.23),
  Joint.elbowL: Offset(0.34, 0.30),
  Joint.elbowR: Offset(0.66, 0.32),
  Joint.handL: Offset(0.38, 0.40),
  Joint.handR: Offset(0.62, 0.22),
  Joint.hip: Offset(0.50, 0.53),
  Joint.kneeL: Offset(0.44, 0.73),
  Joint.kneeR: Offset(0.58, 0.55),
  Joint.footL: Offset(0.43, 0.92),
  Joint.footR: Offset(0.60, 0.68),
});

// ------------------------------------------------------------- side-facing

final _pushUpTop = _p(const {
  Joint.head: Offset(0.16, 0.40),
  Joint.neck: Offset(0.25, 0.43),
  Joint.shoulderL: Offset(0.29, 0.44),
  Joint.shoulderR: Offset(0.29, 0.47),
  Joint.elbowL: Offset(0.29, 0.59),
  Joint.elbowR: Offset(0.29, 0.62),
  Joint.handL: Offset(0.29, 0.75),
  Joint.handR: Offset(0.29, 0.78),
  Joint.hip: Offset(0.58, 0.50),
  Joint.kneeL: Offset(0.74, 0.57),
  Joint.kneeR: Offset(0.74, 0.60),
  Joint.footL: Offset(0.89, 0.64),
  Joint.footR: Offset(0.89, 0.67),
});

final _pushUpBottom = _p(const {
  Joint.head: Offset(0.16, 0.57),
  Joint.neck: Offset(0.25, 0.59),
  Joint.shoulderL: Offset(0.29, 0.61),
  Joint.shoulderR: Offset(0.29, 0.64),
  // Elbows track back along the ribs, not out to the sides.
  Joint.elbowL: Offset(0.20, 0.70),
  Joint.elbowR: Offset(0.20, 0.73),
  Joint.handL: Offset(0.29, 0.76),
  Joint.handR: Offset(0.29, 0.79),
  Joint.hip: Offset(0.58, 0.63),
  Joint.kneeL: Offset(0.74, 0.66),
  Joint.kneeR: Offset(0.74, 0.69),
  Joint.footL: Offset(0.89, 0.70),
  Joint.footR: Offset(0.89, 0.73),
});

final _plankHold = _p(const {
  Joint.head: Offset(0.16, 0.47),
  Joint.neck: Offset(0.25, 0.50),
  Joint.shoulderL: Offset(0.29, 0.51),
  Joint.shoulderR: Offset(0.29, 0.54),
  Joint.elbowL: Offset(0.27, 0.66),
  Joint.elbowR: Offset(0.27, 0.69),
  Joint.handL: Offset(0.17, 0.70),
  Joint.handR: Offset(0.17, 0.73),
  Joint.hip: Offset(0.58, 0.56),
  Joint.kneeL: Offset(0.74, 0.62),
  Joint.kneeR: Offset(0.74, 0.65),
  Joint.footL: Offset(0.89, 0.68),
  Joint.footR: Offset(0.89, 0.71),
});

/// The same hold, a breath deeper. A plank is static, and a figure frozen
/// solid reads as a broken animation rather than an isometric hold.
final _plankBreath = _p(const {
  Joint.head: Offset(0.16, 0.49),
  Joint.neck: Offset(0.25, 0.52),
  Joint.shoulderL: Offset(0.29, 0.53),
  Joint.shoulderR: Offset(0.29, 0.56),
  Joint.elbowL: Offset(0.27, 0.67),
  Joint.elbowR: Offset(0.27, 0.70),
  Joint.handL: Offset(0.17, 0.71),
  Joint.handR: Offset(0.17, 0.74),
  Joint.hip: Offset(0.58, 0.58),
  Joint.kneeL: Offset(0.74, 0.63),
  Joint.kneeR: Offset(0.74, 0.66),
  Joint.footL: Offset(0.89, 0.69),
  Joint.footR: Offset(0.89, 0.72),
});

final _crunchDown = _p(const {
  Joint.head: Offset(0.18, 0.60),
  Joint.neck: Offset(0.26, 0.62),
  Joint.shoulderL: Offset(0.30, 0.63),
  Joint.shoulderR: Offset(0.30, 0.66),
  Joint.elbowL: Offset(0.24, 0.55),
  Joint.elbowR: Offset(0.24, 0.58),
  Joint.handL: Offset(0.21, 0.62),
  Joint.handR: Offset(0.21, 0.65),
  Joint.hip: Offset(0.58, 0.70),
  Joint.kneeL: Offset(0.74, 0.55),
  Joint.kneeR: Offset(0.74, 0.58),
  Joint.footL: Offset(0.86, 0.72),
  Joint.footR: Offset(0.86, 0.75),
});

final _crunchUp = _p(const {
  Joint.head: Offset(0.31, 0.48),
  Joint.neck: Offset(0.36, 0.53),
  Joint.shoulderL: Offset(0.39, 0.55),
  Joint.shoulderR: Offset(0.39, 0.58),
  Joint.elbowL: Offset(0.34, 0.46),
  Joint.elbowR: Offset(0.34, 0.49),
  Joint.handL: Offset(0.32, 0.52),
  Joint.handR: Offset(0.32, 0.55),
  Joint.hip: Offset(0.58, 0.70),
  Joint.kneeL: Offset(0.74, 0.55),
  Joint.kneeR: Offset(0.74, 0.58),
  Joint.footL: Offset(0.86, 0.72),
  Joint.footR: Offset(0.86, 0.75),
});

final _bridgeDown = _p(const {
  Joint.head: Offset(0.16, 0.63),
  Joint.neck: Offset(0.25, 0.65),
  Joint.shoulderL: Offset(0.29, 0.66),
  Joint.shoulderR: Offset(0.29, 0.69),
  Joint.elbowL: Offset(0.36, 0.72),
  Joint.elbowR: Offset(0.36, 0.75),
  Joint.handL: Offset(0.44, 0.76),
  Joint.handR: Offset(0.44, 0.79),
  Joint.hip: Offset(0.58, 0.74),
  Joint.kneeL: Offset(0.75, 0.58),
  Joint.kneeR: Offset(0.75, 0.61),
  Joint.footL: Offset(0.86, 0.77),
  Joint.footR: Offset(0.86, 0.80),
});

final _bridgeUp = _p(const {
  Joint.head: Offset(0.16, 0.63),
  Joint.neck: Offset(0.25, 0.65),
  Joint.shoulderL: Offset(0.29, 0.66),
  Joint.shoulderR: Offset(0.29, 0.69),
  Joint.elbowL: Offset(0.36, 0.72),
  Joint.elbowR: Offset(0.36, 0.75),
  Joint.handL: Offset(0.44, 0.76),
  Joint.handR: Offset(0.44, 0.79),
  Joint.hip: Offset(0.58, 0.56),
  Joint.kneeL: Offset(0.75, 0.55),
  Joint.kneeR: Offset(0.75, 0.58),
  Joint.footL: Offset(0.86, 0.77),
  Joint.footR: Offset(0.86, 0.80),
});

// ------------------------------------------------------------- exercises

final kSquat = Exercise(
  id: 'squat',
  nameAr: 'سكوات',
  cueAr: 'ضهرك مفرود، وركبك ما تعديش صوابع رجليك.',
  keyframes: [_p(_standing), _squatDown],
  loopSeconds: 2.6,
);

final kPushUp = Exercise(
  id: 'push-up',
  nameAr: 'ضغط',
  cueAr: 'جسمك خط واحد من راسك لرجليك، وكوعك جنب ضلوعك.',
  keyframes: [_pushUpTop, _pushUpBottom],
  loopSeconds: 2.4,
);

final kJumpingJack = Exercise(
  id: 'jumping-jack',
  nameAr: 'قفز مفتوح',
  cueAr: 'نزّل على مشط رجلك، والركبة لينة مش مقفولة.',
  keyframes: [_p(_standing), _jackOpen],
  loopSeconds: 1.4,
);

final kPlank = Exercise(
  id: 'plank',
  nameAr: 'بلانك',
  cueAr: 'شدّ بطنك وما ترفعش وركك لفوق.',
  keyframes: [_plankHold, _plankBreath],
  loopSeconds: 3.6,
);

final kLunge = Exercise(
  id: 'lunge',
  nameAr: 'طعن',
  cueAr: 'الركبة الأمامية فوق كعبك، والخلفية تقرب من الأرض.',
  keyframes: [_p(_standing), _lungeDown],
  loopSeconds: 2.8,
);

final kCrunch = Exercise(
  id: 'crunch',
  nameAr: 'بطن',
  cueAr: 'ارفع بكتافك مش برقبتك، وما تشدّش راسك بإيدك.',
  keyframes: [_crunchDown, _crunchUp],
  loopSeconds: 2.2,
);

final kGluteBridge = Exercise(
  id: 'glute-bridge',
  nameAr: 'رفع الحوض',
  cueAr: 'اعصر مؤخرتك وانت طالع، وثبّت لحظة فوق.',
  keyframes: [_bridgeDown, _bridgeUp],
  loopSeconds: 2.6,
);

final kHighKnees = Exercise(
  id: 'high-knees',
  nameAr: 'ركب عالية',
  cueAr: 'ارفع ركبتك لحد مستوى وسطك، وخليك خفيف.',
  keyframes: [_highKneeL, _highKneeR],
  loopSeconds: 1.2,
);

/// Every exercise, for the tests that check them all.
final kAllExercises = <Exercise>[
  kSquat,
  kPushUp,
  kJumpingJack,
  kPlank,
  kLunge,
  kCrunch,
  kGluteBridge,
  kHighKnees,
];

// -------------------------------------------------------------- routines

final kWarmUp = Routine(
  id: 'warm-up',
  nameAr: 'إحماء',
  descriptionAr: 'خمس تمارين خفيفة قبل ما تبدأ',
  exercises: [kJumpingJack, kHighKnees, kSquat, kLunge, kGluteBridge],
  work: const Duration(seconds: 20),
  rest: const Duration(seconds: 15),
);

final kQuickHome = Routine(
  id: 'quick-home',
  nameAr: 'تمرين البيت السريع',
  descriptionAr: 'تمانية تمارين · ٣٠ ثانية شغل و٣٠ راحة',
  exercises: [
    kJumpingJack,
    kSquat,
    kPushUp,
    kPlank,
    kLunge,
    kCrunch,
    kGluteBridge,
    kHighKnees,
  ],
);

final kFullBody = Routine(
  id: 'full-body',
  nameAr: 'الجسم كامل',
  descriptionAr: 'عشرين تمرين · للي عايز يتعب',
  exercises: [
    kJumpingJack,
    kSquat,
    kPushUp,
    kPlank,
    kLunge,
    kCrunch,
    kGluteBridge,
    kHighKnees,
    kSquat,
    kPushUp,
    kJumpingJack,
    kPlank,
    kLunge,
    kCrunch,
    kGluteBridge,
    kHighKnees,
    kSquat,
    kPushUp,
    kPlank,
    kCrunch,
  ],
);

final kRoutines = <Routine>[kWarmUp, kQuickHome, kFullBody];

Routine? routineById(String id) {
  for (final r in kRoutines) {
    if (r.id == id) return r;
  }
  return null;
}
