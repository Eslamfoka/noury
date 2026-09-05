import 'package:flutter/material.dart';
import 'nouri_colors.dart';

abstract final class NouriRadius {
  static const card = 15.0;
  static const chip = 20.0;
}

/// Builds a Cairo text style.
///
/// Cairo ships from Google Fonts as a **variable font only** (`wght`, `slnt`).
/// Setting `fontWeight` alone selects the file but renders its default
/// instance, so bold would silently come out regular. The `wght` axis has to be
/// driven explicitly. This helper is the only sanctioned way to build a Cairo
/// style — never construct one by hand.
TextStyle cairo({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = NouriColors.text,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'Cairo',
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    height: height,
  );
}

abstract final class NouriText {
  /// Athkar and Qur'an text only — never interface chrome. Amiri ships static
  /// Regular and Bold, so it needs no variation axis.
  static const dhikr = TextStyle(
    fontFamily: 'Amiri',
    fontSize: 21,
    height: 2.0,
    color: NouriColors.text,
  );

  /// The big tasbeeh number.
  static final counter = cairo(size: 46, weight: FontWeight.w700, height: 1.0);
}

ThemeData nouriTheme() {
  const scheme = ColorScheme.dark(
    primary: NouriColors.gold,
    surface: NouriColors.surface,
    onSurface: NouriColors.text,
    secondary: NouriColors.success,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NouriColors.background,
    fontFamily: 'Cairo',
    cardTheme: const CardThemeData(
      color: NouriColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    textTheme: TextTheme(
      titleLarge: cairo(size: 19, weight: FontWeight.w700),
      bodyMedium: cairo(size: 14),
      bodySmall: cairo(size: 12, color: NouriColors.muted),
    ),
  );
}
