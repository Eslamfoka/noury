import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/notifications/task_alert.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/prayers/qiyam.dart';

import '../../support/fake_notification_gateway.dart';

/// The point of nineteen sounds, in the user's own words:
///
///   «from the sound i know what this task is»
///
/// Two ways that promise breaks, and both were live on the phone before this
/// file existed:
///
/// **A thing announced twice.** Slice 5 gave the athkar and the wird their own
/// alarms off the day plan, but the Slice-1 reminders for the same four things
/// were left armed beside them — on the old shared channel, at a *different*
/// time, with the default system tone. Two rings a day for one task, neither
/// matching what المهام showed. `task_alarm_plan.dart` already refuses to do
/// this for prayers and says why; this states it for everything else.
///
/// **A sound nothing can play.** Seven of the nineteen channels were created
/// at startup, shipped their tone in the APK, sat in the user's system
/// notification settings — and nothing ever fired on them, because the thing
/// they were made for was still going out on `general_v1`.
void main() {
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

  /// Everything Nouri can say, said — so an unreachable channel shows up as
  /// one that never appears rather than as one this config forgot to enable.
  final everything = base.copyWith(
    notifyQiyam: true,
    budgetNote: 'الميزانية سابقاك شوية',
  );

  // Day 6 is inside the three-day task-alarm window from the frozen 5 Sep
  // "now", so both paths would want it. That is the overlap the duplicate
  // lived in.
  group('nothing is announced twice', () {
    for (final title in ['أذكار الصباح', 'أذكار المساء', 'أذكار النوم']) {
      test('$title rings once a day', () async {
        await scheduler.rearm(base);
        final tomorrow = gateway.scheduled
            .where((n) => n.title == title && n.when.day == 6)
            .toList();
        expect(tomorrow, hasLength(1),
            reason: 'two alarms for one task: '
                '${tomorrow.map((n) => '${n.channelId}@${n.when}')}');
      });
    }

    test('ورد القرآن rings once a day', () async {
      await scheduler.rearm(base);
      final tomorrow = gateway.scheduled
          .where((n) => n.title == 'ورد القرآن' && n.when.day == 6)
          .toList();
      expect(tomorrow, hasLength(1),
          reason: '${tomorrow.map((n) => '${n.channelId}@${n.when}')}');
    });

    test('and the one that rings is the one المهام draws', () async {
      // The task alert takes its time from `planDay` — the same plan المهام
      // lists and Home draws. The Slice-1 reminder took its own from a fixed
      // settings hour, so whichever fired first disagreed with the screen.
      await scheduler.rearm(base);
      final athkar = gateway.scheduled
          .singleWhere((n) => n.title == 'أذكار الصباح' && n.when.day == 6);
      expect(athkar.channelId, TaskAlertKind.athkarMorning.channelId);
      expect(athkar.payload, 'task:morning-athkar');
    });
  });

  test('past the task window the plain reminder stands in, alone', () async {
    // The task alarms reach three days; these reach fourteen. Gating them on
    // `notifyTasks` alone would have cut the athkar and the wird to three
    // days for anyone who did not open Nouri over a long weekend — a quiet
    // loss of a fortnight's cover, traded for a duplicate that is not even
    // there that far out.
    await scheduler.rearm(base);
    final far = gateway.scheduled
        .where((n) => n.title == 'أذكار الصباح' && n.when.day == 12)
        .toList();
    expect(far, hasLength(1), reason: 'one, and only one, on day 12');
    expect(far.single.payload, 'athkar:morning',
        reason: 'the old path is the one still standing that far out');

    final wird = gateway.scheduled
        .where((n) => n.title == 'ورد القرآن' && n.when.day == 12)
        .toList();
    expect(wird, hasLength(1));
  });

  test('turning the task alarms off brings the plain reminders back',
      () async {
    // The old path is not deleted — it is what someone who wants the athkar
    // announced without the whole day announcing itself still gets.
    await scheduler.rearm(base.copyWith(notifyTasks: false));
    final athkar =
        gateway.scheduled.where((n) => n.title == 'أذكار الصباح').toList();
    expect(athkar, isNotEmpty);
    expect(athkar.first.payload, 'athkar:morning');
  });

  test('every bundled sound is one something can actually play', () async {
    await scheduler.rearm(everything);
    final used = gateway.scheduled.map((n) => n.channelId).toSet();

    // Reminders are armed by `ReminderScheduler`, out of the window's id
    // range entirely, so the window cannot be asked about them. Covered by
    // reminder_scheduler_test.
    const elsewhere = {TaskAlertKind.reminder};

    // The planner does not place a workout yet — البدن → تمارين البيت is
    // opened by hand. `alertKindForTaskId` already carries this note. When
    // the planner learns to place one, this exemption goes.
    const notPlannedYet = {TaskAlertKind.workout};

    for (final kind in TaskAlertKind.values) {
      if (elsewhere.contains(kind) || notPlannedYet.contains(kind)) continue;
      expect(used, contains(kind.channelId),
          reason: '${kind.name} ships a sound in the APK and creates a '
              'channel in the user\'s settings that nothing ever fires on');
    }
  });

  test('the sounds that were orphaned are on their own channels now',
      () async {
    await scheduler.rearm(everything);

    String channelOf(String title) => gateway.scheduled
        .firstWhere((n) => n.title == title,
            orElse: () => throw StateError('nothing titled «$title»'))
        .channelId;

    expect(channelOf('الإقامة'), TaskAlertKind.iqama.channelId);
    expect(channelOf('مياه'), TaskAlertKind.water.channelId);
    expect(channelOf('الميزانية'), TaskAlertKind.budget.channelId);
    expect(channelOf('صيام بكرة؟'), TaskAlertKind.fasting.channelId);
    expect(channelOf(qiyamTitle), TaskAlertKind.qiyam.channelId);
  });

  test('the prayer follow-up keeps the quiet general channel', () async {
    // «صليت الظهر؟» is a question, not a summons. It has always been the soft
    // one and stays that way — the review alarm below is the loud end of the
    // same argument and it is deliberate that they differ.
    await scheduler.rearm(base);
    final ask = gateway.scheduled.firstWhere((n) => n.body.startsWith('صليت'));
    expect(ask.channelId, 'general_v1');
  });
}
