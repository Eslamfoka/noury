import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

/// Kuwait is UTC+3 year-round with no DST. The test machine may sit in any
/// zone (this one is Egypt: +02:00 in winter, +03:00 in summer) and `adhan`
/// returns times in the *runner's* local zone — so asserting on a raw `.hour`
/// would make these tests pass in summer and fail in December.
/// Converting to Kuwait wall-clock first makes the assertions absolute.
const _kuwaitOffset = Duration(hours: 3);
DateTime kw(DateTime t) => t.toUtc().add(_kuwaitOffset);

void main() {
  const kuwait = GeoConfig(
    latitude: 29.3759,
    longitude: 47.9774,
    method: 'kuwait',
    madhab: 'shafi',
  );
  final service = PrayerTimesService();

  test('prayers are strictly ordered through the day', () {
    for (final d in [
      DateTime(2026, 1, 15),
      DateTime(2026, 6, 21),
      DateTime(2026, 12, 31),
    ]) {
      final t = service.forDate(d, kuwait);
      expect(t.fajr.isBefore(t.sunrise), isTrue, reason: '$d');
      expect(t.sunrise.isBefore(t.dhuhr), isTrue, reason: '$d');
      expect(t.dhuhr.isBefore(t.asr), isTrue, reason: '$d');
      expect(t.asr.isBefore(t.maghrib), isTrue, reason: '$d');
      expect(t.maghrib.isBefore(t.isha), isTrue, reason: '$d');
    }
  });

  test('every prayer falls on the requested calendar day in Kuwait', () {
    final d = DateTime(2026, 9, 5);
    final t = service.forDate(d, kuwait);
    for (final slot in t.ordered) {
      final local = kw(slot.time);
      expect(local.year, d.year, reason: slot.name);
      expect(local.month, d.month, reason: slot.name);
      expect(local.day, d.day, reason: slot.name);
    }
  });

  test('midsummer Kuwait times land in the expected windows', () {
    final t = service.forDate(DateTime(2026, 6, 21), kuwait);
    expect(kw(t.fajr).hour, inInclusiveRange(2, 4));
    expect(kw(t.dhuhr).hour, inInclusiveRange(11, 12));
    expect(kw(t.maghrib).hour, inInclusiveRange(18, 19));
    expect(kw(t.isha).hour, inInclusiveRange(19, 21));
  });

  test('midwinter Kuwait times shift later in the morning', () {
    final t = service.forDate(DateTime(2026, 12, 21), kuwait);
    expect(kw(t.fajr).hour, inInclusiveRange(4, 6));
    expect(kw(t.maghrib).hour, inInclusiveRange(16, 17));
  });

  test('the absolute instant does not depend on the runner timezone', () {
    // Guards the kw() approach itself: the underlying instant is fixed, only
    // its wall-clock rendering moves with the zone.
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    expect(t.dhuhr.toUtc().hour, inInclusiveRange(8, 9),
        reason: 'Kuwait dhuhr is around 11:47 local, which is 08:47 UTC');
  });

  test('next() returns the upcoming prayer, and null after isha', () {
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    expect(t.next(t.asr.subtract(const Duration(minutes: 1)))!.name, 'asr');
    expect(t.next(t.isha.add(const Duration(minutes: 1))), isNull);
  });

  test('ordered excludes sunrise — it is not a prayer to log', () {
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    expect(t.ordered.map((s) => s.name).toList(),
        ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']);
  });

  test('the hanafi madhab pushes asr later than shafi', () {
    const hanafi = GeoConfig(
      latitude: 29.3759,
      longitude: 47.9774,
      method: 'kuwait',
      madhab: 'hanafi',
    );
    final s = service.forDate(DateTime(2026, 9, 5), kuwait);
    final h = service.forDate(DateTime(2026, 9, 5), hanafi);
    expect(h.asr.isAfter(s.asr), isTrue,
        reason: 'hanafi uses double shadow length, so asr comes later');
  });

  test('an unknown calculation method falls back to Kuwait', () {
    const nonsense = GeoConfig(
      latitude: 29.3759,
      longitude: 47.9774,
      method: 'not-a-real-method',
      madhab: 'shafi',
    );
    expect(service.forDate(DateTime(2026, 9, 5), nonsense).fajr,
        service.forDate(DateTime(2026, 9, 5), kuwait).fajr);
  });

  test('iqama adds the configured offset per prayer', () {
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    const offsets = {
      'fajr': 20,
      'dhuhr': 15,
      'asr': 15,
      'maghrib': 10,
      'isha': 15,
    };
    final asr = t.ordered.firstWhere((s) => s.name == 'asr');
    expect(iqamaFor(asr, offsets).difference(asr.time),
        const Duration(minutes: 15));
    final maghrib = t.ordered.firstWhere((s) => s.name == 'maghrib');
    expect(iqamaFor(maghrib, offsets).difference(maghrib.time),
        const Duration(minutes: 10));
  });

  test('a prayer missing from the offsets map still gets a sane iqama', () {
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    final isha = t.ordered.firstWhere((s) => s.name == 'isha');
    expect(iqamaFor(isha, const {}).difference(isha.time),
        const Duration(minutes: 15));
  });
}
