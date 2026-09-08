import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/phone/phone_budget.dart';

/// §5.5: "Phone/social time: Nouri reserves a fixed slot and notifies if
/// exceeded (the user wants a hard-ish cap here)."
void main() {
  const budget = PhoneBudget(cap: Duration(minutes: 60));

  group('the cap', () {
    test('a short sitting is comfortably inside it', () {
      expect(budget.stateFor(const Duration(minutes: 20)),
          PhoneBudgetState.within);
    });

    test('most of the way through is worth saying so', () {
      expect(budget.stateFor(const Duration(minutes: 50)),
          PhoneBudgetState.close);
    });

    test('the cap is a line, not a wall — passing it is reported', () {
      expect(
          budget.stateFor(const Duration(minutes: 75)), PhoneBudgetState.over);
    });

    test('exactly at the cap is not yet over it', () {
      expect(budget.stateFor(const Duration(minutes: 60)),
          isNot(PhoneBudgetState.over));
    });

    test('a long day does not overflow the bar', () {
      expect(budget.fractionOf(const Duration(hours: 5)), 1.0);
    });

    test('a cap of zero does not divide by it', () {
      const none = PhoneBudget(cap: Duration.zero);
      expect(none.fractionOf(const Duration(minutes: 30)), 0);
    });
  });

  group('what it says', () {
    test('the counter states both numbers, in Arabic digits', () {
      expect(budget.counterFor(const Duration(minutes: 20)), contains('٢٠'));
      expect(budget.counterFor(const Duration(minutes: 20)), contains('٦٠'));
    });

    test('the counter reads «من», never a slash', () {
      // «٢٠ / ٦٠» reverses in RTL and says sixty of twenty. Held app-wide by
      // counter_form_test; stated here too because this is a new counter.
      expect(budget.counterFor(const Duration(minutes: 20)), contains('من'));
      expect(budget.counterFor(const Duration(minutes: 20)),
          isNot(contains('/')));
    });

    test('the counter stays short enough for a card corner', () {
      // It overflowed the header row by 32px when it was a sentence.
      expect(budget.counterFor(const Duration(minutes: 995)).length,
          lessThan(16));
    });

    test('being over is stated and never scolded', () {
      final note = budget.noteFor(const Duration(minutes: 95));
      for (final word in ['فاتتك', 'ضيعت', 'فشل', 'كسلان', 'مدمن', 'بطّل']) {
        expect(note.contains(word), isFalse,
            reason: 'found «$word» in «$note»');
      }
    });

    test('each state says something different', () {
      final notes = {
        budget.noteFor(const Duration(minutes: 10)),
        budget.noteFor(const Duration(minutes: 50)),
        budget.noteFor(const Duration(minutes: 95)),
      };
      expect(notes, hasLength(3));
    });
  });

  group('the log', () {
    late NouriDatabase db;

    setUp(() => db = NouriDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('two sittings in a day add up — the cap is on the day', () async {
      await db.phoneDao.log(date: DateTime(2026, 9, 8), minutes: 20);
      await db.phoneDao.log(date: DateTime(2026, 9, 8), minutes: 25);
      expect(await db.phoneDao.minutesOn(DateTime(2026, 9, 8)), 45);
    });

    test("yesterday's phone time is not today's", () async {
      await db.phoneDao.log(date: DateTime(2026, 9, 7), minutes: 90);
      expect(await db.phoneDao.minutesOn(DateTime(2026, 9, 8)), 0);
    });

    test('a day with nothing is zero, not an error', () async {
      expect(await db.phoneDao.minutesOn(DateTime(2026, 9, 8)), 0);
    });

    test('a sitting logged in the evening lands on that day', () async {
      await db.phoneDao.log(date: DateTime(2026, 9, 8, 23, 40), minutes: 15);
      expect(await db.phoneDao.minutesOn(DateTime(2026, 9, 8)), 15);
    });

    test('a logged sitting can be taken back', () async {
      final id =
          await db.phoneDao.log(date: DateTime(2026, 9, 8), minutes: 30);
      await db.phoneDao.delete(id);
      expect(await db.phoneDao.minutesOn(DateTime(2026, 9, 8)), 0);
    });

    test('between spans whole days at both ends', () async {
      await db.phoneDao.log(date: DateTime(2026, 9, 6), minutes: 10);
      await db.phoneDao.log(date: DateTime(2026, 9, 8), minutes: 10);
      final rows = await db.phoneDao
          .between(DateTime(2026, 9, 6), DateTime(2026, 9, 8));
      expect(rows, hasLength(2));
    });

    test('the cap arrives at sixty minutes', () async {
      // The hour §5.5 already names for calls, applied to the other thing it
      // asks Nouri to reserve.
      expect((await db.settingsDao.get()).phoneCapMinutes, 60);
    });
  });
}
