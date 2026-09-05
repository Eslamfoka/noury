import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/core/time/hijri_date.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/home/widgets/home_header.dart';
import 'package:nouri/features/home/widgets/next_prayer_card.dart';
import 'package:nouri/features/home/widgets/progress_ring.dart';

Future<void> pump(WidgetTester t, Widget child) => t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    );

/// Any red anywhere in the rendered tree would violate the no-blame rule.
bool rendersRed(WidgetTester t) {
  bool isRed(Color? c) =>
      c != null && c.r * 255 > 200 && c.g * 255 < 90 && c.b * 255 < 90;

  final boxes = t
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .any((d) => isRed((d.decoration as BoxDecoration).color));
  final texts =
      t.widgetList<Text>(find.byType(Text)).any((w) => isRed(w.style?.color));
  return boxes || texts;
}

void main() {
  group('ProgressRing', () {
    testWidgets('shows the count in Arabic-Indic digits', (t) async {
      await pump(t, const ProgressRing(done: 5, total: 9));
      expect(find.text('٥/٩'), findsOneWidget);
    });

    testWidgets('an empty day renders without any error styling', (t) async {
      await pump(t, const ProgressRing(done: 0, total: 9));
      expect(find.text('٠/٩'), findsOneWidget);
      expect(rendersRed(t), isFalse);
    });

    testWidgets('a full day renders without any error styling', (t) async {
      await pump(t, const ProgressRing(done: 9, total: 9));
      expect(find.text('٩/٩'), findsOneWidget);
      expect(rendersRed(t), isFalse);
    });
  });

  group('HomeHeader', () {
    testWidgets('shows greeting, Hijri date and the Nouri mark', (t) async {
      await pump(
        t,
        HomeHeader(
          hijri: hijriFor(DateTime(2026, 9, 5)),
          greeting: 'صباح الخير',
        ),
      );
      expect(find.text('صباح الخير'), findsOneWidget);
      expect(find.text('نوري'), findsOneWidget);
      expect(find.textContaining('هـ'), findsOneWidget);
    });
  });

  group('NextPrayerCard', () {
    testWidgets('shows prayer name, countdown and iqama in Arabic digits',
        (t) async {
      await pump(
        t,
        NextPrayerCard(
          slot: PrayerSlot('asr', DateTime(2026, 9, 5, 15, 15)),
          iqama: DateTime(2026, 9, 5, 15, 30),
          remaining: const Duration(hours: 1, minutes: 24, seconds: 10),
        ),
      );
      expect(find.text('العصر'), findsOneWidget);
      expect(find.text('١:٢٤:١٠'), findsOneWidget);
      expect(find.text('٣:٣٠'), findsOneWidget);
      expect(find.text('٣:١٥'), findsOneWidget);
    });

    testWidgets('a passed prayer shows zero, never a negative countdown',
        (t) async {
      await pump(
        t,
        NextPrayerCard(
          slot: PrayerSlot('isha', DateTime(2026, 9, 5, 19, 4)),
          iqama: DateTime(2026, 9, 5, 19, 19),
          remaining: const Duration(minutes: -5),
        ),
      );
      expect(find.text('٠:٠٠:٠٠'), findsOneWidget);
      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('is outlined in gold, the highlight colour', (t) async {
      await pump(
        t,
        NextPrayerCard(
          slot: PrayerSlot('fajr', DateTime(2026, 9, 5, 4, 21)),
          iqama: DateTime(2026, 9, 5, 4, 41),
          remaining: const Duration(hours: 2),
        ),
      );
      final box = t
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      expect(box.border!.top.color, NouriColors.gold);
      expect(rendersRed(t), isFalse);
    });
  });
}
