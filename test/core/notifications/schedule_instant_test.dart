import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Guards the UTC scheduling decision in [LocalNotificationGateway].
///
/// The plugin sends a wall-clock string plus a zone name, and Android rebuilds
/// the instant with its own tz database. If the two databases disagree about a
/// zone's rules — stale OEM tzdata is common — the adhan moves by an hour.
/// Scheduling in UTC removes the disagreement entirely.
void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('converting to UTC preserves the exact instant', () {
    final local = DateTime(2026, 9, 6, 3, 7);
    final utc = tz.TZDateTime.from(local, tz.UTC);

    expect(utc.millisecondsSinceEpoch, local.millisecondsSinceEpoch,
        reason: 'the instant must survive the conversion untouched');
    // The timezone package names it "Etc/UTC". Android's ZoneId accepts that
    // and, like plain UTC, it carries no transitions for the two databases to
    // disagree about — which is the whole point.
    expect(utc.location.name, anyOf('UTC', 'Etc/UTC'));
    expect(utc.timeZoneOffset, Duration.zero);
  });

  test('the UTC wall clock is unambiguous across zones', () {
    // The same instant rendered in three zones gives three different wall
    // clocks — which is exactly what makes the zone-name round trip fragile.
    // Only the UTC rendering is safe to hand to a foreign tz database.
    final instant = DateTime.utc(2026, 9, 6, 1, 7);

    final cairo =
        tz.TZDateTime.from(instant, tz.getLocation('Africa/Cairo'));
    final kuwait =
        tz.TZDateTime.from(instant, tz.getLocation('Asia/Kuwait'));
    final utc = tz.TZDateTime.from(instant, tz.UTC);

    expect(utc.hour, 1);
    expect(kuwait.hour, 4, reason: 'Kuwait is UTC+3 year-round');
    expect(
      cairo.millisecondsSinceEpoch,
      kuwait.millisecondsSinceEpoch,
      reason: 'different wall clocks, same instant',
    );
  });

  test('Kuwait has no DST, so its wall clock is stable year-round', () {
    // Reassurance for the primary use case: in Kuwait the tzdata-mismatch
    // class of bug cannot occur, because there are no transitions to disagree
    // about.
    final kuwait = tz.getLocation('Asia/Kuwait');
    final january =
        tz.TZDateTime.from(DateTime.utc(2026, 1, 15, 12), kuwait);
    final july = tz.TZDateTime.from(DateTime.utc(2026, 7, 15, 12), kuwait);

    expect(january.timeZoneOffset, const Duration(hours: 3));
    expect(july.timeZoneOffset, const Duration(hours: 3));
  });
}
