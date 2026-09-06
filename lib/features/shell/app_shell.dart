import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/nouri_colors.dart';
import '../athkar/athkar_screen.dart';
import '../finance/finance_screen.dart';
import '../home/home_screen.dart';
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
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            AthkarScreen(),
            ReportsScreen(),
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
