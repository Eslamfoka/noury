import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/format/arabic_plurals.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/home/home_providers.dart';
import 'package:nouri/features/prayers/daily_review_sheet.dart';

import '../../support/harness.dart';

/// A fixed day of prayer times, so "has this passed?" is not a race.
DailyPrayerTimes _times(DateTime day) => DailyPrayerTimes(
      fajr: DateTime(day.year, day.month, day.day, 4, 5),
      sunrise: DateTime(day.year, day.month, day.day, 5, 30),
      dhuhr: DateTime(day.year, day.month, day.day, 11, 46),
      asr: DateTime(day.year, day.month, day.day, 15, 18),
      maghrib: DateTime(day.year, day.month, day.day, 18, 4),
      isha: DateTime(day.year, day.month, day.day, 19, 23),
    );

void main() {
  group('Arabic counting', () {
    test('uses the singular for one', () {
      expect(countPrayers(1), 'صلاة واحدة');
      expect(countPrayers(1), isNot(contains('صلوات')));
    });

    test('uses the dual for two, with no numeral', () {
      // Arabic marks two on the noun itself. «٢ صلوات» is not a near miss,
      // it is wrong.
      expect(countPrayers(2), 'صلاتين');
      expect(countPrayers(2), isNot(contains('٢')));
    });

    test('uses the plural from three up', () {
      expect(countPrayers(3), contains('صلوات'));
      expect(countPrayers(5), contains('صلوات'));
    });

    test('never emits a western numeral', () {
      for (var n = 0; n <= 5; n++) {
        expect(RegExp(r'[0-9]').hasMatch(countPrayers(n)), isFalse,
            reason: 'the app writes numbers in Arabic-Indic digits');
      }
    });

    test('counts days with the dual and the after-eleven singular', () {
      expect(countDays(1), 'يوم واحد');
      expect(countDays(2), 'يومين');
      expect(countDays(3), contains('أيام'));
      expect(countDays(15), contains('يوم'));
      expect(countDays(15), isNot(contains('أيام')));
    });
  });

  group('unanswered prayers', () {
    List<String> pendingAt(
      DateTime now, {
      Map<String, PrayerState> logged = const {},
    }) =>
        unansweredFrom(times: _times(now), logs: logged, now: now)
            .map((e) => e.slot.name)
            .toList();

    test('a prayer still ahead is not unanswered', () {
      // At 12:00 only fajr and dhuhr have passed. Asr has not been missed;
      // it simply has not happened.
      final now = DateTime(2026, 9, 6, 12, 0);
      expect(pendingAt(now), isNot(contains('asr')));
      expect(pendingAt(now), isNot(contains('maghrib')));
    });

    test('lists past prayers that were never logged, in order', () {
      expect(pendingAt(DateTime(2026, 9, 6, 12, 0)), ['fajr', 'dhuhr']);
    });

    test('a logged prayer drops off the list', () {
      expect(
        pendingAt(DateTime(2026, 9, 6, 12, 0),
            logged: {'fajr': PrayerState.mosque}),
        ['dhuhr'],
      );
    });

    test('an explicitly missed prayer counts as answered', () {
      // «فاتتني» is an answer. Asking again would be nagging about something
      // the user has already told us.
      expect(
        pendingAt(DateTime(2026, 9, 6, 12, 0),
            logged: {'fajr': PrayerState.missed}),
        isNot(contains('fajr')),
      );
    });

    test('a prayer exactly at its adhan minute is not yet past', () {
      // Asking "how did you pray?" at the very moment the adhan sounds is the
      // bug this whole redesign exists to remove.
      expect(pendingAt(DateTime(2026, 9, 6, 11, 46)), isNot(contains('dhuhr')));
    });

    test('nothing is pending before fajr', () {
      expect(pendingAt(DateTime(2026, 9, 6, 3, 0)), isEmpty);
    });

    test('all five are pending after isha if none were logged', () {
      expect(pendingAt(DateTime(2026, 9, 6, 22, 0)).length, 5);
    });

    test('sunrise is never offered as something to log', () {
      expect(pendingAt(DateTime(2026, 9, 6, 22, 0)), isNot(contains('sunrise')));
    });
  });

  group('daily review sheet', () {
    late NouriDatabase db;

    Future<void> pump(
      WidgetTester t,
      DateTime now, {
      Map<String, PrayerState> logged = const {},
    }) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            todayPrayerTimesProvider
                .overrideWithValue(AsyncValue.data(_times(now))),
            todayPrayerLogsProvider.overrideWith((ref) async => logged),
            coarseClockProvider.overrideWith((ref) => Stream.value(now)),
          ],
          child: testShell(
            Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showDailyReviewSheet(ctx),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    setUp(() {
      db = NouriDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
    });

    testWidgets('offers each unlogged prayer by name', (t) async {
      await withLargeSurface(t, () async {
        await pump(t, DateTime(2026, 9, 6, 22, 0));
        expect(find.text('الفجر'), findsOneWidget);
        expect(find.text('العشاء'), findsOneWidget);
      });
    });

    testWidgets('says something kind when nothing is pending', (t) async {
      await withLargeSurface(t, () async {
        await pump(
          t,
          DateTime(2026, 9, 6, 22, 0),
          logged: {
            for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'])
              p: PrayerState.mosque,
          },
        );
        expect(find.textContaining('كل صلوات النهاردة متسجلة'), findsOneWidget);
      });
    });

    testWidgets('never blames the user for an unlogged prayer', (t) async {
      await withLargeSurface(t, () async {
        await pump(t, DateTime(2026, 9, 6, 22, 0));

        const blaming = ['ضيعت', 'قصرت', 'فشلت', 'إهمال', 'مقصر'];
        for (final word in blaming) {
          expect(find.textContaining(word), findsNothing,
              reason: 'Nouri states facts, it does not deliver verdicts');
        }

        bool isRed(Color? c) =>
            c != null && c.r * 255 > 200 && c.g * 255 < 90 && c.b * 255 < 90;
        final reds = t
            .widgetList<Text>(find.byType(Text))
            .where((w) => isRed(w.style?.color));
        expect(reds, isEmpty);
      });
    });
  });
}
