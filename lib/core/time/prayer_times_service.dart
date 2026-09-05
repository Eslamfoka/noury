import 'package:adhan/adhan.dart' as adhan;

import 'geo_config.dart';

/// One prayer and the moment it enters.
class PrayerSlot {
  const PrayerSlot(this.name, this.time);

  /// fajr | dhuhr | asr | maghrib | isha
  final String name;
  final DateTime time;
}

class DailyPrayerTimes {
  const DailyPrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;

  /// The five prayers, in order.
  ///
  /// Sunrise is deliberately absent: it bounds fajr but is not a prayer the
  /// user logs, and putting it in this list would corrupt every count.
  List<PrayerSlot> get ordered => [
        PrayerSlot('fajr', fajr),
        PrayerSlot('dhuhr', dhuhr),
        PrayerSlot('asr', asr),
        PrayerSlot('maghrib', maghrib),
        PrayerSlot('isha', isha),
      ];

  /// The next prayer strictly after [now], or null once isha has passed.
  PrayerSlot? next(DateTime now) {
    for (final s in ordered) {
      if (s.time.isAfter(now)) return s;
    }
    return null;
  }
}

class PrayerTimesService {
  const PrayerTimesService();

  DailyPrayerTimes forDate(DateTime date, GeoConfig cfg) {
    final params = _method(cfg.method).getParameters()
      ..madhab =
          cfg.madhab == 'hanafi' ? adhan.Madhab.hanafi : adhan.Madhab.shafi;

    final t = adhan.PrayerTimes(
      adhan.Coordinates(cfg.latitude, cfg.longitude),
      adhan.DateComponents(date.year, date.month, date.day),
      params,
    );

    return DailyPrayerTimes(
      fajr: t.fajr,
      sunrise: t.sunrise,
      dhuhr: t.dhuhr,
      asr: t.asr,
      maghrib: t.maghrib,
      isha: t.isha,
    );
  }

  /// Unknown keys fall back to Kuwait rather than throwing — a corrupt setting
  /// must never leave the user without prayer times.
  adhan.CalculationMethod _method(String key) => switch (key) {
        'ummAlQura' => adhan.CalculationMethod.umm_al_qura,
        'muslimWorldLeague' => adhan.CalculationMethod.muslim_world_league,
        'egyptian' => adhan.CalculationMethod.egyptian,
        'qatar' => adhan.CalculationMethod.qatar,
        'dubai' => adhan.CalculationMethod.dubai,
        _ => adhan.CalculationMethod.kuwait,
      };
}

/// Iqama time for a prayer. Defaults to 15 minutes when the prayer is missing
/// from the map, so a malformed setting still produces a usable reminder.
DateTime iqamaFor(PrayerSlot slot, Map<String, int> offsetsMinutes) =>
    slot.time.add(Duration(minutes: offsetsMinutes[slot.name] ?? 15));
