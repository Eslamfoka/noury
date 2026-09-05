import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/app.dart';
import 'package:nouri/core/theme/nouri_colors.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NouriApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows five tabs in the approved order', (tester) async {
    await pumpApp(tester);
    expect(find.text('النهاردة'), findsOneWidget);
    expect(find.text('الأذكار'), findsOneWidget);
    expect(find.text('التقارير'), findsOneWidget);
    expect(find.text('المالية'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('renders right-to-left by default', (tester) async {
    await pumpApp(tester);
    expect(
      Directionality.of(tester.element(find.text('النهاردة'))),
      TextDirection.rtl,
    );
  });

  testWidgets('starts on the Today tab', (tester) async {
    await pumpApp(tester);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
  });

  testWidgets('tapping a tab switches to it', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('الأذكار'));
    await tester.pumpAndSettle();
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
  });

  testWidgets('the finance tab reads as coming soon, never as broken',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('المالية'));
    await tester.pumpAndSettle();

    expect(find.text('قريباً إن شاء الله'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.warning), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing,
        reason: 'a placeholder must not look like it is still loading');
  });

  testWidgets('the shell sits on the navy ground', (tester) async {
    await pumpApp(tester);
    final ctx = tester.element(find.byType(NavigationBar));
    expect(Theme.of(ctx).scaffoldBackgroundColor, NouriColors.background);
  });
}
