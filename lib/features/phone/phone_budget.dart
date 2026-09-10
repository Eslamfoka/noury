import '../../core/format/arabic_numerals.dart';

/// Where the day stands against the cap.
///
/// Three states, none of which is a failure. `over` is a fact about a number,
/// not a verdict about a person — nothing in Nouri is ever marked failed and
/// nothing is ever red.
enum PhoneBudgetState {
  /// Comfortably inside.
  within,

  /// Most of the way through the cap.
  close,

  /// Past it.
  over,
}

/// The daily cap on phone and social time, and what to say about it.
///
/// §5.5: "Phone/social time: Nouri reserves a fixed slot and notifies if
/// exceeded (the user wants a hard-ish cap here)."
///
/// **The time is the user's word, not a measurement.** Reading real usage
/// needs PACKAGE_USAGE_STATS, a special-access permission granted through a
/// system settings page, and it would make Nouri infer where every other
/// pillar asks — a fasting day is the user's word, a prayer is logged rather
/// than detected. So the user starts the slot and Nouri times it. A
/// usage-stats source could replace the writer later without changing
/// anything here.
///
/// "Hard-ish" is honoured by *saying*, never by blocking. Nouri cannot stop
/// anyone using their phone and should not pretend to.
class PhoneBudget {
  const PhoneBudget({required this.cap});

  final Duration cap;

  /// The fraction of the cap used, clamped so a long day does not overflow a
  /// progress bar.
  double fractionOf(Duration spent) => cap.inMinutes == 0
      ? 0
      : (spent.inMinutes / cap.inMinutes).clamp(0.0, 1.0);

  PhoneBudgetState stateFor(Duration spent) {
    if (spent > cap) return PhoneBudgetState.over;
    if (cap.inMinutes > 0 && spent.inMinutes >= cap.inMinutes * 0.8) {
      return PhoneBudgetState.close;
    }
    return PhoneBudgetState.within;
  }

  /// The bare counter, for the corner of a card.
  ///
  /// «من», never a slash: «٩٠ / ٦٠» lays out right-to-left and says sixty of
  /// ninety. Held app-wide by counter_form_test.
  ///
  /// Short on purpose. A sentence here overflowed the card's header row by 32
  /// pixels at 90 minutes — caught by a widget test, which is where the
  /// sentence belongs instead.
  String counterFor(Duration spent) =>
      toArabicDigits('${spent.inMinutes} من ${cap.inMinutes}');

  /// One line about where the day stands.
  ///
  /// States the number and stops. No verb of blame anywhere: the tone tests
  /// assert none of فاتتك / ضيعت / فشل / كسلان / مدمن appears, and the whole
  /// point of the cap is to be useful information rather than a telling-off.
  String noteFor(Duration spent) {
    final capMins = toArabicDigits('${cap.inMinutes}');
    return switch (stateFor(spent)) {
      PhoneBudgetState.within => 'الحد اليومي $capMins دقيقة. سجّل قعدتك.',
      PhoneBudgetState.close => 'قربت من حد النهاردة، $capMins دقيقة.',
      PhoneBudgetState.over => 'عدّيت حد النهاردة. بكرة يوم جديد.',
    };
  }
}
