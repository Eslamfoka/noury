import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/notifications/notification_route.dart';
import '../../core/notifications/pending_route_provider.dart';
import '../../core/theme/nouri_colors.dart';
import '../athkar/athkar_screen.dart';
import '../body/body_screen.dart';
import '../finance/finance_screen.dart';
import '../home/home_providers.dart';
import '../home/home_screen.dart';
import '../prayers/daily_review_sheet.dart';
import '../prayers/notification_log_flow.dart';
import '../reminders/calendar_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';

/// The five-tab shell.
///
/// Tab order is fixed and matches the approved design:
/// النهاردة · الأذكار · التقارير · المالية · الإعدادات
///
/// IndexedStack rather than a rebuild-on-switch: the tasbeeh counter and the
/// athkar stepper keep their in-progress state when the user glances at
/// another tab and comes back.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  bool _handling = false;

  static const _tabForAthkar = 1;
  static const _tabForBody = 3;

  // Six destinations is one past Material's recommended five. The three
  // pillars each need a home and none of them is optional, so the crowding is
  // deliberate rather than accidental -- worth revisiting alongside the Slice 2
  // structure, where الأذكار arguably belongs inside the religious pillar
  // rather than beside it.

  @override
  void initState() {
    super.initState();
    // A tap that launched the app cold is already waiting by the time the
    // shell mounts, so drain once here as well as on later changes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  /// Acts on a tapped notification, then clears it.
  ///
  /// Clearing matters: without it, every rebuild would reopen the same sheet,
  /// and the user could never get back to the app.
  Future<void> _drain() async {
    if (_handling || !mounted) return;
    final route = ref.read(pendingNotificationRouteProvider);
    if (route == null) return;

    _handling = true;
    ref.read(pendingNotificationRouteProvider.notifier).clear();
    try {
      switch (route) {
        case LogPrayerRoute(:final prayer):
          await logPrayerFromNotification(context, ref, prayer);
        case DailyReviewRoute():
          if (mounted) await showDailyReviewSheet(context);
        case PrayerRoute():
          if (mounted) setState(() => _index = 0);
        case AthkarRoute():
          if (mounted) setState(() => _index = _tabForAthkar);
        case QuranRoute():
          if (mounted) setState(() => _index = 0);
        case WaterRoute():
          if (mounted) setState(() => _index = _tabForBody);
        case FastingRoute():
          // Fasting lives in the physical pillar, per the brief.
          if (mounted) setState(() => _index = _tabForBody);
        case ReminderRoute(:final id):
          // Open the calendar on the reminder's own day. The row is read
          // fresh rather than trusted from the payload: the reminder may have
          // been moved to another day since the alarm was armed.
          final row = await ref
              .read(databaseProvider)
              .reminderDao
              .all()
              .then((rows) => rows.where((r) => r.id == id).firstOrNull);
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CalendarScreen(initialDay: row?.onDate),
            ),
          );
      }
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    ref.listen(pendingNotificationRouteProvider, (_, next) {
      if (next != null) _drain();
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            AthkarScreen(),
            ReportsScreen(),
            BodyScreen(),
            FinanceScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: NouriColors.surface,
          indicatorColor: NouriColors.surfaceActive,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 10.5,
              fontFamily: 'Cairo',
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: states.contains(WidgetState.selected)
                  ? NouriColors.gold
                  : NouriColors.muted,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 22,
              color: states.contains(WidgetState.selected)
                  ? NouriColors.gold
                  : NouriColors.muted,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          height: 66,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.nightlight_round_outlined),
              selectedIcon: const Icon(Icons.nightlight_round),
              label: l.tabToday,
            ),
            NavigationDestination(
              icon: const Icon(Icons.circle_outlined),
              selectedIcon: const Icon(Icons.brightness_7),
              label: l.tabAthkar,
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: l.tabReports,
            ),
            NavigationDestination(
              icon: const Icon(Icons.favorite_outline),
              selectedIcon: const Icon(Icons.favorite),
              label: l.tabBody,
            ),
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: l.tabFinance,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: l.tabSettings,
            ),
          ],
        ),
      ),
    );
  }
}
