import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/app.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/features/home/home_providers.dart';

import 'support/harness.dart';

void main() {
  testWidgets('starts in Arabic, right-to-left, on the navy ground',
      (tester) async {
    await withLargeSurface(tester, () async {
      final db = inMemoryDatabase(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const NouriApp(),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(Scaffold).first);
      expect(Directionality.of(ctx), TextDirection.rtl,
          reason: 'RTL is the default direction, not a mode');
      expect(Localizations.localeOf(ctx), const Locale('ar'));
      expect(Theme.of(ctx).scaffoldBackgroundColor, NouriColors.background);
    });
  });

  testWidgets('English is supported as an alternative', (tester) async {
    expect(NouriApp.supportedLocales, contains(const Locale('en')));
    expect(NouriApp.supportedLocales.first, const Locale('ar'),
        reason: 'Arabic is the baseline, listed first');
  });
}
