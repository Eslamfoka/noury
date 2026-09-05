import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n/app_localizations.dart';
import 'core/theme/nouri_theme.dart';

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
      home: const _TemporaryHome(),
    );
  }
}

/// Placeholder until Task 9 replaces it with the five-tab shell.
class _TemporaryHome extends StatelessWidget {
  const _TemporaryHome();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Text(l.appName, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
