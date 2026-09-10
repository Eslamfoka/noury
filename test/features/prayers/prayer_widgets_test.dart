import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/data/db/tables.dart';
import 'package:nouri/features/prayers/prayer_log_sheet.dart';
import 'package:nouri/features/prayers/prayer_row.dart';

void main() {
  group('PrayerRow', () {
    Future<void> pumpRow(
      WidgetTester t, {
      required PrayerState state,
      bool isNext = false,
      VoidCallback? onTap,
    }) =>
        t.pumpWidget(MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PrayerRow(
                slot: PrayerSlot('asr', DateTime(2026, 9, 5, 15, 15)),
                state: state,
                isNext: isNext,
                onTap: onTap ?? () {},
              ),
            ),
          ),
        ));

    testWidgets('shows the prayer name, time and state chip', (t) async {
      await pumpRow(t, state: PrayerState.mosque);
      expect(find.text('العصر'), findsOneWidget);
      expect(find.text('٣:١٥'), findsOneWidget);
      expect(find.text('في المسجد'), findsOneWidget);
    });

    testWidgets('an unlogged prayer reads «لسه», not a failure', (t) async {
      await pumpRow(t, state: PrayerState.none);
      expect(find.text('لسه'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.error), findsNothing);
    });

    testWidgets('the whole row is tappable', (t) async {
      var taps = 0;
      await pumpRow(t, state: PrayerState.none, onTap: () => taps++);
      await t.tap(find.byType(PrayerRow));
      expect(taps, 1);
    });
  });

  group('showPrayerLogSheet', () {
    Future<void> pumpSheet(
      WidgetTester t,
      PrayerState current,
      void Function(PrayerState?) onResult,
    ) async {
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      onResult(await showPrayerLogSheet(ctx, 'asr', current)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
    }

    testWidgets('offers the four states and returns the tapped one',
        (t) async {
      PrayerState? result;
      await pumpSheet(t, PrayerState.none, (r) => result = r);

      expect(find.text('في المسجد'), findsOneWidget);
      expect(find.text('جماعة'), findsOneWidget);
      expect(find.text('في الوقت'), findsOneWidget);
      expect(find.text('متأخرة'), findsOneWidget);

      await t.tap(find.text('في المسجد'));
      await t.pumpAndSettle();
      expect(result, PrayerState.mosque);
    });

    testWidgets('asks a question rather than issuing a verdict', (t) async {
      await pumpSheet(t, PrayerState.none, (_) {});
      expect(find.textContaining('صليت العصر إزاي؟'), findsOneWidget);
    });

    testWidgets('the sheet contains no punishing language', (t) async {
      await pumpSheet(t, PrayerState.none, (_) {});
      for (final w in ['فاتتك', 'ضيعت', 'فشل']) {
        expect(find.textContaining(w), findsNothing);
      }
    });

    testWidgets('clearing is offered only once something is logged',
        (t) async {
      await pumpSheet(t, PrayerState.none, (_) {});
      expect(find.text('امسح التسجيل'), findsNothing);
    });

    testWidgets('a logged prayer can be cleared back to «لسه»', (t) async {
      PrayerState? result;
      await pumpSheet(t, PrayerState.mosque, (r) => result = r);
      expect(find.text('امسح التسجيل'), findsOneWidget);
      await t.ensureVisible(find.text('امسح التسجيل'));
      await t.pumpAndSettle();
      await t.tap(find.text('امسح التسجيل'));
      await t.pumpAndSettle();
      expect(result, PrayerState.none);
    });
  });
}
