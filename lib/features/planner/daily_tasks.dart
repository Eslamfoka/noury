import 'day_plan.dart';
import 'shift.dart';

/// The tasks Nouri plans into an ordinary day.
///
/// Every one comes from the brief, and each carries the weight and anchor that
/// decides where the planner may put it. Prayers are **not** here: rule 6 says
/// they are anchors rather than tasks, and `planDay` places them itself.
///
/// Knowledge time is rule 5's flexible block: reading, skill learning and
/// religious content rotate rather than all appearing every day, so exactly
/// one of them is emitted per day and which one turns on the date. That keeps
/// the promise the brief makes — "one day read, another learn, another listen"
/// — without three items competing for the same evening.
List<PlannedTask> dailyTasksFor({
  required DateTime date,
  required ShiftPattern shift,
  int eatingWindowStartHour = 12,
  bool includeQuranWird = true,
  bool includeWalk = true,
  bool includeCalls = true,
}) {
  final tasks = <PlannedTask>[];

  // --- الديني -------------------------------------------------------------

  tasks.add(const PlannedTask(
    id: 'morning-athkar',
    title: 'أذكار الصباح',
    pillar: TaskPillar.deen,
    weight: TaskWeight.light,
    duration: Duration(minutes: 15),
    // Tied to fajr rather than a clock hour, so it follows the sun through the
    // year instead of drifting away from the prayer it belongs to.
    anchor: PrayerAnchor('fajr', offset: Duration(minutes: 23)),
  ));

  tasks.add(const PlannedTask(
    id: 'evening-athkar',
    title: 'أذكار المساء',
    pillar: TaskPillar.deen,
    weight: TaskWeight.light,
    duration: Duration(minutes: 15),
    anchor: PrayerAnchor('maghrib', offset: Duration(minutes: 16)),
  ));

  tasks.add(const PlannedTask(
    id: 'tasbeeh',
    title: 'تسبيح',
    pillar: TaskPillar.deen,
    weight: TaskWeight.light,
    duration: Duration(minutes: 10),
    // Rides a break at work when there is one; falls back to anywhere light.
    anchor: FlexibleAnchor(preferredBlock: DayBlockKind.work),
  ));

  if (includeQuranWird) {
    tasks.add(const PlannedTask(
      id: 'quran-wird',
      title: 'ورد القرآن — ربع',
      pillar: TaskPillar.deen,
      weight: TaskWeight.heavy,
      duration: Duration(minutes: 25),
      anchor: FlexibleAnchor(preferredBlock: DayBlockKind.afterWork),
    ));
  }

  tasks.add(const PlannedTask(
    id: 'sleep-athkar',
    title: 'أذكار النوم',
    pillar: TaskPillar.deen,
    weight: TaskWeight.light,
    duration: Duration(minutes: 10),
    // Last thing before bed, which is what «أذكار النوم» means. A first-fit
    // search would put them in the first free minute after maghrib — hours
    // early, and before isha.
    anchor: FlexibleAnchor(
      preferredBlock: DayBlockKind.evening,
      preferLatest: true,
    ),
  ));

  // --- البدني -------------------------------------------------------------

  // Meals get a window, not a time. The 16/8 eating window already owns when
  // food is allowed, and a planner that also pinned a clock time to breakfast
  // would be two systems disagreeing about the same meal.
  tasks.add(PlannedTask(
    id: 'first-meal',
    title: 'أول وجبة',
    pillar: TaskPillar.body,
    weight: TaskWeight.light,
    duration: const Duration(minutes: 30),
    anchor: FlexibleAnchor(
      preferredBlock: eatingWindowStartHour < 12
          ? DayBlockKind.morning
          : DayBlockKind.afterWork,
    ),
  ));

  tasks.add(const PlannedTask(
    id: 'last-meal',
    title: 'آخر وجبة',
    pillar: TaskPillar.body,
    weight: TaskWeight.light,
    duration: Duration(minutes: 30),
    anchor: FlexibleAnchor(preferredBlock: DayBlockKind.evening),
    // Not preferLatest: eating immediately before bed is the opposite of what
    // the brief asks for, and the 16/8 window closes long before then.
  ));

  if (includeWalk) {
    tasks.add(const PlannedTask(
      id: 'walk',
      title: 'مشي ٣٠ دقيقة',
      pillar: TaskPillar.body,
      weight: TaskWeight.heavy,
      duration: Duration(minutes: 30),
      anchor: FlexibleAnchor(preferredBlock: DayBlockKind.afterWork),
    ));
  }

  // --- تطوير الذات --------------------------------------------------------

  tasks.add(knowledgeTaskFor(date, shift));

  // --- الوقت والدوام ------------------------------------------------------

  if (includeCalls) {
    tasks.add(PlannedTask(
      id: 'calls',
      title: 'مكالمات',
      // The same pillar the worked example gave it. There is no «وقت» pillar
      // and adding one would ripple through the labels, the reports and their
      // tests for a single task; كلام مع الأهل sits closer to تطوير than to
      // anything else on the list.
      pillar: TaskPillar.mind,
      // An hour on the phone is not a heavy task: it needs no desk and no
      // quiet, which is what «heavy» means to the placer.
      weight: TaskWeight.light,
      duration: const Duration(hours: 1),
      anchor: FlexibleAnchor(preferredBlock: _callsBlockFor(shift)),
    ));
  }

  return tasks;
}

