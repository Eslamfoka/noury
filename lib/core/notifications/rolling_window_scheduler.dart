import '../time/geo_config.dart';
import '../time/prayer_times_service.dart';
import 'notification_channels_ids.dart';
import 'notification_gateway.dart';
import 'notification_slot.dart';

/// How many days of alarms are kept armed at any time.
///
/// Seven is comfortably inside Android's ~500 pending-alarm cap (this uses
/// about 100) and long enough that the app can go a week unopened without the
/// adhan going quiet.
const kWindowDays = 7;

class SchedulingConfig {
  const SchedulingConfig({
    required this.geo,
    required this.iqamaOffsets,
    this.notifyAdhan = true,
    this.notifyIqama = true,
    this.notifyAthkar = true,
    this.notifyWird = true,
    this.morningAthkarHour = 7,
    this.sleepAthkarHour = 22,
    this.quranWirdHour = 17,
  });

  final GeoConfig geo;
  final Map<String, int> iqamaOffsets;
  final bool notifyAdhan;
  final bool notifyIqama;
  final bool notifyAthkar;
  final bool notifyWird;
  final int morningAthkarHour;
  final int sleepAthkarHour;
  final int quranWirdHour;

  SchedulingConfig copyWith({
    GeoConfig? geo,
    Map<String, int>? iqamaOffsets,
    bool? notifyAdhan,
    bool? notifyIqama,
    bool? notifyAthkar,
    bool? notifyWird,
    int? morningAthkarHour,
    int? sleepAthkarHour,
    int? quranWirdHour,
  }) =>
      SchedulingConfig(
        geo: geo ?? this.geo,
        iqamaOffsets: iqamaOffsets ?? this.iqamaOffsets,
        notifyAdhan: notifyAdhan ?? this.notifyAdhan,
        notifyIqama: notifyIqama ?? this.notifyIqama,
        notifyAthkar: notifyAthkar ?? this.notifyAthkar,
        notifyWird: notifyWird ?? this.notifyWird,
        morningAthkarHour: morningAthkarHour ?? this.morningAthkarHour,
        sleepAthkarHour: sleepAthkarHour ?? this.sleepAthkarHour,
        quranWirdHour: quranWirdHour ?? this.quranWirdHour,
      );
}

/// Rebuilds the entire alarm window from scratch on every call.
///
/// Cheap — about 100 alarms — and it makes re-arming trivially correct: there
/// is no incremental state to get wrong after a reboot, a settings change, or
/// a week with the app unopened. Combined with deterministic IDs, running this
/// twice is indistinguishable from running it once.
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

  static const _arabicNames = {
    'fajr': 'الفجر',
    'dhuhr': 'الظهر',
    'asr': 'العصر',
    'maghrib': 'المغرب',
    'isha': 'العشاء',
  };

  /// How long after the adhan the gentle follow-up asks whether you prayed.
  static const _followUpDelay = Duration(minutes: 25);

  /// Evening athkar are tied to maghrib, not to a clock hour, because sunset
  /// moves by nearly two hours across the year.
  static const _eveningAthkarBeforeMaghrib = Duration(minutes: 45);

  Future<void> rearm(SchedulingConfig cfg) async {
    await gateway.cancelAll();

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

          // A question, never an accusation — and it carries the action that
          // logs the prayer straight from the shade.
          await _put(
            date,
            _followUpSlots[slot.name]!,
            slot.time.add(_followUpDelay),
            now,
            title: 'نوري',
            body: 'صليت $name؟',
            channel: channelGeneral,
            payload: 'log:${slot.name}',
          );
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
