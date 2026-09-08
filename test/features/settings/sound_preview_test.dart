import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/adhan_sounds.dart';
import 'package:nouri/core/notifications/notification_channels.dart';
import 'package:nouri/core/notifications/task_alert.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/settings/settings_section_screen.dart';
import 'package:nouri/features/settings/settings_sections.dart';

import '../../support/harness.dart';

/// الأصوات — the screen that answers the two questions only an ear can.
///
/// Nouri ships five adhans and nineteen tones and, until this existed, the
/// only way to hear any of them was to wait for the moment it fires. Which
/// meant the two things the handoff had been asking the user for a week —
/// *which adhan carries «الصلاة خير من النوم»* and *which tones do not read*
/// — could not actually be answered without living with the app for a day.
///
/// A notification is used rather than an audio player on purpose: Android
/// reads a sound off its **channel**, so posting on the channel is the only
/// way to hear what will really arrive, including any change the user has
/// made to it in system settings.
void main() {
  late NouriDatabase db;

  Future<void> pump(WidgetTester t) async {
    db = inMemoryDatabase(t);
    await t.pumpWidget(testApp(
      db: db,
      child: const SettingsSectionScreen(section: SettingsSection.sounds),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('every adhan can be played, and says who recorded it',
      (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      for (final prayer in adhanPrayers) {
        expect(find.byKey(ValueKey('preview-adhan-$prayer')), findsOneWidget,
            reason: prayer);
        // CC BY and CC BY-SA make attribution a condition of use, so the
        // credit travels with the button rather than living only in عن نوري.
        expect(find.text(adhanCredits[prayer]!), findsOneWidget,
            reason: prayer);
      }
    });
  });

  testWidgets('every task tone can be played', (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      for (final kind in TaskAlertKind.values) {
        final row = find.byKey(ValueKey('preview-${kind.name}'));
        await t.scrollUntilVisible(row, 300,
            scrollable: find.byType(Scrollable).first);
        expect(row, findsOneWidget, reason: kind.name);
      }
    });
  });

  testWidgets('pressing play does not throw when there is no service yet',
      (t) async {
    // `notificationServiceProvider` is null until the plugin is ready, and
    // الأصوات is reachable before then. A press must be a no-op, not a crash.
    await withLargeSurface(t, () async {
      await pump(t);
      await t.tap(find.descendant(
        of: find.byKey(const ValueKey('preview-adhan-fajr')),
        matching: find.byType(TextButton),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  test('no two tones are listed under the same name', () {
    // Two rows reading «نوري» would be two buttons the user cannot tell
    // apart — which is the exact failure this whole screen exists to fix.
    final names = TaskAlertKind.values.map((k) => k.soundName).toList();
    expect(names.toSet(), hasLength(names.length),
        reason: '$names');
  });

  test('an audition does not seize the screen', () {
    // Five adhans compared in a row, each with a full-screen intent, would
    // make the screen unusable for the one thing it is for. Everything that
    // makes the sound real is kept.
    for (final prayer in adhanPrayers) {
      final id = adhanChannelFor(prayer);
      final real = androidDetailsFor(id);
      final preview = androidDetailsFor(id, preview: true);

      expect(real.fullScreenIntent, isTrue, reason: 'the real one still does');
      expect(preview.fullScreenIntent, isFalse, reason: prayer);

      expect(preview.sound, real.sound, reason: 'same recording');
      expect(preview.audioAttributesUsage, real.audioAttributesUsage,
          reason: 'same volume');
      expect(preview.importance, real.importance);
    }
  });

  test('preview changes nothing for a channel that never had a takeover', () {
    for (final kind in TaskAlertKind.values) {
      final real = androidDetailsFor(kind.channelId);
      final preview = androidDetailsFor(kind.channelId, preview: true);
      expect(preview.fullScreenIntent, real.fullScreenIntent,
          reason: kind.name);
      expect(preview.sound, real.sound, reason: kind.name);
    }
  });
}
