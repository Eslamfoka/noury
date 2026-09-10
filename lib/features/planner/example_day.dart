import '../../core/time/prayer_times_service.dart';
import 'day_plan.dart';
import 'shift.dart';

/// A hand-written day, for previewing the shape of Slice 2.
///
/// **This is a fixture, not a planner.** Every task and time below was chosen
/// by hand in `docs/superpowers/specs/slice2-worked-example.md`; nothing here
/// decides anything. The real anchors — prayers — are passed in so the preview
/// moves with the actual day rather than showing invented times, but the tasks
/// around them are fixed.
///
/// It exists so the block layout can be seen and argued about before the
/// placement algorithm is designed.
DayPlan exampleDayPlan({
  required DateTime date,
  required DailyPrayerTimes prayers,
  ShiftPattern shift = ShiftPattern.morning,
}) {
  DateTime at(int hour, int minute) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  ScheduledTask task({
    required String id,
    required String title,
    required TaskPillar pillar,
    required TaskWeight weight,
    required Duration duration,
    required DateTime start,
    required DayBlockKind block,
  }) =>
      ScheduledTask(
        task: PlannedTask(
          id: id,
          title: title,
          pillar: pillar,
          weight: weight,
          duration: duration,
          anchor: const FlexibleAnchor(),
        ),
        start: start,
        block: block,
      );

  final morning = DayBlock(
    kind: DayBlockKind.morning,
    start: prayers.fajr,
    end: at(7, 0),
    tasks: [
      task(
        id: 'fajr',
        title: 'صلاة الفجر',
        pillar: TaskPillar.deen,
        weight: TaskWeight.heavy,
        duration: const Duration(minutes: 15),
        start: prayers.fajr,
        block: DayBlockKind.morning,
      ),
      task(
        id: 'morning-athkar',
        title: 'أذكار الصباح',
        pillar: TaskPillar.deen,
        weight: TaskWeight.light,
        duration: const Duration(minutes: 10),
        start: prayers.fajr.add(const Duration(minutes: 25)),
        block: DayBlockKind.morning,
      ),
      task(
        id: 'breakfast',
        title: 'فطار',
        pillar: TaskPillar.body,
        weight: TaskWeight.light,
        duration: const Duration(minutes: 20),
        start: at(5, 0),
        block: DayBlockKind.morning,
      ),
      task(
        id: 'commute-lecture',
        title: 'الأتوبيس — استماع لمحاضرة',
        pillar: TaskPillar.mind,
        weight: TaskWeight.light,
        duration: const Duration(minutes: 45),
        start: at(6, 0),
        block: DayBlockKind.morning,
      ),
    ],
  );

  final work = DayBlock(
    kind: DayBlockKind.work,
    start: at(7, 0),
    end: at(14, 0),
    tasks: [
      task(
        id: 'dhuhr',
        title: 'صلاة الظهر — جماعة في الشغل',
        pillar: TaskPillar.deen,
        weight: TaskWeight.heavy,
        duration: const Duration(minutes: 20),
        start: prayers.dhuhr,
        block: DayBlockKind.work,
      ),
      task(
        id: 'tasbeeh-break',
        title: 'تسبيح في البريك',
        pillar: TaskPillar.deen,
        weight: TaskWeight.light,
        duration: const Duration(minutes: 5),
        start: prayers.dhuhr.add(const Duration(minutes: 45)),
        block: DayBlockKind.work,
      ),
    ],
  );

  final afterWork = DayBlock(
    kind: DayBlockKind.afterWork,
    start: at(15, 15),
    end: prayers.maghrib,
    tasks: [
      task(
        id: 'asr',
        title: 'صلاة العصر',
        pillar: TaskPillar.deen,
        weight: TaskWeight.heavy,
        duration: const Duration(minutes: 15),
        start: prayers.asr,
        block: DayBlockKind.afterWork,
      ),
      task(
        id: 'rest',
        title: 'راحة',
        pillar: TaskPillar.body,
        weight: TaskWeight.light,
        duration: const Duration(minutes: 30),
        start: prayers.asr.add(const Duration(minutes: 27)),
        block: DayBlockKind.afterWork,
      ),
      task(
        id: 'walk',
        title: 'مشي ٣٠ دقيقة',
        pillar: TaskPillar.body,
        weight: TaskWeight.heavy,
        duration: const Duration(minutes: 30),
        start: prayers.asr.add(const Duration(minutes: 57)),
        block: DayBlockKind.afterWork,
      ),
      task(
        id: 'quran',
        title: 'ورد القرآن — ربع',
        pillar: TaskPillar.deen,
        weight: TaskWeight.heavy,
        duration: const Duration(minutes: 20),
        start: at(17, 0),
        block: DayBlockKind.afterWork,
      ),
    ],
  );

  final evening = DayBlock(
    kind: DayBlockKind.evening,
    start: prayers.maghrib,
    end: at(22, 0),
    tasks: [
      task(
        id: 'maghrib',
        title: 'صلاة المغرب',
        pillar: TaskPillar.deen,
        weight: TaskWeight.heavy,
        duration: const Duration(minutes: 15),
        start: prayers.maghrib,
        block: DayBlockKind.evening,
      ),
      task(
        id: 'evening-athkar',
        title: 'أذكار المساء',
        pillar: TaskPillar.deen,
        weight: TaskWeight.light,
        duration: const Duration(minutes: 10),
        start: prayers.maghrib.add(const Duration(minutes: 16)),
        block: DayBlockKind.evening,
      ),
      task(
        id: 'dinner',
        title: 'عشا',
        pillar: TaskPillar.body,
        weight: TaskWeight.light,
        duration: const Duration(minutes: 30),
        start: at(19, 0),
        block: DayBlockKind.evening,
      ),
      task(
        id: 'isha',
        title: 'صلاة العشاء',
        pillar: TaskPillar.deen,
        weight: TaskWeight.heavy,
        duration: const Duration(minutes: 15),
        start: prayers.isha,
        block: DayBlockKind.evening,
      ),
      task(
        id: 'reading',
        title: 'قراءة ٣٠ دقيقة',
        pillar: TaskPillar.mind,
        weight: TaskWeight.heavy,
        duration: const Duration(minutes: 30),
        start: at(20, 0),
        block: DayBlockKind.evening,
      ),
      task(
        id: 'calls',
        title: 'مكالمات',
        pillar: TaskPillar.mind,
        weight: TaskWeight.light,
        duration: const Duration(hours: 1),
        start: at(20, 30),
        block: DayBlockKind.evening,
      ),
      task(
        id: 'sleep-athkar',
        title: 'أذكار النوم',
        pillar: TaskPillar.deen,
        weight: TaskWeight.light,
        duration: const Duration(minutes: 10),
        start: at(21, 45),
        block: DayBlockKind.evening,
      ),
    ],
  );

  return DayPlan(
    date: date,
    shift: shift,
    blocks: [morning, work, afterWork, evening],
  );
}
