import '../../features/fasting/sunnah_fasting.dart';
import '../../features/finance/budget_nudge.dart';
import '../../features/planner/daily_tasks.dart';
import '../../features/planner/day_planner.dart';
import '../../features/planner/shift.dart';
import '../../features/prayers/qiyam.dart';
import '../../features/water/water_plan.dart';
import '../time/geo_config.dart';
import '../time/prayer_times_service.dart';
import 'follow_up_plan.dart';
import 'adhan_sounds.dart';
import 'notification_channels_ids.dart';
import 'notification_gateway.dart';
import 'notification_slot.dart';
import 'task_alarm_ids.dart';
import 'task_alarm_plan.dart';
import 'task_alert.dart';

/// How many days of alarms are kept armed at any time.
///
/// Fourteen, measured rather than guessed. A day of *core* alarms costs 14
/// (five adhan, five iqama, three athkar, one wird), so this arms 196.
/// Follow-ups are armed over the shorter [kFollowUpWindowDays] and add 33, for
/// 229 — comfortably inside Android's ~500 pending-alarm cap, with room for
/// the user to keep every channel on.
///
/// The window exists so the adhan survives the app going unopened. Exact
/// alarms live in AlarmManager and fire without the app running at all, so a
/// longer window is the most reliable form of that guarantee — more reliable
/// than a background top-up task, which aggressive OEM power managers (HONOR
/// among the worst) routinely kill. See docs/setup.md for why the spec's
/// workmanager top-up was not added.
const kWindowDays = 14;

/// How many days of follow-up questions are armed.
///
/// Much shorter than [kWindowDays], and deliberately so. The adhan has to
/// survive a fortnight of the app going unopened — that is the whole point of
/// the window. A follow-up does not: "did you pray asr?" is only worth asking
/// of someone still using the app, and eleven days of unanswered questions
/// waiting in the shade is exactly the nagging the brief rules out.
///
/// It is also what keeps the alarm count honest. Arming every slot for a
/// fortnight would cost 350; splitting the windows costs 229
/// (14 x 14 core alarms + 3 x 11 follow-ups), well inside Android's ~500 cap.
const kFollowUpWindowDays = 3;

/// How many days the budget note is armed over.
///
/// Two. Budget state is not knowable ahead the way a prayer time is, so this
/// is armed from the numbers as they stand at re-arm time. One day would miss
/// anyone who opens Nouri after 20:00 — the slot would already have passed —
/// and three would start showing figures old enough to be wrong.
const kBudgetNudgeDays = 2;

/// How many days of **task** alarms are armed.
///
/// Three, at the user's own request: *"for personal tasks I prefer a short
/// rolling window — today + next 2-3 days only. Every time I open the app it
/// re-arms new task alarms for that short window and cancels old ones."*
///
/// It is also what the alarm budget allows. The adhan needs a fortnight
/// because it must survive the app going unopened; a nudge to walk eleven days
/// from now is worth nothing to anyone and would cost ~110 alarms out of
/// Android's ~500, which the adhan has first call on. Ten tasks over three days
/// costs about thirty.
const kTaskAlarmWindowDays = 3;

class SchedulingConfig {
  const SchedulingConfig({
    required this.geo,
    required this.iqamaOffsets,
    this.notifyAdhan = true,
    this.notifyIqama = true,
    this.notifyAthkar = true,
    this.notifyWird = true,
    this.notifyFasting = true,
    this.notifyWater = true,
    this.notifyQiyam = false,
    this.notifyTasks = true,
    this.completedTaskIds = const {},
    this.shift = ShiftType.morning,
    this.budgetNote,
    this.budgetNudgeHour = kBudgetNudgeHour,
    this.fastingDays = const {},
    this.hijriOffsetDays = 0,
    this.fastingEveHour = 20,
    this.morningAthkarHour = 7,
    this.sleepAthkarHour = 22,
    this.quranWirdHour = 17,
    this.dailySummaryHour = 22,
  });

  final GeoConfig geo;
  final Map<String, int> iqamaOffsets;
  final bool notifyAdhan;
  final bool notifyIqama;
  final bool notifyAthkar;
  final bool notifyWird;

  /// Whether to offer the sunnah fasts the evening before.
  final bool notifyFasting;

  /// Whether to nudge the user to drink after each prayer.
  final bool notifyWater;

  /// Whether the planned day announces itself, task by task.
  ///
  /// On by default: it is the point of the feature — *"i don't need to open
  /// the app to know what i have to do"*.
  final bool notifyTasks;

