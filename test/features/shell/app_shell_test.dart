import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/features/shell/app_shell.dart';

import '../../support/harness.dart';

void main() {
  Future<void> pumpShell(WidgetTester tester) async {
    final db = inMemoryDatabase(tester);
    await tester.pumpWidget(testApp(db: db, child: const AppShell()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows five tabs in the approved order', (tester) async {
    await withLargeSurface(tester, () async {
      await pumpShell(tester);
      // Scoped to the nav bar: «النهاردة» legitimately appears twice on
      // screen -- as the tab label and inside the progress ring -- exactly as
      // in the approved design.
      final inNav = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(Text),
      );
      final labels =
          tester.widgetList<Text>(inNav).map((w) => w.data).toList();
      expect(labels, [
        'النهاردة',
        'الأذكار',
        'التقارير',
        'المالية',
        'الإعدادات',
      ]);
    });
  });

  testWidgets('renders right-to-left by default', (tester) async {
    await withLargeSurface(tester, () async {
      await pumpShell(tester);
      expect(
        Directionality.of(tester.element(find.byType(NavigationBar))),
        TextDirection.rtl,
      );
    });
  });

  testWidgets('starts on the Today tab', (tester) async {
    await withLargeSurface(tester, () async {
      await pumpShell(tester);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 0);
    });
  });

  testWidgets('tapping a tab switches to it', (tester) async {
    await withLargeSurface(tester, () async {
      await pumpShell(tester);
      await tester.tap(find.text('الأذكار'));
      await tester.pumpAndSettle();
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 1);
    });
  });

  testWidgets('the finance tab reads as coming soon, never as broken',
      (tester) async {
    await withLargeSurface(tester, () async {
      await pumpShell(tester);
      await tester.tap(find.text('المالية'));
      await tester.pumpAndSettle();

      expect(find.text('قريباً إن شاء الله'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });

  testWidgets('the shell sits on the navy ground', (tester) async {
    await withLargeSurface(tester, () async {
      await pumpShell(tester);
      final ctx = tester.element(find.byType(NavigationBar));
      expect(Theme.of(ctx).scaffoldBackgroundColor, NouriColors.background);
    });
  });

  testWidgets('switching tabs and back preserves the Today tab state',
      (tester) async {
    await withLargeSurface(tester, () async {
      await pumpShell(tester);
      await tester.tap(find.text('الأذكار'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('النهاردة'),
      ));
      await tester.pumpAndSettle();

      // IndexedStack keeps every tab alive, so Home is still built.
      expect(find.text('صلوات اليوم'), findsOneWidget);
    });
  });
}
