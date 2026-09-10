import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/core/theme/nouri_theme.dart';

void main() {
  test('palette matches the approved design tokens exactly', () {
    expect(NouriColors.background.toARGB32(), 0xFF0E2A3B);
    expect(NouriColors.surface.toARGB32(), 0xFF16384C);
    expect(NouriColors.surfaceActive.toARGB32(), 0xFF1B4763);
    expect(NouriColors.border.toARGB32(), 0xFF2C6486);
    expect(NouriColors.gold.toARGB32(), 0xFFD9A73E);
    expect(NouriColors.text.toARGB32(), 0xFFEAF2F5);
    expect(NouriColors.muted.toARGB32(), 0xFF8FB3C4);
    expect(NouriColors.success.toARGB32(), 0xFF5DCAA5);
    expect(NouriColors.attention.toARGB32(), 0xFFE8955A);
  });

  test('theme uses Cairo for interface text and the navy background', () {
    final theme = nouriTheme();
    expect(theme.scaffoldBackgroundColor, NouriColors.background);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Cairo');
  });

  test('religious text style uses Amiri with generous line height', () {
    expect(NouriText.dhikr.fontFamily, 'Amiri');
    expect(NouriText.dhikr.height, greaterThanOrEqualTo(1.9));
  });

  test('palette contains no red', () {
    for (final c in NouriColors.all) {
      final isRed = c.r * 255 > 200 && c.g * 255 < 90 && c.b * 255 < 90;
      expect(isRed, isFalse, reason: 'Nouri never shows a failure red: $c');
    }
  });

  test('cairo() carries the weight on the variable wght axis', () {
    // Cairo is a variable font: without an explicit FontVariation the engine
    // renders the default instance and "bold" silently comes out regular.
    final bold = cairo(size: 14, weight: FontWeight.w700);
    expect(bold.fontFamily, 'Cairo');
    expect(bold.fontWeight, FontWeight.w700);
    expect(bold.fontVariations, contains(const FontVariation('wght', 700)));

    final regular = cairo(size: 14);
    expect(regular.fontVariations, contains(const FontVariation('wght', 400)));
  });

  test('every theme text style carries its wght variation', () {
    final t = nouriTheme().textTheme;
    for (final style in [t.titleLarge!, t.bodyMedium!, t.bodySmall!]) {
      expect(style.fontVariations, isNotEmpty,
          reason:
              'a Cairo style without fontVariations renders at default weight');
    }
  });
}