  /// The task ids the user has already done **today**, derived from the logs
  /// they were already keeping.
  ///
  /// Only today's: nothing is done on a day that has not happened, so this is
  /// applied to the first day of the window and no other. Read outside the
  /// scheduler for the same reason `fastingDays` and `budgetNote` are — the
  /// scheduler knows nothing about the database.
  final Set<String> completedTaskIds;

  /// Whether to offer قيام الليل in the last third of the night.
  ///
  /// **Off unless the user turns it on.** Waking someone at two in the morning
  /// for a voluntary prayer is not something an app should decide for them.
  final bool notifyQiyam;

  /// One quiet line about a budget running ahead of the month, or null when
  /// there is nothing to say — which is most days.
  ///
  /// Passed in already worded rather than computed here, for the same reason
  /// `fastingDays` is: the scheduler stays pure and knows nothing about the
  /// database. `budgetNudgeFor` decides whether there is anything to say.
  final String? budgetNote;

  /// The hour the budget note arrives.
  final int budgetNudgeHour;

  /// The shift the user is currently on.
  ///
  /// Only قيام uses it: on a night shift the whole last third is duty time,
  /// so there is nothing to offer.
  final ShiftType shift;

  /// The days the user has said they are fasting, as midnight-local dates.
  ///
  /// Passed in rather than looked up: the scheduler is pure, and it is the
  /// user's own marking — Nouri never infers a fast, because guessing wrong
  /// means telling a fasting person to drink at noon.
  final Set<DateTime> fastingDays;

  /// The same nudge the Home header uses, so the fasting days can never
  /// disagree with the Hijri date shown on screen.
  final int hijriOffsetDays;

  /// When the evening-before offer goes out. 20:00 by default: late enough to
  /// be after work, early enough to still be an evening.
  final int fastingEveHour;

  final int morningAthkarHour;
  final int sleepAthkarHour;
  final int quranWirdHour;

  /// When the end-of-day review offers to catch up anything unlogged.
  final int dailySummaryHour;

  SchedulingConfig copyWith({
    GeoConfig? geo,
    Map<String, int>? iqamaOffsets,
    bool? notifyAdhan,
    bool? notifyIqama,
    bool? notifyAthkar,
    bool? notifyWird,
    bool? notifyFasting,
    bool? notifyWater,
    bool? notifyQiyam,
    bool? notifyTasks,
    Set<String>? completedTaskIds,
    ShiftType? shift,
    String? budgetNote,
    int? budgetNudgeHour,
    Set<DateTime>? fastingDays,
    int? hijriOffsetDays,
    int? fastingEveHour,
    int? morningAthkarHour,
    int? sleepAthkarHour,
    int? quranWirdHour,
    int? dailySummaryHour,
  }) =>
      SchedulingConfig(
        geo: geo ?? this.geo,
        iqamaOffsets: iqamaOffsets ?? this.iqamaOffsets,
        notifyAdhan: notifyAdhan ?? this.notifyAdhan,
        notifyIqama: notifyIqama ?? this.notifyIqama,
        notifyAthkar: notifyAthkar ?? this.notifyAthkar,
        notifyWird: notifyWird ?? this.notifyWird,
        notifyFasting: notifyFasting ?? this.notifyFasting,
        notifyWater: notifyWater ?? this.notifyWater,
        notifyQiyam: notifyQiyam ?? this.notifyQiyam,
        notifyTasks: notifyTasks ?? this.notifyTasks,
        completedTaskIds: completedTaskIds ?? this.completedTaskIds,
        shift: shift ?? this.shift,
        budgetNote: budgetNote ?? this.budgetNote,
        budgetNudgeHour: budgetNudgeHour ?? this.budgetNudgeHour,
        fastingDays: fastingDays ?? this.fastingDays,
        hijriOffsetDays: hijriOffsetDays ?? this.hijriOffsetDays,
        fastingEveHour: fastingEveHour ?? this.fastingEveHour,
        morningAthkarHour: morningAthkarHour ?? this.morningAthkarHour,
        sleepAthkarHour: sleepAthkarHour ?? this.sleepAthkarHour,
        quranWirdHour: quranWirdHour ?? this.quranWirdHour,
        dailySummaryHour: dailySummaryHour ?? this.dailySummaryHour,
      );
}

/// Rebuilds the entire alarm window from scratch on every call.
///
/// Cheap — about 260 alarms — and it makes re-arming trivially correct: there
/// is no incremental state to get wrong after a reboot, a settings change, or
/// a fortnight with the app unopened. Combined with deterministic IDs, running
/// this twice is indistinguishable from running it once.
class RollingWindowScheduler {
  RollingWindowScheduler({
    required this.gateway,
    required this.prayerTimes,
    required this.clock,
  });

