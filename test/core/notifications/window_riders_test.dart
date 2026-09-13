import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/nag_plan.dart';
import 'package:nouri/core/notifications/nag_store.dart';
import 'package:nouri/core/notifications/prayer_silence.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

import '../../support/fake_notification_gateway.dart';

/// The two things that ride on the window's re-arm without being alarms in
/// it: the nag plan «فكّرني تاني» and the prayer silence. Both come from the
/// same pass that arms the adhan and the task alarms, so neither can
/// disagree with them — and both are absent in every other scheduler test,
/// which is the point of their being optional.
void main() {
  final now = DateTime(2026, 9, 13, 6, 0);
  const base = SchedulingConfig(
    geo: GeoConfig.kuwaitCity,
    iqamaOffsets: {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 10, 'isha': 15},
  );

  late FakeNotificationGateway gateway;
  late _Sink sink;
  late _Port port;
  late RollingWindowScheduler scheduler;

  setUp(() {
    gateway = FakeNotificationGateway();
    sink = _Sink();
    port = _Port();
    scheduler = RollingWindowScheduler(
      gateway: gateway,
      prayerTimes: const PrayerTimesService(),
      clock: () => now,
      nagPlans: sink,
      silence: port,
    );
  });

  group('the nag plan', () {
    test('is published from the same days the task alarms were armed from', () async {
      await scheduler.rearm(base.copyWith(nagIntervalMinutes: 10));

      final plan = sink.published!;
      expect(plan.intervalMinutes, 10);
      expect(plan.enabled, isTrue);
      expect(plan.days.keys, ['2026-09-13', '2026-09-14', '2026-09-15'],
          reason: 'the task-alarm window is three days');

      // Every task still ahead has an alarm in the window at the same
      // minute — the promise that a nag and its alarm never disagree. The
      // plan also carries the tasks already past (the morning athkar at
      // 04:35, before this 06:00 clock): the tick needs them to know which
      // task is current, and the window rightly never arms into the past.
      final today = plan.days['2026-09-13']!;
      expect(today.tasks, isNotEmpty);
      expect(today.tasks.where((t) => t.start.isBefore(now)), isNotEmpty);
      for (final t in today.tasks.where((t) => t.start.isAfter(now))) {
        final armed = gateway.scheduled.where(
          (n) => n.payload == 'task:${t.id}' && n.when == t.start,
        );
        expect(armed, isNotEmpty, reason: '${t.id} at ${t.start}');
      }
    });

    test('carries today\'s completions and the switch', () async {
      await scheduler.rearm(base.copyWith(
        nagIntervalMinutes: 15,
        completedTaskIds: {'walk'},
        notifyTasks: false,
      ));
      expect(sink.doneToday, {'walk'});
      expect(sink.today, DateTime(2026, 9, 13));
      expect(sink.published!.enabled, isFalse,
          reason: 'task alarms off means the nag is off too');
      expect(sink.published!.active, isFalse);
    });
  });

  group('the prayer silence', () {
    test('is armed for three days from the same times as the adhan', () async {
      await scheduler.rearm(base.copyWith(
        silenceDuringPrayer: true,
        prayerSilenceMinutes: 10,
      ));

      final windows = port.scheduled!;
      // Five prayers, three days, less today's fajr — its window closed at
      // 05:05, before this 06:00 clock.
      expect(windows, hasLength(14));
      expect(windows.first.prayer, 'dhuhr');

      for (final w in windows) {
        final adhan = gateway.scheduled.where(
          (n) => n.payload == 'prayer:${w.prayer}' && n.when == w.silenceAt,
        );
        expect(adhan, isNotEmpty,
            reason: 'silence at ${w.silenceAt} has no adhan alarm at that minute');
      }

      // Dhuhr: fifteen minutes to iqama, ten for the prayer.
      final dhuhr = windows.firstWhere((w) => w.prayer == 'dhuhr');
      expect(dhuhr.restoreAt.difference(dhuhr.silenceAt), const Duration(minutes: 25));
    });

    test('is cancelled outright when the switch is off', () async {
      await scheduler.rearm(base.copyWith(silenceDuringPrayer: false));
      expect(port.scheduled, isNull);
      expect(port.cancelled, isTrue);
    });
  });

  test('neither rider is touched when neither is wired', () async {
    final plain = RollingWindowScheduler(
      gateway: gateway,
      prayerTimes: const PrayerTimesService(),
      clock: () => now,
    );
    await plain.rearm(base.copyWith(nagIntervalMinutes: 10, silenceDuringPrayer: true));
    expect(gateway.scheduled, isNotEmpty, reason: 'the alarms still arm');
  });
}

class _Sink implements NagPlanSink {
  NagPlan? published;
  DateTime? today;
  Set<String>? doneToday;

  @override
  Future<void> publish(NagPlan plan, {required DateTime today, required Set<String> doneToday}) async {
    published = plan;
    this.today = today;
    this.doneToday = doneToday;
  }
}

class _Port implements PrayerSilencePort {
  List<SilenceWindow>? scheduled;
  bool cancelled = false;

  @override
  Future<void> schedule(List<SilenceWindow> windows) async => scheduled = windows;

  @override
  Future<void> cancelAll() async => cancelled = true;
}
