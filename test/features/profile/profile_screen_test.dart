import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/profile/profile_screen.dart';

import '../../support/harness.dart';

/// الملف الشخصي — the screen the plan is built from.
///
/// The two things worth guarding are the two the user asked for in words:
/// that **every field explains what it changes** («تبقى مكتوبة عشان المستخدم
/// يفهم»), and that **he can add fields Nouri never thought of** («انا مش
/// عارف احصرها»).
///
/// The third is Nouri's own rule rather than his: nothing here may read as a
/// score or a shortfall. He is filling in a form about his own life, and a
/// progress bar over that is the self-blame §1.2 forbids.
void main() {
  late NouriDatabase db;

  /// Taller than any phone, deliberately.
  ///
  /// The screen is a lazy `ListView`, so on a realistic surface everything
  /// below the fold — the custom fields, «ابني خطتي», the privacy line — is
  /// never built, and a finder for it reports "found 0" as though the widget
  /// were missing rather than merely off-screen. Laying the whole thing out
  /// keeps these assertions about the screen rather than about scrolling.
  const tall = Size(420, 3000);

  /// Pumps the screen with its data already present.
  ///
  /// **Not `pumpAndSettle` for the first frame.** While the profile stream has
  /// not delivered, the screen shows a `CircularProgressIndicator`, which
  /// schedules frames forever — so `pumpAndSettle` spins until its ten-minute
  /// timeout rather than failing usefully. Creating the row first and pumping
  /// explicitly makes the load deterministic.
  Future<void> pump(WidgetTester t) async {
    await db.profileDao.get();
    await t.pumpWidget(testApp(db: db, child: const ProfileScreen()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  setUp(() {
    db = NouriDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  group('every field says what it changes', () {
    testWidgets('the occupation question explains the branch it decides',
        (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);

        // Not a demographic question: it is the one that decides whether the
        // day is built around shifts or lectures, and the screen says so.
        expect(find.textContaining('الورديات'), findsOneWidget);
        expect(find.textContaining('المحاضرات'), findsWidgets);
      });
    });

    testWidgets('the interests field says what it is actually for', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);
        expect(find.textContaining('الكتب هتترشّح'), findsOneWidget);
      });
    });
  });

  group('the student fields appear only for a student', () {
    testWidgets('an unanswered profile shows neither branch', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);
        expect(find.byKey(const ValueKey('profile-field-المرحلة الدراسية')),
            findsNothing);
        expect(
            find.byKey(const ValueKey('profile-field-شغل تاني')), findsNothing);
      });
    });

    testWidgets('choosing طالب reveals the study fields, and only those',
        (t) async {
      await withLargeSurface(t, size: tall, () async {
        await db.profileDao
            .update(const ProfileRowsCompanion(occupation: Value('student')));
        await pump(t);

        expect(find.byKey(const ValueKey('profile-field-المرحلة الدراسية')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('profile-field-شغل تاني')),
            findsNothing,
            reason: 'a student is not being asked about a second job');
      });
    });

    testWidgets('«الاتنين» reveals both, because both apply', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await db.profileDao
            .update(const ProfileRowsCompanion(occupation: Value('both')));
        await pump(t);

        expect(find.byKey(const ValueKey('profile-field-المرحلة الدراسية')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('profile-field-شغل تاني')),
            findsOneWidget);
      });
    });
  });

  group('the fields Nouri never thought of', () {
    testWidgets('an empty list says so plainly rather than showing nothing',
        (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);
        expect(find.byKey(const ValueKey('custom-fields-empty')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('add-custom-field')), findsOneWidget);
      });
    });

    testWidgets('a field he added is shown in his own words', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await db.profileDao
            .addCustomField(label: 'النادي', value: 'الجمعة بعد العصر');
        await pump(t);

        expect(find.text('النادي'), findsOneWidget);
        expect(find.text('الجمعة بعد العصر'), findsOneWidget);
      });
    });

    testWidgets('and can be taken away again', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await db.profileDao.addCustomField(label: 'النادي', value: 'الجمعة');
        await pump(t);

        final id = (await db.profileDao.customFields()).single.id;
        await t.tap(find.byKey(ValueKey('remove-custom-field-$id')));
        await t.pumpAndSettle();

        expect(await db.profileDao.customFields(), isEmpty);
      });
    });
  });

  group('nothing here is a score', () {
    testWidgets('an empty profile is never told it is incomplete', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);

        // No percentage, no "0 من 8", no bar. The hint names what a fuller
        // profile would buy him and stops there.
        expect(find.textContaining('%'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byKey(const ValueKey('build-plan-hint')), findsOneWidget);
      });
    });

    testWidgets('the button is pressable on a completely empty profile',
        (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);

        // A gate here would be a form that must be completed before the app is
        // useful, which is the stress Nouri exists to remove.
        await t.tap(find.byKey(const ValueKey('build-my-plan')));
        await t.pumpAndSettle();

        expect(find.byKey(const ValueKey('build-plan-not-ready')),
            findsOneWidget);
      });
    });

    testWidgets('the button explains it needs a key rather than doing nothing',
        (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);
        await t.tap(find.byKey(const ValueKey('build-my-plan')));
        await t.pumpAndSettle();

        expect(find.textContaining('مفتاح API'), findsOneWidget);
        expect(find.textContaining('حسابك'), findsNothing,
            reason: 'the sheet says the account stays his, in his own terms');
      });
    });
  });

  group('what leaves the phone is stated on the screen that sends it',
      () {
    testWidgets('the privacy line names what is NOT sent', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);

        final note = find.byKey(const ValueKey('profile-privacy-note'));
        expect(note, findsOneWidget);
        expect(find.textContaining('وجباتك'), findsOneWidget);
        expect(find.textContaining('مصاريفك'), findsOneWidget);
      });
    });
  });

  group('the photo', () {
    testWidgets('says it is not ready rather than looking broken', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);
        expect(find.byKey(const ValueKey('profile-photo-pending')),
            findsOneWidget);
      });
    });
  });
}