  final NotificationGateway gateway;
  final PrayerTimesService prayerTimes;
  final DateTime Function() clock;

  static const _adhanSlots = {
    'fajr': NotificationSlot.adhanFajr,
    'dhuhr': NotificationSlot.adhanDhuhr,
    'asr': NotificationSlot.adhanAsr,
    'maghrib': NotificationSlot.adhanMaghrib,
    'isha': NotificationSlot.adhanIsha,
  };

  static const _iqamaSlots = {
    'fajr': NotificationSlot.iqamaFajr,
    'dhuhr': NotificationSlot.iqamaDhuhr,
    'asr': NotificationSlot.iqamaAsr,
    'maghrib': NotificationSlot.iqamaMaghrib,
    'isha': NotificationSlot.iqamaIsha,
  };

  static const _followUpSlots = {
    'fajr': NotificationSlot.followUpFajr,
    'dhuhr': NotificationSlot.followUpDhuhr,
    'asr': NotificationSlot.followUpAsr,
    'maghrib': NotificationSlot.followUpMaghrib,
    'isha': NotificationSlot.followUpIsha,
  };

  static const _followUp2Slots = {
    'fajr': NotificationSlot.followUp2Fajr,
    'dhuhr': NotificationSlot.followUp2Dhuhr,
    'asr': NotificationSlot.followUp2Asr,
    'maghrib': NotificationSlot.followUp2Maghrib,
    'isha': NotificationSlot.followUp2Isha,
  };

