/// The fixed monthly categories from the brief.
///
/// Charity is one of them, not an afterthought: the brief puts it inside the
/// monthly budget as a planned amount rather than whatever happens to be left.
enum BudgetCategory {
  rent,
  food,
  family,
  transport,
  internet,
  personal,
  charity,
  other,
}

extension BudgetCategoryLabel on BudgetCategory {
  String get arabicLabel => switch (this) {
        BudgetCategory.rent => 'السكن',
        BudgetCategory.food => 'أكل وشرب',
        BudgetCategory.family => 'الأهل',
        BudgetCategory.transport => 'مواصلات',
        BudgetCategory.internet => 'إنترنت',
        BudgetCategory.personal => 'مصاريف شخصية',
        BudgetCategory.charity => 'صدقة',
        BudgetCategory.other => 'حاجات تانية',
      };
}

BudgetCategory? categoryFromName(String name) {
  for (final c in BudgetCategory.values) {
    if (c.name == name) return c;
  }
  return null;
}

/// Money is stored as integer fils and only ever formatted for display.
///
/// A double would accumulate rounding error across a month of expenses, and
/// "why is my total off by one fils" is not a bug worth having.
String formatMoney(int fils, {String currency = 'د.ك'}) {
  final whole = fils ~/ 1000;
  final part = (fils % 1000).toString().padLeft(3, '0');
  return '$whole٫$part $currency';
}

/// Parses user input like "12.500" or "12٫5" into fils.
///
/// Returns null rather than throwing: a typo in an amount field is an ordinary
/// event, not an error condition.
int? parseMoney(String input) {
  final normalised = input
      .trim()
      .replaceAll('٫', '.')
      .replaceAll('،', '.')
      .replaceAll(RegExp(r'[٠-٩]'), '')
      .replaceAll(RegExp(r'[^0-9.]'), '');

  // Re-map any Arabic-Indic digits the user typed.
  final arabicMapped = input.trim().replaceAllMapped(
        RegExp(r'[٠-٩]'),
        (m) => (m.group(0)!.codeUnitAt(0) - 0x0660).toString(),
      );
  final source = RegExp(r'[٠-٩]').hasMatch(input)
      ? arabicMapped.replaceAll('٫', '.').replaceAll(RegExp(r'[^0-9.]'), '')
      : normalised;

  if (source.isEmpty) return null;

  final parts = source.split('.');
  if (parts.length > 2) return null;

  final whole = int.tryParse(parts[0].isEmpty ? '0' : parts[0]);
  if (whole == null) return null;

  var fraction = 0;
  if (parts.length == 2 && parts[1].isNotEmpty) {
    final padded = parts[1].padRight(3, '0').substring(0, 3);
    fraction = int.tryParse(padded) ?? 0;
  }

  return whole * 1000 + fraction;
}
