import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/l10n/app_localizations.dart';
import 'package:nouri/core/theme/nouri_theme.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/home/home_providers.dart';

/// Runs [body] on a tall, phone-shaped surface.
///
/// The default 800x600 test window is shorter than any real phone, which makes
/// content-rich screens overflow in ways users never see. A 1200-tall surface
/// keeps the whole screen laid out so finders and taps are meaningful.
Future<void> withLargeSurface(
  WidgetTester tester,
  Future<void> Function() body, {
  Size size = const Size(420, 1200),
}) async {
  final view = tester.view;
  view.physicalSize = size;
  view.devicePixelRatio = 1.0;
  addTearDown(view.resetPhysicalSize);
  addTearDown(view.resetDevicePixelRatio);
  await body();
}

/// An in-memory database for widget tests.
///
/// The real `databaseProvider` opens a file through path_provider, which needs
/// a platform channel that widget tests do not have — so every test that
/// renders a data-backed screen must override it with one of these.
NouriDatabase inMemoryDatabase(WidgetTester tester) {
  final db = NouriDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// The app's real theme, locale and delegates, without any provider scope.
///
/// Screens that need providers beyond the database build their own
/// [ProviderScope] around this - `Override` is not exported by
/// flutter_riverpod, so an overrides list can only be written inline where
/// ProviderScope infers its type.
Widget testShell(Widget child) {
  return MaterialApp(
    locale: const Locale('ar'),
    theme: nouriTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

/// Wraps [child] in the app's real theme, locale and delegates, with the
/// database overridden for tests.
Widget testApp({
  required Widget child,
  required NouriDatabase db,
}) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: testShell(child),
  );
}