  static const _arabicNames = {
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  /// Evening athkar are tied to maghrib, not to a clock hour, because sunset
  /// moves by nearly two hours across the year.
  static const _eveningAthkarBeforeMaghrib = Duration(minutes: 45);

  Future<void> rearm(SchedulingConfig cfg) async {
    // Not cancelAll: reminders are scheduled outside this window, at ids from
    // kOutOfWindowIdBase upward, and a settings change must not delete them.
    // For a device carrying only window alarms this is identical to the
    // cancelAll it replaces -- there is nothing at or above the base to spare.
    await gateway.cancelAllBelow(kOutOfWindowIdBase);

    final now = clock();
    final today = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < kWindowDays; i++) {
      // Constructed, never offset. On the autumn night the clocks go back,
      // `today.add(Duration(days: 1))` from midnight lands at 23:00 the *same*
      // day — so the loop would arm that day twice and never reach the far end
      // of the fortnight, quietly losing a day of adhan once a year.
      final date = DateTime(today.year, today.month, today.day + i);
      final times = prayerTimes.forDate(date, cfg.geo);

      for (final slot in times.ordered) {
        final name = _arabicNames[slot.name]!;

        if (cfg.notifyAdhan) {
          await _put(
            date,
            _adhanSlots[slot.name]!,
            slot.time,
            now,
            title: name,
            body: 'حان الآن موعد صلاة $name',
            // Each prayer's own channel, so five different recitations are
            // possible and so silencing one does not silence the rest.
            channel: adhanChannelFor(slot.name),
            payload: 'prayer:${slot.name}',
          );

          // Asked after the prayer window has actually closed, never at the
          // adhan. Timing comes from followUpsFor, which starts from iqama
          // rather than adhan and leaves room for the prayer itself.
          if (i < kFollowUpWindowDays) {
            final asks = followUpsFor(
              slot: slot,
              iqama: iqamaFor(slot, cfg.iqamaOffsets),
              nextAdhan: times.next(slot.time)?.time,
            );

            // A question, never an accusation - and it carries the action
            // that logs the prayer straight from the shade.
            await _put(
              date,
              _followUpSlots[slot.name]!,
              asks.first,
              now,
              title: 'نوري',
              body: 'صليت $name؟',
              channel: channelGeneral,
              payload: 'log:${slot.name}',
            );

            final second = asks.second;
            if (second != null) {
              // Worded differently from the first. Repeating a question
              // verbatim an hour later reads as a machine, not a companion.
              await _put(
                date,
                _followUp2Slots[slot.name]!,
                second,
                now,
                title: 'نوري',
                body: 'لسه $name مش متسجلة — صليتها؟',
                channel: channelGeneral,
                payload: 'log:${slot.name}',
              );
            }
          }
        }

        if (cfg.notifyIqama) {
          await _put(
            date,
            _iqamaSlots[slot.name]!,
            iqamaFor(slot, cfg.iqamaOffsets),
            now,
            title: 'الإقامة',
            body: 'إقامة صلاة $name',
            channel: channelIqama,
            payload: 'prayer:${slot.name}',
          );
        }
      }

      if (cfg.notifyAthkar) {
        await _put(
          date,
          NotificationSlot.morningAthkar,
          _at(date, cfg.morningAthkarHour),
          now,
          title: 'أذكار الصباح',
          body: 'وقت أذكار الصباح — خمس دقايق بس',
          channel: channelAthkar,
          payload: 'athkar:morning',
        );

        await _put(
          date,
          NotificationSlot.eveningAthkar,
          times.maghrib.subtract(_eveningAthkarBeforeMaghrib),
          now,
          title: 'أذكار المساء',
          body: 'قرب المغرب — وقت أذكار المسا',
          channel: channelAthkar,
          payload: 'athkar:evening',
        );

        await _put(
          date,
          NotificationSlot.sleepAthkar,
          _at(date, cfg.sleepAthkarHour),
          now,
          title: 'أذكار النوم',
          body: 'قبل ما تنام، خد أذكار النوم',
          channel: channelAthkar,
          payload: 'athkar:sleep',
        );
      }

      if (cfg.notifyWird) {
        await _put(
          date,
          NotificationSlot.quranWird,
          _at(date, cfg.quranWirdHour),
          now,
          title: 'ورد القرآن',
          body: 'ورد النهاردة — ربع من مصحفك',
          channel: channelWird,
          payload: 'quran',
        );
      }

      // قيام الليل, in the last third of the night that *starts* on this
      // date — so it needs tomorrow's fajr as well as tonight's isha. Armed
      // across the full window like the adhan rather than the short one: it
      // is a standing invitation, not a question about something recent.
      if (cfg.notifyQiyam) {
        final tomorrow = DateTime(date.year, date.month, date.day + 1);
        final at = qiyamTimeFor(
          isha: times.isha,
          fajrTomorrow: prayerTimes.forDate(tomorrow, cfg.geo).fajr,
          shift: cfg.shift,
        );
        if (at != null) {
          await _put(
            date,
            NotificationSlot.qiyam,
            at,
            now,
            title: qiyamTitle,
            body: qiyamBody,
            channel: channelAthkar,
            payload: 'qiyam',
          );
        }
      }

      // The evening before a sunnah fast, so the offer arrives while there is
      // still a night to decide in. Asked about *tomorrow*, which is why it
      // looks a day ahead rather than at the day it is scheduled on.
      if (cfg.notifyFasting) {
        final tomorrow = DateTime(date.year, date.month, date.day + 1);
        final fast = sunnahFastFor(tomorrow,
            hijriOffsetDays: cfg.hijriOffsetDays);
        if (fast != null) {
          await _put(
            date,
            NotificationSlot.fastingEve,
            _at(date, cfg.fastingEveHour),
            now,
            title: 'صيام بكرة؟',
            body: fastingEveBody(fast),
            channel: channelGeneral,
            payload: 'fasting',
          );
        }
      }

      // Water, riding the prayers. Five times a day the user already stops
      // what they are doing, so this costs no new interruption — and on a day
      // they have said they are fasting, the daytime ones are simply absent.
      // Only over the short window, for the same reason the follow-ups are.
      // A nudge to drink twelve days from now is worth nothing to anyone, and
      // arming it for a fortnight would cost 70 alarms out of a budget of
      // ~500 that the adhan has first call on.
      if (cfg.notifyWater && i < kFollowUpWindowDays) {
        final fastingToday = cfg.fastingDays.contains(date);
        final slots = <NotificationSlot>[
          NotificationSlot.waterFajr,
          NotificationSlot.waterDhuhr,
          NotificationSlot.waterAsr,
          NotificationSlot.waterMaghrib,
          NotificationSlot.waterIsha,
        ];

        for (var p = 0; p < times.ordered.length; p++) {
          final at = times.ordered[p].time.add(const Duration(minutes: 25));
          if (!waterReminderAllowed(
            at: at,
            fastingToday: fastingToday,
            fajr: times.fajr,
            maghrib: times.maghrib,
          )) {
            continue;
          }

          await _put(
            date,
            slots[p],
            at,
            now,
            title: 'مياه',
            body: waterReminderBody(
              afterFast: fastingToday && !at.isBefore(times.maghrib),
            ),
            channel: channelGeneral,
            payload: 'water',
          );
        }
      }

      // A quiet line about a budget running ahead of the month.
      //
      // Unlike the adhan, budget state is not knowable a fortnight ahead — it
      // depends on what gets spent — so this is armed over two days only, from
      // the numbers as they stand at re-arm time. Today alone would miss
      // anyone who opens Nouri in the evening, since the 20:00 slot would
      // already have passed; three days would start putting stale figures in
      // front of the user. Every launch re-arms and overwrites both.
      if (cfg.budgetNote != null && i < kBudgetNudgeDays) {
        await _put(
          date,
          NotificationSlot.budgetNudge,
          _at(date, cfg.budgetNudgeHour),
          now,
          title: 'الميزانية',
          body: cfg.budgetNote!,
          channel: channelGeneral,
          payload: 'finance',
        );
      }

      // The planned day, announcing itself. Each task at the time `planDay`
      // gave it, on its own channel so it is recognisable by ear, and with
      // the «عملتها؟» that follows the ones worth asking about.
      //
      // Short window, by the user's own instruction and by the alarm budget:
      // see kTaskAlarmWindowDays. Ids come from their own range rather than
      // from a day/slot pair, exactly as reminders do, so the slot below is
      // only a label.
      if (cfg.notifyTasks && i < kTaskAlarmWindowDays) {
        final plan = planDay(
          date: date,
          shift: ShiftPattern.forType(cfg.shift),
          prayers: times,
          tasks: dailyTasksFor(
            date: date,
            shift: ShiftPattern.forType(cfg.shift),
          ),
        );

        for (final alert in taskAlertsFor(plan)) {
          // Already done. Nouri does not ring to demand something it can see
          // in the user's own log, and it does not ask «عملتها؟» about a
          // question the log has already answered — that is nagging rather
          // than helping. Today only: nothing is done on a day that has not
          // happened yet.
          if (i == 0 && cfg.completedTaskIds.contains(alert.taskId)) continue;

          final id = taskAlarmId(date, alert.taskId);
          if (id == null) continue;

          await _putRaw(
            id: id,
            slot: NotificationSlot.taskAlert,
            when: alert.when,
            now: now,
            title: alert.kind.title,
            body: alert.kind.body,
            channel: alert.kind.channelId,
            payload: 'task:${alert.taskId}',
          );

          final ask = alert.askAt;
          final askId = taskAlarmId(date, alert.taskId, ask: true);
          if (ask != null && askId != null) {
            await _putRaw(
              id: askId,
              slot: NotificationSlot.taskFollowUp,
              when: ask,
              now: now,
              title: alert.kind.title,
              body: alert.kind.followUpQuestion!,
              // The soft channel, whatever the task's own sound is: a question
              // should not arrive at the same volume as the summons.
              channel: TaskAlertKind.followUp.channelId,
              payload: 'taskask:${alert.taskId}',
            );
          }
        }
      }

      // The end-of-day review. Worded so it reads correctly whether or not
      // anything is outstanding: the alarm is set days ahead and cannot know,
      // and a fixed «you missed prayers» would be wrong on a complete day.
      // The sheet it opens says «كل صلوات النهاردة متسجلة» when there is
      // nothing to do.
      if (cfg.notifyAdhan && i < kFollowUpWindowDays) {
        await _put(
          date,
          NotificationSlot.dailySummary,
          _at(date, cfg.dailySummaryHour),
          now,
          title: 'نوري',
          body: 'تحب نراجع صلوات النهاردة سوا؟',
          channel: channelGeneral,
          payload: 'review:daily',
        );
      }
    }
  }

