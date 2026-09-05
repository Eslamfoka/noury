import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/nouri_theme.dart';
import 'features/shell/app_shell.dart';

/// The notification service, injected at startup.
///
/// Overridden in `main()` with the real instance; left null in widget tests,
/// which have no platform channels.
final notificationServiceProvider = Provider<NotificationService?>(
  (ref) => null,
);

/// The root widget.
///
/// Arabic is the default locale and RTL the default direction — not a mode the
/// user switches into. English exists as an alternative, never as the baseline.
class NouriApp extends StatelessWidget {
  const NouriApp({super.key});

  static const supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نوري',
      debugShowCheckedModeBanner: false,
      theme: nouriTheme(),
      locale: const Locale('ar'),
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
