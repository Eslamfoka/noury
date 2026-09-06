import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/finance/budget_categories.dart';
import 'package:nouri/features/finance/finance_screen.dart';

import '../../support/harness.dart';

/// Deleting a logged expense.
///
/// The DAO could already delete, but nothing called it — an amount is typed by
/// hand, and a mistyped figure would otherwise distort every report for the
/// rest of the cycle with no way to correct it.
void main() {
  late NouriDatabase db;

  Future<void> pump(WidgetTester t) async {
    await t.pumpWidget(
      testApp(db: db, child: const Scaffold(body: FinanceScreen())),
    );
    await t.pumpAndSettle();
  }

  // The app is RTL, so DismissDirection.endToStart is a drag toward the
  // right — "end" is the left edge. Dragging left would be startToEnd and
  // does nothing.
  testWidgets('an expense can be swiped away', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.financeDao.addExpense(
        date: DateTime.now(),
        category: BudgetCategory.food.name,
        amountFils: 3500,
        note: 'غدا',
      );

      await pump(t);
      expect(find.text('غدا'), findsOneWidget);

      await t.drag(find.text('غدا'), const Offset(500, 0));
      await t.pumpAndSettle();

      expect(await db.financeDao.expensesBetween(
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now().add(const Duration(days: 1)),
      ), isEmpty);
    });
  });

  testWidgets('deleting offers an undo rather than a confirmation',
      (t) async {
    // A confirmation on every swipe would punish the common case to guard the
    // rare one. An undo keeps the fast path fast and still recovers a slip.
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.financeDao.addExpense(
        date: DateTime.now(),
        category: BudgetCategory.transport.name,
        amountFils: 1500,
      );

      await pump(t);
      await t.drag(find.byType(Dismissible).first, const Offset(500, 0));
      await t.pumpAndSettle();

      expect(find.text('رجّعه'), findsOneWidget);
    });
  });

  testWidgets('undo puts the expense back', (t) async {
    await withLargeSurface(t, () async {
      db = inMemoryDatabase(t);
      await db.financeDao.addExpense(
        date: DateTime.now(),
        category: BudgetCategory.food.name,
        amountFils: 2750,
        note: 'قهوة',
      );

      await pump(t);
      await t.drag(find.text('قهوة'), const Offset(500, 0));
      await t.pumpAndSettle();

      await t.tap(find.text('رجّعه'));
      await t.pumpAndSettle();

      final rows = await db.financeDao.expensesBetween(
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now().add(const Duration(days: 1)),
      );
      expect(rows, hasLength(1));
      expect(rows.single.amountFils, 2750);
      expect(rows.single.note, 'قهوة');
    });
  });
}
