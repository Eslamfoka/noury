import '../../features/fasting/sunnah_fasting.dart';
import '../time/geo_config.dart';
import '../time/prayer_times_service.dart';
import 'follow_up_plan.dart';
import 'notification_channels_ids.dart';
import 'notification_gateway.dart';
import 'notification_slot.dart';

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

class SchedulingConfig {
  const SchedulingConfig({
    required this.geo,
    required this.iqamaOffsets,
    this.notifyAdhan = true,
    this.notifyIqama = true,
    this.notifyAthkar = true,
    this.notifyWird = true,
    this.notifyFasting = true,
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
      final date = today.add(Duration(days: i));
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
            channel: channelAdhan,
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
