import 'dart:async';

import 'package:drift/native.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/home/home_providers.dart';

/// Midnight, with the app open.
///
/// The brief's user works night shifts, so having Nouri open as the date
/// changes is not an edge case for him — it is most nights. Every day-scoped
/// provider read `DateTime.now()` once and cached it, so at 00:01 the whole
/// app was still showing yesterday: yesterday's prayer times, yesterday's
/// plan, yesterday's logs, until something else happened to invalidate them.
void main() {
  late StreamController<DateTime> clock;
  late NouriDatabase db;
  late ProviderContainer container;

  setUp(() {
    clock = StreamController<DateTime>.broadcast();
    db = NouriDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      coarseClockProvider.overrideWith((ref) => clock.stream),
    ]);
    addTearDown(() {
      container.dispose();
      clock.close();
      db.close();
    });
  });

  /// Emits a clock reading and lets it propagate.
  ///
  /// A real delay rather than `Duration.zero`: the value crosses a Stream, a
  /// StreamProvider and a derived Provider, and a single microtask is not
  /// enough for all three.
  Future<void> tick(DateTime at) async {
    clock.add(at);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test('the current day holds still through the day', () async {
    final sub = container.listen(currentDayProvider, (_, _) {},
        fireImmediately: true);

    await tick(DateTime(2026, 9, 7, 8, 0));
    expect(sub.read(), DateTime(2026, 9, 7));

    await tick(DateTime(2026, 9, 7, 13, 30));
    await tick(DateTime(2026, 9, 7, 23, 59, 30));
    expect(sub.read(), DateTime(2026, 9, 7),
        reason: 'the day should not change until it does');
  });

  test('and turns over at midnight', () async {
    final seen = <DateTime>[];
    container.listen(currentDayProvider, (_, next) => seen.add(next),
        fireImmediately: true);

    await tick(DateTime(2026, 9, 7, 23, 59, 30));
    await tick(DateTime(2026, 9, 8, 0, 0, 30));

    expect(seen.last, DateTime(2026, 9, 8),
        reason: 'the app was showing yesterday all night');
  });

  test('it changes once a day, not once a tick', () async {
    // A provider that fired every thirty seconds would rebuild every
    // day-scoped query in the app all day long.
    //
    // The subscription has to exist *before* the seeding tick. The clock
    // override is a broadcast stream, which drops anything emitted while
    // nothing is listening, and `currentDayProvider` falls back to
    // `DateTime.now()` until its first event arrives. Seeding first left the
    // provider holding the machine's real date, so this test only asserted
    // anything at all on 7 September 2026 — and failed on the 8th.
    final sub = container.listen(currentDayProvider, (_, _) {},
        fireImmediately: true);
    await tick(DateTime(2026, 9, 7, 9, 0));
    expect(sub.read(), DateTime(2026, 9, 7),
        reason: 'the seeding tick must land before changes are counted');

    var notifications = 0;
    container.listen(currentDayProvider, (_, _) => notifications++);

    for (var minute = 0; minute < 60; minute += 5) {
      await tick(DateTime(2026, 9, 7, 10, minute));
    }
    expect(notifications, 0, reason: 'same day, no change');

    await tick(DateTime(2026, 9, 8, 0, 1));
    expect(notifications, 1);
  });

  test('day-scoped queries follow it over midnight', () async {
    // The thing that actually matters: a log written yesterday must stop
    // being "today's" once the date has turned.
    await db.athkarDao.upsert(
      date: DateTime(2026, 9, 7),
      type: 'morning',
      progress: 17,
      target: 17,
    );

    final sub = container.listen(todayAthkarProvider, (_, _) {},
        fireImmediately: true);

    await tick(DateTime(2026, 9, 7, 22, 0));
    await container.read(todayAthkarProvider.future);
    expect(sub.read().value, isNotNull);
    expect(sub.read().value!.containsKey('morning'), isTrue);

    await tick(DateTime(2026, 9, 8, 0, 1));
    final tomorrow = await container.read(todayAthkarProvider.future);
    expect(tomorrow.containsKey('morning'), isFalse,
        reason: "yesterday's athkar are not today's");
  });
}
