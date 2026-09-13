/// The user's real duty pattern, taken from the brief rather than invented.
///
/// SCAFFOLDING — the shapes here come straight from §2 of the brief and are
/// unlikely to change, but nothing places tasks yet. The placement algorithm
/// is the part that still needs designing.
enum ShiftType { morning, evening, night, off }

extension ShiftTypeLabel on ShiftType {
  String get arabicLabel => switch (this) {
        ShiftType.morning => 'صباحي',
        ShiftType.evening => 'مسائي',
        ShiftType.night => 'ليلي',
        ShiftType.off => 'راحة',
      };
}

/// A time of day, independent of any date.
class Clock {
  const Clock(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutesFromMidnight => hour * 60 + minute;

  DateTime on(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is Clock && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// The fixed anchors of one duty day.
///
/// These are the immovable parts — work and commute — that everything else has
/// to fit around. Prayer times are the other fixed anchor and come from the
/// prayer engine, not from here.
class ShiftPattern {
  const ShiftPattern({
    required this.type,
    this.wake,
    this.leaveHome,
    this.workStart,
    this.workEnd,
    this.homeAgain,
    this.crossesMidnight = false,
  });

  final ShiftType type;
  final Clock? wake;
  final Clock? leaveHome;
  final Clock? workStart;
  final Clock? workEnd;
  final Clock? homeAgain;

  /// True for the night shift, whose work period runs into the next day.
  final bool crossesMidnight;

  bool get isWorking => type != ShiftType.off;

  // There is deliberately no `outboundCommute` here.
  //
  // The brief is explicit that the commute is usable time and that light tasks
  // belong in it — athkar, a lecture, the Qur'an wird by ear — and that is
  // built: `_windowsFor` opens a light-only window from `leaveHome` to
  // `workStart`, and two tests in `day_planner_test` hold it. A getter saying
  // the same thing a second way was never called by anything, and a second
  // place where "the commute is leaveHome→workStart" is written down is
  // exactly the drift that cost this project قيام and the budget note.

  static const morning = ShiftPattern(
    type: ShiftType.morning,
    wake: Clock(5, 0),
    leaveHome: Clock(6, 0),
    workStart: Clock(7, 0),
    workEnd: Clock(14, 0),
    homeAgain: Clock(15, 15),
  );

  static const evening = ShiftPattern(
    type: ShiftType.evening,
    wake: Clock(12, 0),
    leaveHome: Clock(13, 0),
    workStart: Clock(14, 0),
    workEnd: Clock(21, 0),
    homeAgain: Clock(22, 0),
  );

  /// Wake is computed backwards from the shift rather than fixed: the brief
  /// says sleep is the priority and the wake time follows from the next duty.
  static const night = ShiftPattern(
    type: ShiftType.night,
    workStart: Clock(22, 0),
    workEnd: Clock(7, 0),
    homeAgain: Clock(8, 0),
    crossesMidnight: true,
  );

  static const dayOff = ShiftPattern(type: ShiftType.off);

  /// A pattern from the user's own times.
  ///
  /// 13 September 2026: «عايز اختار وقت الدوام بيبدأ امتا وينتهي امتا مثلا
  /// الصبح من 7 am الي 2 pm وتحط ساعتين مواصلات ساعة قبل الدوام وساعة بعد
  /// يعني من 6 الي 3». Work from [workStart] to [workEnd]; the commute is
  /// [commuteBefore] ahead of it and [commuteAfter] behind; and the wake is
  /// an hour before leaving, which is what the brief's own numbers say
  /// (05:00 wake, 06:00 bus) and what every morning needs — fajr, athkar,
  /// breakfast, out of the door.
  ///
  /// The night shift keeps its shape: no fixed wake (sleep is sized from the
  /// next duty), and it crosses midnight whenever the end is not after the
  /// start. A day off ignores all of it.
  factory ShiftPattern.custom({
    required ShiftType type,
    required Clock workStart,
    required Clock workEnd,
    Duration commuteBefore = const Duration(hours: 1),
    Duration commuteAfter = const Duration(hours: 1),
  }) {
    if (type == ShiftType.off) return dayOff;

    final crosses = workEnd.minutesFromMidnight <= workStart.minutesFromMidnight;
    final leave = _shift(workStart, -commuteBefore.inMinutes);
    final home = _shift(workEnd, commuteAfter.inMinutes);

    if (type == ShiftType.night || crosses) {
      return ShiftPattern(
        type: ShiftType.night,
        workStart: workStart,
        workEnd: workEnd,
        homeAgain: home,
        crossesMidnight: true,
      );
    }

    return ShiftPattern(
      type: type,
      wake: _shift(leave, -60),
      leaveHome: leave,
      workStart: workStart,
      workEnd: workEnd,
      homeAgain: home,
    );
  }

  /// A clock moved by [minutes], wrapping within the day.
  static Clock _shift(Clock c, int minutes) {
    final total = ((c.minutesFromMidnight + minutes) % 1440 + 1440) % 1440;
    return Clock(total ~/ 60, total % 60);
  }

  /// The brief's default hours for one type — what a fresh install has and
  /// what the settings screen shows until the user changes them.
  static (Clock, Clock)? defaultHours(ShiftType type) => switch (type) {
        ShiftType.morning => (const Clock(7, 0), const Clock(14, 0)),
        ShiftType.evening => (const Clock(14, 0), const Clock(21, 0)),
        ShiftType.night => (const Clock(22, 0), const Clock(7, 0)),
        ShiftType.off => null,
      };

  /// Parses the stored settings value, falling back to the morning shift.
  ///
  /// Falls back rather than throwing: an unrecognised value should give the
  /// user a plausible day, not an error screen where their day should be.
  static ShiftPattern fromName(String name) => switch (name) {
        'evening' => evening,
        'night' => night,
        'off' => dayOff,
        _ => morning,
      };

  static ShiftPattern forType(ShiftType type) => switch (type) {
        ShiftType.morning => morning,
        ShiftType.evening => evening,
        ShiftType.night => night,
        ShiftType.off => dayOff,
      };
}
