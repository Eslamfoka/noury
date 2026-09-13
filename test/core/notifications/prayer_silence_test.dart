import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/prayer_silence.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

/// The phone going silent for the prayer — the Dart half, which decides when.
///
///   «عايزك تظبط الصامت من بعد الأذان لحد ميعاد بعد الصلاة يعني من الاذان
///    للأقامة ومثلا ١٠ دقايق صلاه وبعدين يرجع تاني عام مش صامت»
void main() {
  final day = DateTime(2026, 9, 13);
  final times = DailyPrayerTimes(
    fajr: DateTime(2026, 9, 13, 4, 10),
    sunrise: DateTime(2026, 9, 13, 5, 30),
    dhuhr: DateTime(2026, 9, 13, 11, 45),
    asr: DateTime(2026, 9, 13, 15, 10),
    maghrib: DateTime(2026, 9, 13, 17, 55),
    isha: DateTime(2026, 9, 13, 19, 15),
  );
  const offsets = {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 10, 'isha': 15};

  test('one window per prayer: adhan to iqama plus the prayer\'s minutes', () {
    final windows = silenceWindowsFor(
      days: [(day, times)],
      iqamaOffsets: offsets,
      prayerMinutes: 10,
      now: DateTime(2026, 9, 13, 0, 0),
    );

    expect(windows.map((w) => w.prayer),
        ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']);

    final dhuhr = windows[1];
    expect(dhuhr.silenceAt, DateTime(2026, 9, 13, 11, 45),
        reason: 'silence begins at the adhan');
    // Iqama fifteen minutes after the adhan, then ten for the prayer.
    expect(dhuhr.restoreAt, DateTime(2026, 9, 13, 12, 10));

    final maghrib = windows[3];
    expect(maghrib.restoreAt, DateTime(2026, 9, 13, 18, 15),
        reason: 'each prayer uses its own iqama offset');
  });

  test('the prayer minutes are the user\'s number', () {
    final windows = silenceWindowsFor(
      days: [(day, times)],
      iqamaOffsets: offsets,
      prayerMinutes: 20,
      now: DateTime(2026, 9, 13, 0, 0),
    );
    expect(windows.first.restoreAt, DateTime(2026, 9, 13, 4, 50));
  });

  test('a window already over is not armed', () {
    final windows = silenceWindowsFor(
      days: [(day, times)],
      iqamaOffsets: offsets,
      prayerMinutes: 10,
      now: DateTime(2026, 9, 13, 12, 30),
    );
    expect(windows.map((w) => w.prayer), ['asr', 'maghrib', 'isha']);
  });

  test('a window in progress keeps its restore edge', () {
    // The app opened mid-prayer. The phone may already be silent from the
    // adhan edge; the restore is the half that still matters. The native
    // side declines to silence for a start that has passed.
    final windows = silenceWindowsFor(
      days: [(day, times)],
      iqamaOffsets: offsets,
      prayerMinutes: 10,
      now: DateTime(2026, 9, 13, 11, 50),
    );
    expect(windows.first.prayer, 'dhuhr');
    expect(windows.first.silenceAt.isBefore(DateTime(2026, 9, 13, 11, 50)), isTrue);
  });

  test('carries every day it is given, in order', () {
    final tomorrow = DateTime(2026, 9, 14);
    final windows = silenceWindowsFor(
      days: [(day, times), (tomorrow, times)],
      iqamaOffsets: offsets,
      prayerMinutes: 10,
      now: DateTime(2026, 9, 13, 0, 0),
    );
    expect(windows, hasLength(10));
  });

  test('the map the channel carries is epoch millis, nothing else', () {
    final w = SilenceWindow(
      prayer: 'asr',
      silenceAt: DateTime(2026, 9, 13, 15, 10),
      restoreAt: DateTime(2026, 9, 13, 15, 35),
    );
    final m = w.toMap();
    expect(m.keys, ['prayer', 'silenceAt', 'restoreAt']);
    expect(m['silenceAt'], DateTime(2026, 9, 13, 15, 10).millisecondsSinceEpoch);
  });

  test('three days, like the task alarms — thirty exact alarms at most', () {
    expect(kSilenceWindowDays, 3);
  });
}
