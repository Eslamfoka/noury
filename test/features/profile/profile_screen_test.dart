import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/planner/ai/plan_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nouri/features/home/home_providers.dart';
import 'package:nouri/features/profile/profile_photo.dart';
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

  group('a date can be taken back', () {
    testWidgets('an unset date offers nothing to clear', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pump(t);
        expect(find.byKey(const ValueKey('profile-birthdate-clear')),
            findsNothing);
      });
    });

    testWidgets('a set date can be cleared back to empty', (t) async {
      // Every other field on this screen can be emptied — text by deleting it,
      // a choice chip by tapping the selected one. The date could only ever be
      // *replaced*, because a picker has no "none". So a value set by mistake
      // was permanent, which is how 2001/1/1 — the picker's own default —
      // ended up in the real profile on 9 September 2026, written by a stray
      // gesture and impossible to take back.
      await db.profileDao.update(
        ProfileRowsCompanion(birthDate: Value(DateTime(2001, 1, 1))),
      );
      await pump(t);

      expect(find.text('2001/1/1'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('profile-birthdate-clear')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      expect((await db.profileDao.get()).birthDate, isNull);
      expect(find.text('اختار التاريخ'), findsOneWidget);
    });

    testWidgets('clearing it takes the age out of what Claude is told',
        (t) async {
      // The point of the field. A wrong birth date is not cosmetic — it is a
      // wrong age in the summary, and the age shapes sleep and exercise advice.
      await db.profileDao.update(
        ProfileRowsCompanion(birthDate: Value(DateTime(2001, 1, 1))),
      );
      await pump(t);
      await t.tap(find.byKey(const ValueKey('profile-birthdate-clear')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));

      final payload = PlanRequest(
        profile: await db.profileDao.get(),
        customFields: const [],
        days: const [],
        shiftType: 'night',
        prayerTimesByDay: const {},
        targetSleepHours: 7,
        eatingWindowStartHour: 12,
        eatingWindowHours: 8,
        waterTargetGlasses: 8,
      ).toPrompt(allowedTaskIds: const ['walk']);

      expect(payload, isNot(contains('السن')));
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
    /// Pumps the screen with the two photo seams replaced.
    ///
    /// `testApp` takes no overrides — `Override` is not exported by
    /// flutter_riverpod, so an overrides list can only be written inline where
    /// `ProviderScope` can infer its type. Hence the scope built by hand here.
    Future<void> pumpWithPhoto(
      WidgetTester t, {
      required Future<String?> Function() chooser,
      Future<void> Function()? remover,
    }) async {
      await db.profileDao.get();
      await t.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          photoChooserProvider.overrideWithValue(chooser),
          if (remover != null) photoRemoverProvider.overrideWithValue(remover),
        ],
        child: testShell(const ProfileScreen()),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('an empty slot says what the photo does, which is nothing',
        (t) async {
      // The one field on this screen whose honest answer is "it changes
      // nothing". Every other row promises the answer shapes the plan; this
      // one must not be allowed to imply the same by standing among them.
      await withLargeSurface(t, size: tall, () async {
        await pumpWithPhoto(t, chooser: () async => null);

        final line = t.widget<Text>(
            find.byKey(const ValueKey('profile-photo-explain')));
        expect(line.data, contains('مش بتروح لحد'));
        expect(line.data, contains('مش بتغيّر الخطة'));
      });
    });

    testWidgets('choosing one writes the path into the profile', (t) async {
      await withLargeSurface(t, size: tall, () async {
        final file = File('${Directory.systemTemp.path}/nouri-test-photo.jpg')
          ..writeAsStringSync('x');
        addTearDown(() {
          if (file.existsSync()) file.deleteSync();
        });

        await pumpWithPhoto(t, chooser: () async => file.path);
        await t.tap(find.byKey(const ValueKey('profile-photo')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));

        expect((await db.profileDao.get()).photoPath, file.path);
      });
    });

    testWidgets('backing out of the picker changes nothing', (t) async {
      await withLargeSurface(t, size: tall, () async {
        await pumpWithPhoto(t, chooser: () async => null);
        await t.tap(find.byKey(const ValueKey('profile-photo')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));

        expect((await db.profileDao.get()).photoPath, isNull);
        expect(find.byKey(const ValueKey('profile-photo-clear')), findsNothing);
      });
    });

    testWidgets('a path whose file is gone draws the empty circle', (t) async {
      // The row is in the database and the file is on disk, and the two can
      // part company — cleared app storage, a restore onto another phone. An
      // app that answers that with a broken image is telling the user
      // something is wrong with them.
      await withLargeSurface(t, size: tall, () async {
        await db.profileDao.update(const ProfileRowsCompanion(
            photoPath: Value('/nowhere/at/all/profile-1.jpg')));

        await pumpWithPhoto(t, chooser: () async => null);
        // `pump` advances the test's fake clock; reading a file happens on the
        // real one. Without `runAsync` the load never gets a chance to fail,
        // so the fallback never runs and this would assert about a frame the
        // user never sees.
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 200)));
        await t.pump();

        expect(t.takeException(), isNull);
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
      });
    });

    testWidgets('a photo that is there can be taken back off', (t) async {
      // A value the user can set is a value the user can unset — the rule a
      // birth date had to learn after a stray gesture wrote 2001/1/1 into the
      // real profile and there was no way back out of it.
      await withLargeSurface(t, size: tall, () async {
        final file = File('${Directory.systemTemp.path}/nouri-test-clear.jpg')
          ..writeAsStringSync('x');
        addTearDown(() {
          if (file.existsSync()) file.deleteSync();
        });
        await db.profileDao
            .update(ProfileRowsCompanion(photoPath: Value(file.path)));

        var removed = false;
        await pumpWithPhoto(
          t,
          chooser: () async => null,
          remover: () async => removed = true,
        );
        await t.pump(const Duration(milliseconds: 50));

        await t.tap(find.byKey(const ValueKey('profile-photo-clear')));
        await t.pump();
        await t.pump(const Duration(milliseconds: 50));

        expect(removed, isTrue, reason: 'the file has to go, not just the row');
        expect((await db.profileDao.get()).photoPath, isNull);
      });
    });

    testWidgets('the photo is not in what gets sent to Claude', (t) async {
      // Stated here as well as in plan_request_test, because this is the
      // screen that collects it and the screen that says it goes nowhere.
      await db.profileDao.update(
          const ProfileRowsCompanion(photoPath: Value('/data/profile-9.jpg')));

      final request = PlanRequest(
        profile: await db.profileDao.get(),
        customFields: const [],
        days: const [],
        shiftType: 'morning',
        prayerTimesByDay: const {},
        targetSleepHours: 7,
        eatingWindowStartHour: 12,
        eatingWindowHours: 8,
        waterTargetGlasses: 8,
      );

      expect(request.toPrompt(allowedTaskIds: const ['walk']),
          isNot(contains('profile-9')));
    });
  });
}
