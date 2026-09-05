import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/home/daily_items.dart';

void main() {
  test('there are exactly nine daily religious items', () {
    // 5 prayers + morning athkar + evening athkar + tasbeeh + Qur'an wird
    expect(kDailyItemTotal, 9);
  });

  test('counts logged prayers and completed wird items', () {
    final c = DailyItems.count(
      loggedPrayers: 3,
      morningAthkarDone: true,
      eveningAthkarDone: false,
      tasbeehDone: true,
      quranWirdDone: false,
    );
    expect(c.done, 5);
    expect(c.total, 9);
  });

  test('a day with nothing logged is zero, never negative', () {
    final c = DailyItems.count(
      loggedPrayers: 0,
      morningAthkarDone: false,
      eveningAthkarDone: false,
      tasbeehDone: false,
      quranWirdDone: false,
    );
    expect(c.done, 0);
    expect(c.fraction, 0.0);
  });

  test('a full day is exactly complete', () {
    final c = DailyItems.count(
      loggedPrayers: 5,
      morningAthkarDone: true,
      eveningAthkarDone: true,
      tasbeehDone: true,
      quranWirdDone: true,
    );
    expect(c.done, 9);
    expect(c.fraction, 1.0);
    expect(c.isComplete, isTrue);
  });

  test('fraction is clamped even if more is somehow logged', () {
    final c = DailyItems.count(
      loggedPrayers: 7,
      morningAthkarDone: true,
      eveningAthkarDone: true,
      tasbeehDone: true,
      quranWirdDone: true,
    );
    expect(c.fraction, 1.0);
  });

  group('greetingFor', () {
    test('morning, day and night each get their own line', () {
      expect(greetingFor(DateTime(2026, 9, 5, 6)), 'صباح الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 11)), 'صباح الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 14)), 'مساء الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 20)), 'مساء الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 2)), 'ليلة طيبة');
    });

    test('the boundaries are exact', () {
      expect(greetingFor(DateTime(2026, 9, 5, 5)), 'صباح الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 12)), 'مساء الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 23)), 'ليلة طيبة');
    });

    test('greetings never scold, whatever the hour', () {
      for (var h = 0; h < 24; h++) {
        final g = greetingFor(DateTime(2026, 9, 5, h));
        expect(g, isNotEmpty);
        for (final w in ['فاتتك', 'ضيعت', 'فشل']) {
          expect(g.contains(w), isFalse);
        }
      }
    });
  });

  group('nouriProgressLine', () {
    test('an untouched day opens the door rather than judging', () {
      final line = nouriProgressLine(const DailyItemCount(0, 9));
      expect(line, isNotEmpty);
      expect(line.contains('فاتتك'), isFalse);
    });

    test('a finished day is acknowledged', () {
      final line = nouriProgressLine(const DailyItemCount(9, 9));
      expect(line, isNotEmpty);
    });

    test('every line uses Arabic-Indic digits only', () {
      for (var done = 0; done <= 9; done++) {
        final line = nouriProgressLine(DailyItemCount(done, 9));
        expect(RegExp(r'[0-9]').hasMatch(line), isFalse,
            reason: 'done=$done produced "$line"');
      }
    });
  });
}
