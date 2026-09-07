import 'dart:io';
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';

/// Nouri encourages continuation; it never punishes.
///
/// That promise is repeated all over the brief and asserted screen by screen,
/// which is fine until someone adds a screen. These two tests make it
/// structural instead: colour is defined in exactly one file, and that file
/// has nothing red in it. A red anywhere in the app then has to get past a
/// failing test to arrive.
void main() {
  /// The same threshold the per-screen tests use: red clearly dominant.
  ///
  /// `attention` (0xFFE8955A) is deliberately *not* caught. It is the warmest
  /// colour in the palette and marks "worth noticing" — a budget run past, a
  /// prayer not yet logged — which is a different thing from failure.
  bool looksRed(Color c) => c.r > 0.75 && c.g < 0.55 && c.b < 0.55;

  test('the palette contains no red', () {
    final offenders = NouriColors.all.where(looksRed).toList();
    expect(offenders, isEmpty,
        reason: 'Nouri has no failure colour, by design: $offenders');
  });

  test('attention is warm but is not a failure colour', () {
    // Pins the distinction rather than leaving it to a comment: if someone
    // reddens `attention` to make it louder, this is what stops them.
    expect(looksRed(NouriColors.attention), isFalse);
    expect(NouriColors.attention.r, greaterThan(NouriColors.attention.b),
        reason: 'it should still read as warm');
  });

  test('colour is defined only in the palette', () {
    // A raw Color() anywhere else is how a red gets in without touching the
    // palette at all — and how the app stops being one thing.
    final literal = RegExp(r'\bColor\(0x|\bColors\.[a-z]');
    final offenders = <String>[];

    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;

      final normalised = f.path.replaceAll(r'\', '/');
      if (normalised.endsWith('core/theme/nouri_colors.dart')) continue;

      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        // Colors.transparent is absence, not a colour choice.
        if (line.contains('Colors.transparent')) continue;
        if (!literal.hasMatch(line)) continue;
        offenders.add('$normalised:${i + 1}  ${line.trim()}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'use NouriColors — the palette is the whole design:\n'
            '${offenders.join('\n')}');
  });

  test('the pattern catches what it is meant to', () {
    final literal = RegExp(r'\bColor\(0x|\bColors\.[a-z]');
    expect(literal.hasMatch('color: const Color(0xFFFF0000),'), isTrue);
    expect(literal.hasMatch('color: Colors.red,'), isTrue);
    expect(literal.hasMatch('color: NouriColors.gold,'), isFalse);
  });
}
