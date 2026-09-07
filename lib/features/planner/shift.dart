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

  /// Commute time is usable: the brief is explicit that light tasks belong
  /// here — athkar, a lecture, the Qur'an wird by ear.
  Duration? get outboundCommute {
    if (leaveHome == null || workStart == null) return null;
    return Duration(
      minutes: workStart!.minutesFromMidnight - leaveHome!.minutesFromMidnight,
    );
  }

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
