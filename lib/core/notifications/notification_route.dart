/// Where a tapped notification should take the user.
///
/// Parsing is kept separate from acting on it so the mapping can be tested
/// without a platform channel, a navigator, or a database. Payload strings are
/// written by the scheduler and read back by a different process after a
/// reboot, so they are a small wire format — worth treating as one.
sealed class NotificationRoute {
  const NotificationRoute();

  /// Parses a scheduler payload. Returns null for anything unrecognised,
  /// including null and empty strings.
  ///
  /// Unknown payloads must never throw. An old alarm scheduled by a previous
  /// version of the app can still be sitting in AlarmManager days later, and
  /// crashing on tap would be a poor thanks for upgrading.
  static NotificationRoute? parse(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    final i = payload.indexOf(':');
    final head = i == -1 ? payload : payload.substring(0, i);
    final rest = i == -1 ? '' : payload.substring(i + 1);

    return switch (head) {
      'log' when rest.isNotEmpty => LogPrayerRoute(rest),
      'prayer' when rest.isNotEmpty => PrayerRoute(rest),
      'review' when rest == 'daily' => const DailyReviewRoute(),
      'athkar' when rest.isNotEmpty => AthkarRoute(rest),
      'quran' => const QuranRoute(),
      'reminder' when int.tryParse(rest) != null =>
        ReminderRoute(int.parse(rest)),
      'fasting' => const FastingRoute(),
      _ => null,
    };
  }
}

/// Open the log sheet for one prayer — the follow-up asks.
class LogPrayerRoute extends NotificationRoute {
  const LogPrayerRoute(this.prayer);
  final String prayer;

  @override
  bool operator ==(Object other) =>
      other is LogPrayerRoute && other.prayer == prayer;
  @override
  int get hashCode => Object.hash('log', prayer);
}

/// Open Home, focused on a prayer — the adhan and iqama.
class PrayerRoute extends NotificationRoute {
  const PrayerRoute(this.prayer);
  final String prayer;

  @override
  bool operator ==(Object other) =>
      other is PrayerRoute && other.prayer == prayer;
  @override
  int get hashCode => Object.hash('prayer', prayer);
}

/// Open the end-of-day review.
class DailyReviewRoute extends NotificationRoute {
  const DailyReviewRoute();

  @override
  bool operator ==(Object other) => other is DailyReviewRoute;
  @override
  int get hashCode => 'review:daily'.hashCode;
}

class AthkarRoute extends NotificationRoute {
  const AthkarRoute(this.kind);
  final String kind;

  @override
  bool operator ==(Object other) =>
      other is AthkarRoute && other.kind == kind;
  @override
  int get hashCode => Object.hash('athkar', kind);
}

class QuranRoute extends NotificationRoute {
  const QuranRoute();

  @override
  bool operator ==(Object other) => other is QuranRoute;
  @override
  int get hashCode => 'quran'.hashCode;
}

/// Open the calendar on the day a reminder falls.
///
/// Carries the row id rather than the date: the reminder may have been edited
/// to another day between the alarm being armed and the user tapping it, and
/// the row is the thing that is still true.
class ReminderRoute extends NotificationRoute {
  const ReminderRoute(this.id);
  final int id;

  @override
  bool operator ==(Object other) => other is ReminderRoute && other.id == id;
  @override
  int get hashCode => Object.hash('reminder', id);
}

/// Open البدن, where fasting lives — the brief puts it in the physical pillar.
class FastingRoute extends NotificationRoute {
  const FastingRoute();

  @override
  bool operator ==(Object other) => other is FastingRoute;
  @override
  int get hashCode => 'fasting'.hashCode;
}
