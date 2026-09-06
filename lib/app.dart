import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/nouri_colors.dart';
import 'core/theme/nouri_theme.dart';
import 'features/home/home_providers.dart';
import 'features/onboarding/permission_flow.dart';
import 'features/settings/settings_screen.dart';
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
      home: const _Root(),
    );
  }
}

/// Shows the permission flow on first launch, then the shell.
///
/// Falls through to the shell whenever settings cannot be read: onboarding is
/// a convenience, never a gate the user can get stuck behind.
class _Root extends ConsumerWidget {
  const _Root();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return settings.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: NouriColors.gold),
        ),
      ),
      error: (_, _) => const AppShell(),
      data: (s) {
        if (s.onboardingComplete) return const AppShell();

        final service = ref.read(notificationServiceProvider);
        return PermissionFlow(
          steps: defaultPermissionSteps(
            requestNotifications: () async =>
                service?.requestNotificationPermission(),
            requestBattery: () async => service?.requestBatteryExemption(),
            requestLocation: () async {
              // Asks for the permission and, if granted, stores the
              // coordinates straight away — so prayer times are right from
              // the first launch rather than after a later visit to Settings.
              await ref.read(settingsControllerProvider).detectLocation();
              ref.invalidate(settingsProvider);
            },
          ),
          onDone: () async {
            await ref
                .read(settingsControllerProvider)
                .markOnboardingComplete();
            ref.invalidate(settingsProvider);
          },
        );
      },
    );
  }
}
