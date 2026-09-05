import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> load(String p) =>
      jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

  Set<String> keys(Map<String, dynamic> m) =>
      m.keys.where((k) => !k.startsWith('@')).toSet();

  test('ar and en define exactly the same message keys', () {
    final ar = load('lib/core/l10n/app_ar.arb');
    final en = load('lib/core/l10n/app_en.arb');
    expect(keys(ar).difference(keys(en)), isEmpty,
        reason: 'keys present in Arabic but missing in English');
    expect(keys(en).difference(keys(ar)), isEmpty,
        reason: 'keys present in English but missing in Arabic');
  });

  test('Arabic is the template locale', () {
    expect(load('lib/core/l10n/app_ar.arb')['@@locale'], 'ar');
  });

  test('no Arabic string contains a western digit', () {
    final ar = load('lib/core/l10n/app_ar.arb');
    for (final e in ar.entries) {
      if (e.key.startsWith('@') || e.value is! String) continue;
      final value = e.value as String;
      if (value.contains('{')) continue; // placeholders are filled at runtime
      expect(RegExp(r'[0-9]').hasMatch(value), isFalse,
          reason: '${e.key} must use Arabic-Indic digits');
    }
  });

  test('no Arabic string uses punishing language', () {
    // The no-blame rule, enforced on the copy itself rather than trusted.
    const forbidden = ['فاتتك', 'ضيعت', 'فشل', 'خسرت', 'إنذار'];
    final ar = load('lib/core/l10n/app_ar.arb');
    for (final e in ar.entries) {
      if (e.key.startsWith('@') || e.value is! String) continue;
      for (final w in forbidden) {
        expect((e.value as String).contains(w), isFalse,
            reason: '${e.key} must never blame the user: "$w"');
      }
    }
  });
}