  /// Schedules with an **explicit** id rather than one derived from a slot.
  ///
  /// Task alarms and reminders both live outside the day/slot numbering, so
  /// the slot they carry is only a label. Everything else about [_put] holds,
  /// including never scheduling into the past.
  Future<void> _putRaw({
    required int id,
    required NotificationSlot slot,
    required DateTime when,
    required DateTime now,
    required String title,
    required String body,
    required String channel,
    String? payload,
  }) async {
    if (!when.isAfter(now)) return;

    await gateway.schedule(ScheduledNotification(
      id: id,
      slot: slot,
      when: when,
      title: title,
      body: body,
      channelId: channel,
      payload: payload,
    ));
  }

  DateTime _at(DateTime date, int hour) =>
      DateTime(date.year, date.month, date.day, hour);

  Future<void> _put(
    DateTime date,
    NotificationSlot slot,
    DateTime when,
    DateTime now, {
    required String title,
    required String body,
    required String channel,
    String? payload,
  }) async {
    // Today's already-passed times are simply skipped. Scheduling into the
    // past would fire a burst of notifications the moment the app opens.
    if (!when.isAfter(now)) return;

    await gateway.schedule(ScheduledNotification(
      id: notificationIdFor(date, slot),
      slot: slot,
      when: when,
      title: title,
      body: body,
      channelId: channel,
      payload: payload,
    ));
  }
}
