import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dates are constructed, never offset.
///
/// `add(Duration(days: 1))` is twenty-four *absolute* hours, which is the
/// wrong length on a daylight-saving night. Egypt observes DST, and this
/// project has been bitten by exactly this twice already — once moving the
/// adhan by an hour, once breaking the pay cycle. `DateTime(y, m, d + 1)` asks
/// the calendar for a day, which is what every one of these callers means.
///
/// Concretely, on the autumn night the clocks go back:
///
///   DateTime(2026, 10, 30).add(Duration(days: 1))  ->  2026-10-30 23:00
///
/// A loop stepping a day at a time therefore visits the 30th twice and never
/// reaches the far end of its range — the alarm window loses a day, and a
/// seven-day report shows six days and a duplicate.
///
/// A guard rather than a unit test because the failure needs a DST boundary to
/// show, and which boundary depends on the zone the test machine happens to be
/// in. What can be checked everywhere is that the shape that fails is not in
/// the source.
void main() {
  /// Stepping a date by a whole number of days.
  ///
  /// Deliberately narrow: `Duration(days:)` is fine for a *length* — a
  /// fortnight of alarms, a week of history — and only wrong when it is used
  /// to walk from one calendar day to the next.
  final dayStep = RegExp(r'\.(add|subtract)\(\s*(const\s+)?Duration\(days:');

  /// Sites where a whole-day offset is the right thing, with the reason.
  const allowed = <String, String>{
    // Reads as prose about the rule rather than performing it.
    'lib/features/reminders/reminder.dart':
        'the doc comment explaining why this is banned',
  };

  test('no source steps a date with a day offset', () {
    final offenders = <String>[];

    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;

      final normalised = f.path.replaceAll(r'\', '/');
      final lines = f.readAsLinesSync();

      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!dayStep.hasMatch(line)) continue;
        // A line that is only a comment is talking about the rule.
        if (line.trimLeft().startsWith('//')) continue;
        if (allowed.containsKey(normalised)) continue;

        offenders.add('$normalised:${i + 1}  ${line.trim()}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'construct the day instead — DateTime(y, m, d + n):\n'
          '${offenders.join('\n')}',
    );
  });

  test('the pattern matches the shape it is meant to catch', () {
    // Guards the test above: a regex matching nothing would pass forever.
    expect(dayStep.hasMatch('final d = today.add(Duration(days: i));'), isTrue);
    expect(
      dayStep.hasMatch('final from = today.subtract(const Duration(days: 6));'),
      isTrue,
    );
  });

  test('it leaves durations that are genuinely lengths alone', () {
    expect(dayStep.hasMatch('const window = Duration(days: 14);'), isFalse);
    expect(dayStep.hasMatch('at.add(const Duration(minutes: 25))'), isFalse);
    expect(dayStep.hasMatch('expect(d, const Duration(days: 3));'), isFalse);
  });
}
