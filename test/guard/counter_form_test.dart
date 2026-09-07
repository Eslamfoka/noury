import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Counters read left-to-right even in an RTL layout, so «٠ / ٣» renders with
/// the numbers swapped and says *three of zero*. The app has one correct form
/// for this — «٠ من ٣» — used by the athkar stepper, the workout progress
/// line, the challenge cards and the water card. This test keeps the wrong one
/// from creeping back.
///
/// A guard rather than a widget test on purpose: the failure is a *reading*,
/// not a rendering, and no assertion about pixels would catch it. What can be
/// checked is that the app only ever builds the form that reads correctly.
void main() {
  /// A "x / y" counter built for display: a slash with a space either side,
  /// inside a string that is interpolating values.
  ///
  /// Deliberately narrow. A bare `/` is division, a path, or a comment; it is
  /// the spaced slash between two interpolated values that is the counter.
  final counterSlash = RegExp(r"'[^']*\$\{?\w[^']*\s/\s\$\{?\w[^']*'");

  test('no user-facing counter uses the slash form', () {
    final offenders = <String>[];

    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;

      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (counterSlash.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}  ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'these read backwards in RTL — use «\$done من \$total»:\n'
          '${offenders.join('\n')}',
    );
  });

  test('the pattern actually matches the form it is meant to catch', () {
    // Guards the test above: a regex that matched nothing would make this
    // check vacuously pass forever.
    expect(counterSlash.hasMatch(r"toArabicDigits('$done / $total')"), isTrue);
    expect(
      counterSlash.hasMatch(r"'${formatMoney(a)} / ${formatMoney(b)}'"),
      isTrue,
    );
  });

  test('it does not fire on things that are not counters', () {
    expect(counterSlash.hasMatch("final path = 'assets/athkar/\$name.json';"),
        isFalse);
    expect(counterSlash.hasMatch('final half = total / 2;'), isFalse);
    expect(counterSlash.hasMatch("// heavy / light"), isFalse);
  });
}
