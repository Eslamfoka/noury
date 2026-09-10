import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/tables.dart';
import 'package:nouri/features/reports/weekly_summary.dart';

DaySnapshot day(
  int d, {
  List<PrayerState> states = const [],
  bool morning = false,
  bool evening = false,
  int tasbeeh = 0,
  int pages = 0,
}) =>
    DaySnapshot(
      date: DateTime(2026, 9, d),
      prayerStates: states,
      morningDone: morning,
      eveningDone: evening,
      tasbeehCount: tasbeeh,
      quranPages: pages,
    );

void main() {
  test('covers exactly the days it is given', () {
    final s = WeeklySummary.build(days: List.generate(7, (i) => day(i + 1)));
    expect(s.days.length, 7);
  });

  test('averages only the prayers that were logged', () {
    final s = WeeklySummary.build(days: [
      day(1, states: [PrayerState.mosque, PrayerState.none]),
      day(2, states: [PrayerState.onTime]),
    ]);
    expect(s.prayerAverage, closeTo(85.0, 0.01)); // (100 + 70) / 2
    expect(s.prayersLogged, 2);
  });

  test('a week with nothing logged has a null average, never zero', () {
    final s = WeeklySummary.build(days: [day(1), day(2)]);
    expect(s.prayerAverage, isNull);
    expect(s.prayersLogged, 0);
  });

  test('unlogged prayers never drag the average down', () {
    final allLogged = WeeklySummary.build(days: [
      day(1, states: [PrayerState.mosque]),
    ]);
    final withGaps = WeeklySummary.build(days: [
      day(1, states: [PrayerState.mosque, PrayerState.none, PrayerState.none]),
    ]);
    expect(withGaps.prayerAverage, allLogged.prayerAverage);
  });

  test('the wird streak counts consecutive days ending today', () {
    final s = WeeklySummary.build(days: [
      day(1, pages: 3),
      day(2, pages: 0),
      day(3, pages: 3),
      day(4, pages: 3),
      day(5, pages: 3),
    ]);
    expect(s.wirdStreak, 3, reason: 'days 3, 4, 5 — the gap on day 2 ends it');
  });

  test('a streak broken today is zero, not the older run', () {
    final s = WeeklySummary.build(days: [
      day(1, pages: 3),
      day(2, pages: 3),
      day(3, pages: 0),
    ]);
    expect(s.wirdStreak, 0);
  });

  test('a full week of wird gives a streak of seven', () {
    final s = WeeklySummary.build(
      days: List.generate(7, (i) => day(i + 1, pages: 3)),
    );
    expect(s.wirdStreak, 7);
  });

  test('tasbeeh and pages accumulate across the week', () {
    final s = WeeklySummary.build(days: [
      day(1, tasbeeh: 100, pages: 3),
      day(2, tasbeeh: 33, pages: 6),
    ]);
    expect(s.tasbeehTotal, 133);
    expect(s.quranPages, 9);
  });

  test('athkar sessions count morning and evening separately', () {
    final s = WeeklySummary.build(days: [
      day(1, morning: true, evening: true),
      day(2, morning: true),
      day(3),
    ]);
    expect(s.athkarSessions, 3);
  });

  test('an empty week produces a valid, empty summary rather than throwing',
      () {
    final s = WeeklySummary.build(days: const []);
    expect(s.days, isEmpty);
    expect(s.prayerAverage, isNull);
    expect(s.wirdStreak, 0);
    expect(s.tasbeehTotal, 0);
    expect(s.athkarSessions, 0);
  });

  test('loggedPrayers on a snapshot excludes unlogged entries', () {
    final d = day(1, states: [
      PrayerState.mosque,
      PrayerState.none,
      PrayerState.late_,
    ]);
    expect(d.loggedPrayers, 2);
  });
}
