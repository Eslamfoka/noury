import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_channels_ids.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/finance/budget_categories.dart';
import 'package:nouri/features/finance/budget_nudge.dart';
import 'package:nouri/features/finance/financial_month.dart';

import '../../support/fake_notification_gateway.dart';

/// §5.4: "Gentle budget alerts: when a category nears its limit, notify softly
/// (not an alarm) so month-end isn't a surprise."
///
/// `BudgetStatus` already computed all of this — `isOver`, `isAheadOfPace`,
/// `pacedAllowance` — and its own comment says "this is what makes an alert
/// useful rather than alarming". The numbers were on screen and nothing was
/// ever sent. This is the missing half.
void main() {
  /// A cycle running the 25th to the 24th, so "day 4" and "day 18" are easy
  /// to state.
  final month = FinancialMonth.containing(
    DateTime(2026, 9, 8),
    startDay: 25,
  );

  DateTime dayOfCycle(int n) => DateTime(
        month.start.year,
        month.start.month,
        month.start.day + (n - 1),
      );

  BudgetStatus status({
    required int limit,
    required int spent,
    required int onDay,
  }) =>
      BudgetStatus(
        limit: limit,
        spent: spent,
        month: month,
        now: dayOfCycle(onDay),
      );

  test('a category comfortably inside its budget says nothing', () {
    final note = budgetNudgeFor({
      BudgetCategory.food: status(limit: 1000, spent: 100, onDay: 15),
    });
    expect(note, isNull);
  });

  test('sixty per cent on day four is worth one quiet note', () {
    // BudgetStatus.pacedAllowance's own words: "spending 60% of the food
    // budget is fine on day 18 and worth noticing on day 4".
    final note = budgetNudgeFor({
      BudgetCategory.food: status(limit: 1000, spent: 600, onDay: 4),
    });
    expect(note, isNotNull);
    expect(note, contains('أكل وشرب'));
  });

  test('the same sixty per cent on day eighteen says nothing', () {
    final note = budgetNudgeFor({
      BudgetCategory.food: status(limit: 1000, spent: 600, onDay: 18),
    });
    expect(note, isNull, reason: 'the same number, a different point in the month');
  });

  test('three stretched categories are one note, not three', () {
    // Three separate notifications about money in one evening is nagging.
    final note = budgetNudgeFor({
      BudgetCategory.food: status(limit: 1000, spent: 600, onDay: 4),
      BudgetCategory.transport: status(limit: 1000, spent: 600, onDay: 4),
      BudgetCategory.personal: status(limit: 1000, spent: 600, onDay: 4),
    });
    expect(note, isNotNull);
    expect('\n'.allMatches(note!), isEmpty, reason: 'one line, one note');
  });

  test('a category with no budget set is not judged', () {
    // A limit of zero means "not budgeted", not "you have overspent by
    // everything you have spent".
    final note = budgetNudgeFor({
      BudgetCategory.personal: status(limit: 0, spent: 5000, onDay: 4),
    });
    expect(note, isNull);
  });

  test('over the limit is named, and still not scolded', () {
    final note = budgetNudgeFor({
      BudgetCategory.food: status(limit: 1000, spent: 1400, onDay: 20),
    });
    expect(note, isNotNull);
    for (final word in ['فشل', 'إسراف', 'مبذر', 'غلط', 'لازم']) {
      expect(note!.contains(word), isFalse, reason: 'found «$word» in «$note»');
    }
  });

  test('it states the category, so the note is actionable', () {
    final note = budgetNudgeFor({
      BudgetCategory.transport: status(limit: 1000, spent: 1400, onDay: 20),
    });
    expect(note, contains('مواصلات'));
  });

  test('nothing budgeted at all says nothing', () {
    expect(budgetNudgeFor(const {}), isNull);
  });

  group('in the alarm window', () {
    late FakeNotificationGateway gateway;
    late RollingWindowScheduler scheduler;
    final now = DateTime(2026, 9, 5, 6, 0);

    const base = SchedulingConfig(
      geo: GeoConfig.kuwaitCity,
      iqamaOffsets: {
        'fajr': 20,
        'dhuhr': 15,
        'asr': 15,
        'maghrib': 10,
        'isha': 15,
      },
    );

    setUp(() {
      gateway = FakeNotificationGateway();
      scheduler = RollingWindowScheduler(
        gateway: gateway,
        prayerTimes: const PrayerTimesService(),
        clock: () => now,
      );
    });

    test('nothing to say arms nothing', () async {
      await scheduler.rearm(base);
      expect(gateway.ofSlot(NotificationSlot.budgetNudge), isEmpty);
    });

    test('something to say arms it over two days, not the fortnight',
        () async {
      // Budget state is not knowable a fortnight ahead the way a prayer time
      // is, so arming it across the window would put stale numbers in front
      // of the user eleven days running.
      await scheduler.rearm(base.copyWith(budgetNote: 'أكل وشرب ماشية أسرع'));
      expect(gateway.ofSlot(NotificationSlot.budgetNudge).length,
          kBudgetNudgeDays);
    });

    test('it arrives in the evening, not the morning', () async {
      // A note about yesterday's total, before the day has started, is
      // information with nothing to do about it.
      await scheduler.rearm(base.copyWith(budgetNote: 'حاجة'));
      for (final n in gateway.ofSlot(NotificationSlot.budgetNudge)) {
        expect(n.when.hour, kBudgetNudgeHour);
      }
    });

    test('it is soft — not the adhan channel', () async {
      // "Notify softly (not an alarm)", in the brief's own words.
      await scheduler.rearm(base.copyWith(budgetNote: 'حاجة'));
      for (final n in gateway.ofSlot(NotificationSlot.budgetNudge)) {
        expect(n.channelId, isNot(channelAdhan));
        expect(n.channelId, isNot(channelIqama));
      }
    });

    test('it carries the wording it was given, not a rewritten one', () async {
      const note = 'مواصلات ماشية أسرع من الشهر. لسه فيه وقت تظبطها.';
      await scheduler.rearm(base.copyWith(budgetNote: note));
      expect(gateway.ofSlot(NotificationSlot.budgetNudge).first.body, note);
    });
  });

  test('charity is never flagged for being ahead of pace', () {
    // Giving early is not overspending, and a nudge that read as "slow down
    // on the صدقة" would be the app saying something it has no business
    // saying.
    final note = budgetNudgeFor({
      BudgetCategory.charity: status(limit: 1000, spent: 900, onDay: 3),
    });
    expect(note, isNull);
  });
}
