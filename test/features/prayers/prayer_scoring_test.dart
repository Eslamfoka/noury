import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/data/db/tables.dart';
import 'package:nouri/features/prayers/prayer_scoring.dart';

void main() {
  test('each state maps to its approved chip colour', () {
    expect(chipColorFor(PrayerState.mosque), NouriColors.gold);
    expect(chipColorFor(PrayerState.congregation), NouriColors.success);
    expect(chipColorFor(PrayerState.onTime), NouriColors.muted);
    expect(chipColorFor(PrayerState.late_), NouriColors.attention);
    expect(chipColorFor(PrayerState.none), NouriColors.muted);
  });

  test('no state is ever rendered in a failure red', () {
    for (final s in PrayerState.values) {
      final c = chipColorFor(s);
      expect(c.r * 255 > 200 && c.g * 255 < 90 && c.b * 255 < 90, isFalse,
          reason: '$s');
    }
  });

  test('an unlogged prayer looks no worse than an on-time one', () {
    // "Not yet" must not read as a warning state.
    expect(chipColorFor(PrayerState.none), chipColorFor(PrayerState.onTime));
  });

  test('labels use the approved wording', () {
    expect(chipLabelFor(PrayerState.mosque), 'في المسجد');
    expect(chipLabelFor(PrayerState.congregation), 'جماعة');
    expect(chipLabelFor(PrayerState.onTime), 'في الوقت');
    expect(chipLabelFor(PrayerState.late_), 'متأخرة');
    expect(chipLabelFor(PrayerState.none), 'لسه');
  });

  test('no label blames the user', () {
    for (final s in PrayerState.values) {
      for (final w in ['فاتتك', 'ضيعت', 'فشل', 'مفوّت']) {
        expect(chipLabelFor(s).contains(w), isFalse);
      }
    }
  });

  test('scores follow the agreed ladder', () {
    expect(PrayerState.mosque.score, 100);
    expect(PrayerState.congregation.score, 85);
    expect(PrayerState.onTime.score, 70);
    expect(PrayerState.late_.score, 40);
    expect(PrayerState.none.score, 0);
  });

  test('the loggable states run best to worst', () {
    expect(loggablePrayerStates, [
      PrayerState.mosque,
      PrayerState.congregation,
      PrayerState.onTime,
      PrayerState.late_,
      PrayerState.missed,
    ]);
    expect(loggablePrayerStates.contains(PrayerState.none), isFalse,
        reason: 'clearing an entry is not a rating');
  });

  test('«فاتتني» looks exactly like «متأخرة»', () {
    // It is the only label that names a failure. The brief's firmest rule is
    // that Nouri never shows failure marks, so it must not stand out.
    expect(chipColorFor(PrayerState.missed), chipColorFor(PrayerState.late_));
    expect(PrayerState.missed.score, PrayerState.late_.score,
        reason: 'scored as qada, not as a lower grade');
  });

  test('the enum is append-only, so stored rows keep their meaning', () {
    // drift persists these by index. Reordering would silently rewrite every
    // prayer the user has already logged.
    expect(PrayerState.values.map((e) => e.name).toList(), [
      'mosque',
      'congregation',
      'onTime',
      'late_',
      'none',
      'missed',
    ]);
  });

  test('an unlogged prayer is excluded from the average, not zeroed', () {
    final avg = dailyPrayerAverage([
      PrayerState.mosque,
      PrayerState.congregation,
      PrayerState.none,
    ]);
    expect(avg, closeTo(92.5, 0.01),
        reason: 'unlogged must not drag the average down');
  });

  test('a day with nothing logged has no average rather than zero', () {
    expect(dailyPrayerAverage([PrayerState.none, PrayerState.none]), isNull);
    expect(dailyPrayerAverage([]), isNull);
  });

  test('a perfect day averages 100', () {
    expect(
      dailyPrayerAverage(List.filled(5, PrayerState.mosque)),
      100.0,
    );
  });
}
