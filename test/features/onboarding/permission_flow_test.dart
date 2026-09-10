import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/onboarding/permission_flow.dart';

import '../../support/harness.dart';

void main() {
  List<PermissionStep> steps({
    void Function(String)? onRequest,
  }) =>
      defaultPermissionSteps(
        requestNotifications: () async => onRequest?.call('notifications'),
        requestBattery: () async => onRequest?.call('battery'),
        requestLocation: () async => onRequest?.call('location'),
      );

  Future<void> pumpFlow(
    WidgetTester t, {
    VoidCallback? onDone,
    void Function(String)? onRequest,
  }) =>
      t.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PermissionFlow(
            steps: steps(onRequest: onRequest),
            onDone: onDone ?? () {},
          ),
        ),
      ));

  testWidgets('starts on the notifications step', (t) async {
    await withLargeSurface(t, () async {
      await pumpFlow(t);
      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('اسمح بالإشعارات'), findsOneWidget);
    });
  });

  testWidgets('every step can be skipped', (t) async {
    await withLargeSurface(t, () async {
      await pumpFlow(t);
      expect(find.text('تخطّي'), findsOneWidget);
    });
  });

  testWidgets('each step explains why in one plain sentence', (t) async {
    await withLargeSurface(t, () async {
      await pumpFlow(t);
      // Colloquial "عشان" — Nouri explains itself rather than demanding.
      expect(find.textContaining('عشان'), findsOneWidget);
    });
  });

  testWidgets('no step blocks progress or shows an error state', (t) async {
    await withLargeSurface(t, () async {
      await pumpFlow(t);
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.block), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);
    });
  });

  testWidgets('skipping walks through every step and finishes',
      (t) async {
    await withLargeSurface(t, () async {
      var done = false;
      await pumpFlow(t, onDone: () => done = true);

      expect(find.text('الإشعارات'), findsOneWidget);
      await t.tap(find.text('تخطّي'));
      await t.pumpAndSettle();

      expect(find.text('البطارية'), findsOneWidget);
      await t.tap(find.text('تخطّي'));
      await t.pumpAndSettle();

      expect(find.text('الموقع'), findsOneWidget);
      await t.tap(find.text('تخطّي'));
      await t.pumpAndSettle();

      // The shift is a question rather than a request, so it is last — and
      // skipping it leaves the morning default rather than blocking the way
      // in, like every step before it.
      expect(find.text('ورديتك'), findsOneWidget);
      await t.tap(find.text('تخطّي'));
      await t.pumpAndSettle();

      expect(done, isTrue);
    });
  });

  testWidgets('the shift step offers all four and stores the one picked',
      (t) async {
    await withLargeSurface(t, () async {
      final chosen = <String>[];
      var done = false;

      await t.pumpWidget(testShell(PermissionFlow(
        steps: defaultPermissionSteps(
          requestNotifications: () async {},
          requestBattery: () async {},
          requestLocation: () async {},
          chooseShift: (s) async => chosen.add(s),
        ),
        onDone: () => done = true,
      )));
      await t.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('تخطّي'));
        await t.pumpAndSettle();
      }

      for (final v in ['morning', 'evening', 'night', 'off']) {
        expect(find.byKey(ValueKey('onboarding-choice-$v')), findsOneWidget,
            reason: v);
      }

      await t.tap(find.byKey(const ValueKey('onboarding-choice-night')));
      await t.pumpAndSettle();

      expect(chosen, ['night']);
      expect(done, isTrue, reason: 'picking one finishes the flow');
    });
  });

  testWidgets('a choice step shows no accept button of its own', (t) async {
    // Options above and a single accept button below would be two ways to
    // answer the same question, and one of them ambiguous.
    await withLargeSurface(t, () async {
      var done = false;
      await pumpFlow(t, onDone: () => done = true);

      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('تخطّي'));
        await t.pumpAndSettle();
      }

      expect(find.text('ورديتك'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('تخطّي'), findsOneWidget);
      expect(done, isFalse);
    });
  });

  testWidgets('accepting a step requests it and advances', (t) async {
    await withLargeSurface(t, () async {
      final requested = <String>[];
      await pumpFlow(t, onRequest: requested.add);

      await t.tap(find.text('اسمح بالإشعارات'));
      await t.pumpAndSettle();

      expect(requested, ['notifications']);
      expect(find.text('البطارية'), findsOneWidget);
    });
  });

  testWidgets('the location step says Kuwait is used without it', (t) async {
    await withLargeSurface(t, () async {
      await pumpFlow(t);
      await t.tap(find.text('تخطّي'));
      await t.pumpAndSettle();
      await t.tap(find.text('تخطّي'));
      await t.pumpAndSettle();

      expect(find.textContaining('الكويت'), findsOneWidget,
          reason: 'the user must know the app still works without location');
    });
  });
}
