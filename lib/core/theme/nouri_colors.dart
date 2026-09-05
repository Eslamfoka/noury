import 'package:flutter/material.dart';

/// The locked Nouri palette. Calm, spiritual, uncluttered — and deliberately
/// without a failure red: Nouri encourages continuation, it never punishes.
abstract final class NouriColors {
  static const background = Color(0xFF0E2A3B);
  static const surface = Color(0xFF16384C);
  static const surfaceActive = Color(0xFF1B4763);
  static const border = Color(0xFF2C6486);
  static const gold = Color(0xFFD9A73E);
  static const text = Color(0xFFEAF2F5);
  static const muted = Color(0xFF8FB3C4);
  static const success = Color(0xFF5DCAA5);

  /// The warmest colour in the app. Used for "needs attention", never for a
  /// religious action the user simply has not done yet.
  static const attention = Color(0xFFE8955A);

  static const all = <Color>[
    background,
    surface,
    surfaceActive,
    border,
    gold,
    text,
    muted,
    success,
    attention,
  ];
}