/// Where the hour of calls goes, by shift.
///
/// §5.5: "one hour, placed by shift — after morning/evening shift or before
/// sleep; for the night shift, before duty or during it if there's a chance."
///
/// "During it if there's a chance" is not something Nouri can know, so it
/// takes the half it can: on a night shift the hour goes in the evening,
/// which is the only stretch that is both awake and free before duty starts
/// at 22:00. Nouri never claims the call happened during duty.
DayBlockKind _callsBlockFor(ShiftPattern shift) => switch (shift.type) {
      // Home from 15:30 with the evening still ahead.
      ShiftType.morning => DayBlockKind.afterWork,
      // Home at 22:00; the free hours are the ones before leaving.
      ShiftType.evening => DayBlockKind.evening,
      // Before duty.
      ShiftType.night => DayBlockKind.evening,
      // A loose day; the evening still reads as an evening.
      ShiftType.off => DayBlockKind.evening,
    };

/// The three faces of "knowledge time", rotating by day.
///
/// Rule 5: one flexible block, not three separate items. The rotation is by
/// day-of-year so it is deterministic — the same date always gives the same
/// one, which means a re-plan mid-day cannot silently change what the user was
/// promised this morning.
///
/// The listening one is light and rides the commute; the other two are heavy
/// and need a chair. On a day with no commute the light one simply lands
/// wherever else it fits.
PlannedTask knowledgeTaskFor(DateTime date, ShiftPattern shift) {
  final dayOfYear =
      date.difference(DateTime(date.year, 1, 1)).inDays.abs();

  return switch (dayOfYear % 3) {
    0 => const PlannedTask(
        id: 'knowledge-read',
        title: 'قراءة ٣٠ دقيقة',
        pillar: TaskPillar.mind,
        weight: TaskWeight.heavy,
        duration: Duration(minutes: 30),
        anchor: FlexibleAnchor(preferredBlock: DayBlockKind.evening),
      ),
    1 => const PlannedTask(
        id: 'knowledge-listen',
        title: 'استماع لمحاضرة',
        pillar: TaskPillar.mind,
        weight: TaskWeight.light,
        duration: Duration(minutes: 30),
        anchor: FlexibleAnchor(preferredBlock: DayBlockKind.morning),
      ),
    _ => const PlannedTask(
        id: 'knowledge-skill',
        title: 'تعلّم مهارة',
        pillar: TaskPillar.mind,
        weight: TaskWeight.heavy,
        duration: Duration(minutes: 30),
        anchor: FlexibleAnchor(preferredBlock: DayBlockKind.evening),
      ),
  };
}
