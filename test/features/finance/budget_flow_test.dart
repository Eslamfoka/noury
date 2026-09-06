import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/finance/budget_categories.dart';
import 'package:nouri/features/finance/finance_screen.dart';

import '../../support/harness.dart';

void main() {
  group('money parsing', () {
    test('accepts whole numbers', () {
      expect(parseMoney('12'), 12000);
    });

    test('accepts a decimal point', () {
      expect(parseMoney('12.500'), 12500);
    });

    test('accepts the Arabic decimal separator', () {
      expect(parseMoney('12٫500'), 12500);
    });

    test('accepts Arabic-Indic digits', () {
      expect(parseMoney('١٢٫٥٠٠'), 12500);
    });

    test('pads a short fraction rather than misreading it', () {
      // "12.5" means twelve and a half, not twelve and five fils.
      expect(parseMoney('12.5'), 12500);
      expect(parseMoney('12.05'), 12050);
    });

    test('truncates beyond three decimal places', () {
      expect(parseMoney('12.5009'), 12500);
    });

    test('returns null on nonsense rather than throwing', () {
      // A typo in an amount field is an ordinary event, not an error.
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney('1.2.3'), isNull);
    });

    test('round-trips through the display format', () {
      for (final fils in [0, 500, 12000, 12500, 1234567]) {
        final shown = formatMoney(fils);
        expect(shown, isNotEmpty);
        expect(RegExp(r'[0-9]').hasMatch(shown), isTrue,
            reason: 'amounts stay legible as numerals');
      }
    });

    test('formats fils as a three-place fraction', () {
      expect(formatMoney(12500), contains('12٫500'));
      expect(formatMoney(12000), contains('12٫000'));
    });
  });

  group('finance screen', () {
    late NouriDatabase db;

    Future<void> pumpFinance(WidgetTester t) async {
      await t.pumpWidget(
        testApp(db: db, child: const Scaffold(body: FinanceScreen())),
      );
      await t.pumpAndSettle();
    }

    testWidgets('offers a way to set budgets, not just log spending',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpFinance(t);
        expect(find.text('عدّل الميزانية'), findsOneWidget,
            reason: 'without this the category bars have no limits');
        expect(find.text('سجّل مصروف'), findsOneWidget);
      });
    });

    testWidgets('a logged expense appears against its category', (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await db.financeDao.addExpense(
          date: DateTime.now(),
          category: BudgetCategory.food.name,
          amountFils: 3500,
          note: 'غدا',
        );

        await pumpFinance(t);
        expect(find.text('أكل وشرب'), findsWidgets);
        expect(find.text('غدا'), findsOneWidget);
      });
    });

    testWidgets('spending over a budget is flagged warmly, never in red',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        final now = DateTime.now();

        await db.financeDao.setBudget(
          monthStart: DateTime(now.year, now.month, 1),
          category: BudgetCategory.food.name,
          limitFils: 1000,
        );
        await db.financeDao.addExpense(
          date: now,
          category: BudgetCategory.food.name,
          amountFils: 5000,
        );

        await pumpFinance(t);

        bool isRed(Color? c) =>
            c != null && c.r * 255 > 200 && c.g * 255 < 90 && c.b * 255 < 90;
        final reds = t
            .widgetList<Text>(find.byType(Text))
            .where((w) => isRed(w.style?.color));
        expect(reds, isEmpty, reason: 'over budget is information, not blame');
      });
    });

    testWidgets('states the not-a-financial-adviser position plainly',
        (t) async {
      await withLargeSurface(t, () async {
        db = inMemoryDatabase(t);
        await pumpFinance(t);
        await t.scrollUntilVisible(
          find.textContaining('مش مستشار مالي'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('مش مستشار مالي'), findsOneWidget);
      });
    });
  });
}
