import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/l10n/app_localizations.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/notification_status.dart';
import 'core/theme/nouri_colors.dart';
import 'core/theme/nouri_theme.dart';

/// The root widget.
///
/// Arabic is the default locale and RTL the default direction — not a mode the
/// user switches into. English exists as an alternative, never as the baseline.
class NouriApp extends StatelessWidget {
  const NouriApp({super.key, this.notifications});

  /// Null in widget tests, which have no platform channels.
  final NotificationService? notifications;

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
      home: _TemporaryHome(notifications: notifications),
    );
  }
}

/// Placeholder until Task 9 replaces it with the five-tab shell.
///
/// It exists now so Task 8's device check has something to drive: it shows the
/// live notification status and can fire a test notification.
class _TemporaryHome extends StatefulWidget {
  const _TemporaryHome({this.notifications});

  final NotificationService? notifications;

  @override
  State<_TemporaryHome> createState() => _TemporaryHomeState();
}

class _TemporaryHomeState extends State<_TemporaryHome> {
  NotificationStatus? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await widget.notifications?.readStatus();
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = _status;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: NouriColors.surfaceActive,
                    shape: BoxShape.circle,
                    border: Border.all(color: NouriColors.gold, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'نوري',
                    style: TextStyle(
                      color: NouriColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.appName,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 24),
                if (s != null) ...[
                  _StatusRow(label: 'الإشعارات مفعّلة', ok: s.notificationsEnabled),
                  _StatusRow(
                      label: 'التنبيهات الدقيقة مسموحة', ok: s.exactAlarmsAllowed),
                  _StatusRow(
                      label: 'مستثنى من توفير البطارية', ok: !s.batteryOptimised),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: () async {
                          await widget.notifications
                              ?.requestNotificationPermission();
                          await _refresh();
                        },
                        child: const Text('اسمح بالإشعارات'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          await widget.notifications
                              ?.requestExactAlarmPermission();
                          await _refresh();
                        },
                        child: const Text('التنبيهات الدقيقة'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          await widget.notifications?.requestBatteryExemption();
                          await _refresh();
                        },
                        child: const Text('البطارية'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            widget.notifications?.sendTestNotification(),
                        child: const Text('إرسال إشعار تجريبي'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              // Never red: an ungranted permission is something to fix, not a
              // failure to be scolded for.
              color: ok ? NouriColors.success : NouriColors.attention,
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: NouriColors.text, fontSize: 14)),
          ],
        ),
      );
}
