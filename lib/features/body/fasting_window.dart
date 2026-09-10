/// The 16/8 intermittent fasting window.
///
/// The brief's base system for resting the stomach. Eight hours in which
/// eating is planned, sixteen in which it is not.
///
/// Nouri states where you are in the cycle. It never scores the day, and it
/// never tells anyone to keep fasting — the point is to calm the stomach, and
/// a tool that pushes past discomfort would do the opposite.
library;

enum FastingPhase {
  /// Inside the eating window.
  eating,

  /// Outside it.
  fasting,
}

extension FastingPhaseLabel on FastingPhase {
  String get arabicLabel => switch (this) {
        FastingPhase.eating => 'وقت الأكل',
        FastingPhase.fasting => 'وقت الراحة',
      };
}

/// Where [now] falls in an eating window that opens at [startHour].
///
/// The window is eight hours long and can cross midnight — a 20:00 start runs
/// to 04:00, which is an ordinary shape for someone working nights.
class FastingWindow {
  const FastingWindow._({
    required this.opens,
    required this.closes,
    required this.phase,
    required this.now,
  });

  /// Builds the window containing or next following [now].
  ///
  /// Dates are constructed rather than offset. `add(Duration(hours: 8))` is
  /// eight *absolute* hours, which is not eight wall-clock hours across a DST
  /// change — the same class of bug that moved the adhan and broke the pay
  /// cycle.
  factory FastingWindow.at(
    DateTime now, {
    int startHour = 12,
    int lengthHours = 8,
  }) {
    final todayOpens = DateTime(now.year, now.month, now.day, startHour);
    final todayCloses = _addHours(todayOpens, lengthHours);

    // A window that started yesterday can still be open, if it crosses
    // midnight and `now` is on the far side of it.
    final yesterdayOpens =
        DateTime(now.year, now.month, now.day - 1, startHour);
    final yesterdayCloses = _addHours(yesterdayOpens, lengthHours);

    if (!now.isBefore(yesterdayOpens) && now.isBefore(yesterdayCloses)) {
      return FastingWindow._(
        opens: yesterdayOpens,
        closes: yesterdayCloses,
        phase: FastingPhase.eating,
        now: now,
      );
    }

    if (!now.isBefore(todayOpens) && now.isBefore(todayCloses)) {
      return FastingWindow._(
        opens: todayOpens,
        closes: todayCloses,
        phase: FastingPhase.eating,
        now: now,
      );
    }

    // Fasting. Report the window we are heading towards.
    final nextOpens = now.isBefore(todayOpens)
        ? todayOpens
        : DateTime(now.year, now.month, now.day + 1, startHour);

    return FastingWindow._(
      opens: nextOpens,
      closes: _addHours(nextOpens, lengthHours),
      phase: FastingPhase.fasting,
      now: now,
    );
  }

  /// Adds wall-clock hours by construction, so a DST shift moves the clock
  /// time rather than silently sliding the window.
  static DateTime _addHours(DateTime from, int hours) =>
      DateTime(from.year, from.month, from.day, from.hour + hours,
          from.minute);

  final DateTime opens;
  final DateTime closes;
  final FastingPhase phase;
  final DateTime now;

  bool get isEating => phase == FastingPhase.eating;

  /// How long until the phase changes.
  ///
  /// While eating, time until the window closes. While fasting, time until it
  /// opens again.
  Duration get remaining =>
      isEating ? closes.difference(now) : opens.difference(now);
}
