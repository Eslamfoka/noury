import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/phone/phone_time_card.dart';

import '../../support/harness.dart';

void main() {
  late NouriDatabase db;

  Future<void> pumpCard(WidgetTester t) async {
    await t.pumpWidget(
      testApp(
        db: db,
        child: const Scaffold(
          body: SingleChildScrollView(child: PhoneTimeCard()),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('an untouched day shows a dash, not a zero', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpCard(t);
      expect(find.text('وقت الموبايل'), findsOneWidget);
      expect(
        (t.widget<Text>(find.byKey(const ValueKey('phone-minutes')))).data,
        '—',
      );
    });
  });

  testWidgets('logging a sitting records it and shows the total', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpCard(t);

      await t.tap(find.byKey(const ValueKey('phone-add-30')));
      await t.pumpAndSettle();

      expect(await db.phoneDao.minutesOn(DateTime.now()), 30);
      expect(
        (t.widget<Text>(find.byKey(const ValueKey('phone-minutes')))).data,
        contains('٣٠'),
      );
    });
  });

  testWidgets('two sittings add up — the cap is on the day', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpCard(t);

      await t.tap(find.byKey(const ValueKey('phone-add-30')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('phone-add-15')));
      await t.pumpAndSettle();

      expect(await db.phoneDao.minutesOn(DateTime.now()), 45);
    });
  });

  testWidgets('a logged sitting can be taken back', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpCard(t);

      await t.tap(find.byKey(const ValueKey('phone-add-30')));
      await t.pumpAndSettle();

      final id = (await db.phoneDao.forDate(DateTime.now())).first.id;
      await t.tap(find.byKey(ValueKey('phone-delete-$id')));
      await t.pumpAndSettle();

      expect(await db.phoneDao.minutesOn(DateTime.now()), 0);
    });
  });

  testWidgets('passing the cap is said plainly and is never red', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.phoneDao.log(date: DateTime.now(), minutes: 90);
      await pumpCard(t);

      final note =
          t.widget<Text>(find.byKey(const ValueKey('phone-note'))).data!;
      expect(note.isNotEmpty, isTrue);
      for (final word in ['فاتتك', 'ضيعت', 'فشل', 'كسلان', 'مدمن']) {
        expect(note.contains(word), isFalse, reason: word);
      }

      // Gold, not red. Nothing in Nouri is ever red, and an hour on the phone
      // is not a failure — the structural guard covers the app, this states
      // the intent where the number is drawn.
      final value =
          t.widget<Text>(find.byKey(const ValueKey('phone-minutes')));
      expect(value.style!.color, NouriColors.gold);
    });
  });

  testWidgets('Nouri does not claim to have measured the time', (t) async {
    // The whole card rests on the user's word. It must not imply it read the
    // device: that would need PACKAGE_USAGE_STATS, which Nouri does not ask
    // for, and it would be inferring where every other pillar asks.
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await pumpCard(t);
      final note =
          t.widget<Text>(find.byKey(const ValueKey('phone-note'))).data!;
      for (final claim in ['قستلك', 'حسبتلك', 'رصدت', 'اتقاس']) {
        expect(note.contains(claim), isFalse, reason: claim);
      }
    });
  });
}
