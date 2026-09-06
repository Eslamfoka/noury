import '../time/prayer_times_service.dart';

/// When Nouri asks "how did you pray?", and how many times.
///
/// The old behaviour asked once, a fixed 25 minutes after the adhan — which
/// on a 15-minute iqama offset lands ten minutes after the congregation
/// starts, while the user may still be praying or walking home. Miss that one
/// notification and Nouri never asked again, which contradicts the brief's own
/// requirement that it adapt to the user's real day rather than assume he is
/// free at adhan time.
class FollowUpPolicy {
  const FollowUpPolicy({
    this.prayerDuration = const Duration(minutes: 10),
    this.buffer = const Duration(minutes: 10),
    this.secondAskAfter = const Duration(minutes: 60),
    this.nextAdhanGuard = const Duration(minutes: 15),
    this.minimumRoomForSecondAsk = const Duration(minutes: 20),
  });

  /// How long the prayer itself plausibly takes, congregation included.
  final Duration prayerDuration;

  /// Grace on top, so the question never arrives mid-prayer.
  final Duration buffer;

  /// Gap between the first and second ask, when the first goes unanswered.
  final Duration secondAskAfter;

  /// The second ask stops this far short of the next adhan, so the two never
  /// arrive together.
  final Duration nextAdhanGuard;

  /// If the cap leaves less room than this, the second ask is dropped rather
  /// than squeezed in. Maghrib to isha is often only ~75 minutes.
  final Duration minimumRoomForSecondAsk;
}

/// The times at which Nouri will ask about one prayer.
class FollowUpTimes {
  const FollowUpTimes({required this.first, this.second});

  final DateTime first;

  /// Null when the prayers are too close together to fit a second ask.
  final DateTime? second;

  List<DateTime> get all => [first, ?second];
}

/// Works out when to ask about [slot].
///
/// [iqama] is the configured iqama time for this prayer; [nextAdhan] is the
/// following prayer's adhan, or the day's cut-off for isha.
FollowUpTimes followUpsFor({
  required PrayerSlot slot,
  required DateTime iqama,
  required DateTime? nextAdhan,
  FollowUpPolicy policy = const FollowUpPolicy(),
}) {
  final first = iqama.add(policy.prayerDuration).add(policy.buffer);

  if (nextAdhan == null) {
    return FollowUpTimes(first: first, second: first.add(policy.secondAskAfter));
  }

  final latest = nextAdhan.subtract(policy.nextAdhanGuard);
  final wanted = first.add(policy.secondAskAfter);
  final second = wanted.isBefore(latest) ? wanted : latest;

  // Only worth a second ask if it lands meaningfully after the first.
  final room = second.difference(first);
  if (room < policy.minimumRoomForSecondAsk) {
    return FollowUpTimes(first: first);
  }

  return FollowUpTimes(first: first, second: second);
}
