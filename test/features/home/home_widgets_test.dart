import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/core/time/date_formats.dart';
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
    final sunday = DateTime(2026, 9, 6);

    Future<void> pumpHeader(WidgetTester t, {bool arabic = true}) => pump(
          t,
          HomeHeader(
            hijri: hijriFor(sunday, arabic: arabic),
            gregorian: formatGregorianLong(sunday, arabic: arabic),
            greeting: arabic ? 'صباح الخير' : 'Good morning',
          ),
        );

    testWidgets('shows greeting, both dates and the Nouri mark', (t) async {
      await pumpHeader(t);
      expect(find.text('صباح الخير'), findsOneWidget);
      expect(find.text('نوري'), findsOneWidget);
      expect(find.textContaining('هـ'), findsOneWidget);
      expect(find.text('الأحد، ٦ سبتمبر ٢٠٢٦'), findsOneWidget);
    });

    testWidgets('the Hijri date is visually primary over the Gregorian',
        (t) async {
      await pumpHeader(t);

      final hijriStyle =
          t.widget<Text>(find.textContaining('هـ')).style!;
      final gregorianStyle =
          t.widget<Text>(find.text('الأحد، ٦ سبتمبر ٢٠٢٦')).style!;

      expect(hijriStyle.fontSize! > gregorianStyle.fontSize!, isTrue,
          reason: 'Hijri is larger');
      expect(hijriStyle.color, NouriColors.text);
      expect(gregorianStyle.color, NouriColors.muted,
          reason: 'Gregorian is present but quieter');
    });

    testWidgets('renders both dates in English too', (t) async {
      await pumpHeader(t, arabic: false);
      expect(find.text('Sunday, 6 September 2026'), findsOneWidget);
      expect(find.textContaining('AH'), findsOneWidget);
    });

    testWidgets('a long date does not overflow the header', (t) async {
      // «الأربعاء، ٣٠ سبتمبر ٢٠٢٦» next to the avatar is about the widest
      // this row ever gets.
      await pump(
        t,
        HomeHeader(
          hijri: hijriFor(DateTime(2026, 9, 30)),
          gregorian: formatGregorianLong(DateTime(2026, 9, 30)),
          greeting: 'مساء الخير',
        ),
      );
      expect(t.takeException(), isNull);
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
