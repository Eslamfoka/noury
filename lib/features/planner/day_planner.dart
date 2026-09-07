import '../../core/time/prayer_times_service.dart';
import 'day_plan.dart';
import 'shift.dart';

/// Turns a shift, a day's prayer times and a task list into a planned day.
///
/// This is the algorithm `docs/superpowers/specs/slice2-worked-example.md`
/// deliberately left absent. The six rules that worked example implies are
/// implemented here in the order they matter, and the six open questions it
/// asked are answered — see `docs/planner-decisions.md` for which answer was
/// taken and why each is reversible.
///
/// Everything is pure. No database, no clock, no providers: a day is a
/// function of its inputs, which is what makes an algorithm this fiddly
/// testable at all.

/// Why a task did not make it into the day.
enum DeferralReason {
  /// No window long enough was left.
  noRoom,

  /// Heavy, and the user was never home and free for long enough.
  needsHomeTime,

  /// Its anchor fell outside the waking day.
  outsideTheDay,
}

class DeferredTask {
  const DeferredTask({required this.task, required this.reason});

  final PlannedTask task;
  final DeferralReason reason;

  /// What Nouri says about it — an explanation, never an accusation.
  ///
  /// The day is *always* told what it dropped. Silently shortening the plan
  /// would be the app quietly deciding something did not matter, which is
  /// exactly the trust the brief is built on not spending.
  String get arabicNote => switch (reason) {
        DeferralReason.noRoom => 'اليوم مليان — ${task.title} أجّلناها',
        DeferralReason.needsHomeTime =>
          '${task.title} محتاجة وقت في البيت، مش لاقيينه النهاردة',
        DeferralReason.outsideTheDay => '${task.title} برّه وقت اليوم',
      };
}

/// Tonight's sleep, sized before anything else is placed.
///
/// [start] is tonight's bedtime and [end] is tomorrow's wake, so the window is
/// always forwards in time. This is deliberately *not* the sleep the user just
/// had: the planner is deciding what to do with the day ahead, and the night
/// at the end of it is the thing that constrains it.
class SleepWindow {
  const SleepWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get length => end.difference(start);
}

/// The hours the user is actually awake and plannable.
///
/// Bounded by this morning's wake and tonight's bedtime. Kept separate from
/// [SleepWindow] because conflating the two is exactly the mistake that made
/// the first version of this file compute a negative night.
class WakingDay {
  const WakingDay({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class PlannerConfig {
  const PlannerConfig({
    this.targetSleep = const Duration(hours: 7),
    this.minimumSleep = const Duration(hours: 6),
    this.breakAfterHeavy = const Duration(minutes: 30),
    this.breakAfterLight = const Duration(minutes: 5),
    this.prayerDuration = const Duration(minutes: 15),
    this.settleAfterHome = const Duration(minutes: 30),
  });

  /// What the brief asks for. Sleep is sized to this and only shrinks toward
  /// [minimumSleep] when the day physically cannot hold it.
  final Duration targetSleep;

  /// The floor. Below this the planner defers tasks instead — the brief's
  /// rule is explicit that sleep is never the thing that gives way.
  final Duration minimumSleep;

  /// Rule 4 of the worked example: breaks scale with the effort just finished.
  /// A heavy task earns a real rest; a light one barely interrupts.
  final Duration breakAfterHeavy;
  final Duration breakAfterLight;

  /// How long a prayer occupies the day. Prayers are anchors rather than
  /// tasks, but they still take time that nothing else may use.
  final Duration prayerDuration;

  /// The gap between walking in the door and being available. Coming home is
  /// not the same as being free, and scheduling a heavy task at the doormat is
  /// how a plan stops being believed.
  final Duration settleAfterHome;
}

/// A stretch of the day that is still free.
///
/// Both edges move. A window is *split* when something is placed in its
/// middle, never advanced past it: sliding the start forward to the end of an
/// 11:46 prayer would silently throw away every free hour before it, which is
/// exactly the bug that made a day off look fuller than a work day.
class _Window {
  _Window({
    required this.start,
    required this.end,
    required this.block,
    required this.allowsHeavy,
  });

  DateTime start;
  DateTime end;
  final DayBlockKind block;

  /// Rule 2: heavy tasks only where the user is home and free. A commute or a
  /// work break is a window, but only a light task may ride it.
  final bool allowsHeavy;

  Duration get remaining => end.difference(start);
}

/// Plans one day.
///
/// **The plan is the whole day, and it does not depend on when you look at
/// it.** There is deliberately no `now`: a plan that changes as the clock
/// moves is not a plan, and two attempts at making one work both did damage.
///
/// Clamping windows to `now` made a flexible task land at "now" and then keep
/// moving — 15:45, 15:55, 16:05 — chasing the clock and never arriving.
/// Filtering *past* prayers out before placing was subtler and worse: a fajr
/// that had already happened stopped consuming its fifteen minutes, so the
/// tasks around it shifted, and the same day planned at noon came out
/// different from the same day planned at dawn.
///
/// So the day is planned once and whole. What is past is still in it, in a
/// block the UI collapses and marks — that is a true statement about the day,
/// and the user can see what it was for.
///
/// **Re-planning around a missed task is not implemented.** The brief asks for
/// it and it is a real feature — move tonight's reading because this morning's
/// was missed — but it is a decision about what to move and what to drop, not
/// a clock parameter. See `docs/planner-decisions.md`.
DayPlan planDay({
  required DateTime date,
  required ShiftPattern shift,
  required DailyPrayerTimes prayers,
  required List<PlannedTask> tasks,
  PlannerConfig config = const PlannerConfig(),
}) {
  final day = DateTime(date.year, date.month, date.day);
  final (sleep, waking) = _sleepAndWaking(day, shift, prayers, config);

  final windows = _windowsFor(
    day: day,
    shift: shift,
    prayers: prayers,
    waking: waking,
    config: config,
  );

  // The blocks' own edges, captured before anything is placed. Reading them
  // back off the windows afterwards would report what is *left* of a block
  // rather than what it is.
  final bounds = <DayBlockKind, (DateTime, DateTime)>{};
  for (final w in windows) {
    final existing = bounds[w.block];
    bounds[w.block] = existing == null
        ? (w.start, w.end)
        : (
            w.start.isBefore(existing.$1) ? w.start : existing.$1,
            w.end.isAfter(existing.$2) ? w.end : existing.$2,
          );
  }

  final placed = <ScheduledTask>[];
  final deferred = <DeferredTask>[];

  // Prayers first. Rule 6: they are anchors, and every other task fits around
  // the holes they leave rather than the other way round.
  for (final slot in prayers.ordered) {
    final at = slot.time;
    if (at.isBefore(waking.start) || !at.isBefore(waking.end)) continue;

    final block = _blockIn(bounds, at) ?? DayBlockKind.morning;
    placed.add(ScheduledTask(
      task: PlannedTask(
        id: 'prayer-${slot.name}',
        title: 'صلاة ${_prayerNames[slot.name] ?? slot.name}',
        pillar: TaskPillar.deen,
        weight: TaskWeight.light,
        duration: config.prayerDuration,
        anchor: PrayerAnchor(slot.name),
      ),
      start: at,
      block: block,
    ));
    _consume(windows, at, config.prayerDuration);
  }

  // Anchored tasks next: they have a time of their own, so they take it before
  // anything flexible is allowed to compete for the same minutes.
  final anchored = tasks.where((t) => t.anchor is! FlexibleAnchor).toList();
  final flexible = tasks.where((t) => t.anchor is FlexibleAnchor).toList()
    // Heavy first. A heavy task fits in fewer places, so letting the light
    // ones settle first would leave nowhere for it to go.
    ..sort((a, b) {
      if (a.weight == b.weight) return 0;
      return a.weight == TaskWeight.heavy ? -1 : 1;
    });

  for (final task in anchored) {
    final at = _anchorTime(task.anchor, day, prayers);
    if (at == null ||
        at.isBefore(waking.start) ||
        !at.isBefore(waking.end)) {
      deferred.add(DeferredTask(
        task: task,
        reason: DeferralReason.outsideTheDay,
      ));
      continue;
    }

    final block = _blockIn(bounds, at);
    if (block == null) {
      deferred.add(
          DeferredTask(task: task, reason: DeferralReason.outsideTheDay));
      continue;
    }

    placed.add(ScheduledTask(task: task, start: at, block: block));
    _consume(windows, at, task.duration + _breakAfter(task, config));
  }

  for (final task in flexible) {
    final anchor = task.anchor as FlexibleAnchor;
    final window = _fittingWindow(
      windows,
      task,
      anchor.preferredBlock,
      latest: anchor.preferLatest,
    );

    if (window == null) {
      deferred.add(DeferredTask(
        task: task,
        reason: task.weight == TaskWeight.heavy
            ? DeferralReason.needsHomeTime
            : DeferralReason.noRoom,
      ));
      continue;
    }

    // A "latest" task sits at the *end* of the window it found, so it lands
    // as close to the edge of the day as it fits.
    final start = anchor.preferLatest
        ? window.end.subtract(task.duration)
        : window.start;
    placed.add(ScheduledTask(task: task, start: start, block: window.block));
    _consume(windows, start, task.duration + _breakAfter(task, config));
  }

  placed.sort((a, b) => a.start.compareTo(b.start));

  final blocks = <DayBlock>[];
  for (final kind in DayBlockKind.values) {
    final edges = bounds[kind];
    if (edges == null) continue;

    blocks.add(DayBlock(
      kind: kind,
      start: edges.$1,
      end: edges.$2,
      tasks: placed.where((t) => t.block == kind).toList(),
    ));
  }

  return DayPlan(
    date: day,
    shift: shift,
    blocks: blocks,
    sleep: sleep,
    deferred: deferred,
  );
}

const _prayerNames = {
  'fajr': 'الفجر',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

/// Rule 1: sleep is sized first, backwards from the *next* wake.
///
/// Returns tonight's sleep and the waking day it bounds. The two are computed
/// together because each defines the other's edge, and computing them apart is
/// how the first version ended up with a night that ran backwards.
(SleepWindow, WakingDay) _sleepAndWaking(
  DateTime day,
  ShiftPattern shift,
  DailyPrayerTimes prayers,
  PlannerConfig config,
) {
  if (shift.type == ShiftType.night) {
    // A night day is genuinely a different shape. The user comes home at
    // 08:00, stays up an hour, and sleeps through the middle of the day — so
    // the sleep is in the *middle* and the waking day is what follows it,
    // running out to the next shift.
    final home = (shift.homeAgain ?? const Clock(8, 0)).on(day);
    final sleepStart = home.add(const Duration(hours: 1));
    final sleepEnd = sleepStart.add(config.targetSleep);
    return (
      SleepWindow(start: sleepStart, end: sleepEnd),
      WakingDay(start: sleepEnd, end: DateTime(day.year, day.month, day.day + 1)),
    );
  }

  // This morning's wake, and the same clock tomorrow — the day is planned
  // between them. A day off has no duty to wake for, so fajr is the anchor
  // that remains; waking for it is the point rather than an imposition.
  final wakeClock = shift.wake;

  // Fajr outranks the shift's wake time. If the shift says 05:00 and fajr is
  // at 04:07, the day starts at fajr — waking for it is the whole point, and a
  // planner that filed fajr as "before the day began" would be describing
  // someone else's day.
  final shiftWake = wakeClock?.on(day);
  final wakeToday = shiftWake == null || prayers.fajr.isBefore(shiftWake)
      ? prayers.fajr
      : shiftWake;
  final wakeTomorrow = wakeClock?.on(DateTime(day.year, day.month, day.day + 1)) ??
      prayers.fajr.add(const Duration(days: 1));

  var bedtime = wakeTomorrow.subtract(config.targetSleep);

  // Bedtime may not land before isha. Praying isha is not optional, and a plan
  // that put the user in bed before it would be wrong about the day.
  final ishaEnd = prayers.isha.add(config.prayerDuration);
  if (bedtime.isBefore(ishaEnd)) {
    bedtime = ishaEnd;
    // Below the floor the planner stops shrinking sleep and defers tasks
    // instead — the brief's rule is that sleep is never what gives way.
    if (wakeTomorrow.difference(bedtime) < config.minimumSleep) {
      bedtime = wakeTomorrow.subtract(config.minimumSleep);
    }
  }

  // A bedtime that has somehow landed before this morning's wake would make
  // the waking day empty. Clamp so the day is at least real.
  if (!bedtime.isAfter(wakeToday)) {
    bedtime = wakeToday.add(const Duration(hours: 1));
  }

  return (
    SleepWindow(start: bedtime, end: wakeTomorrow),
    WakingDay(start: wakeToday, end: bedtime),
  );
}

/// The stretches of the day that can hold anything, in order.
List<_Window> _windowsFor({
  required DateTime day,
  required ShiftPattern shift,
  required DailyPrayerTimes prayers,
  required WakingDay waking,
  required PlannerConfig config,
}) {
  final windows = <_Window>[];

  void add(DateTime start, DateTime end, DayBlockKind block,
      {bool allowsHeavy = true}) {
    // Deliberately *not* clamped to `now`. A window is a stretch of the day,
    // and the day's shape does not change because someone opened the app at
    // two in the afternoon.
    var from = start;
    // Never outside the waking day, whatever the shift's clocks say.
    if (from.isBefore(waking.start)) from = waking.start;
    var to = end;
    if (to.isAfter(waking.end)) to = waking.end;
    if (!from.isBefore(to)) return;
    windows.add(_Window(
      start: from,
      end: to,
      block: block,
      allowsHeavy: allowsHeavy,
    ));
  }

  if (!shift.isWorking) {
    // The day off. Nouri leaves it deliberately loose: the prayers still
    // anchor it and anything the user asked for still lands, but the planner
    // does not invent filler to fill an empty day. Two broad windows, split at
    // maghrib, so the evening still reads as an evening.
    add(waking.start, prayers.maghrib, DayBlockKind.morning);
    add(prayers.maghrib, waking.end, DayBlockKind.evening);
    return windows;
  }

  if (shift.type == ShiftType.night) {
    // Awake from sleep's end until work; home again the next morning. Only the
    // waking evening is plannable, and it is one long stretch at home.
    final work = (shift.workStart ?? const Clock(22, 0)).on(day);
    add(waking.start, work, DayBlockKind.afterWork);
    add(work, waking.end, DayBlockKind.evening, allowsHeavy: false);
    return windows;
  }

  final leave = shift.leaveHome?.on(day);
  final workStart = shift.workStart?.on(day);
  final workEnd = shift.workEnd?.on(day);
  final home = shift.homeAgain?.on(day);

  // Morning: awake, at home, before leaving — but light tasks only.
  //
  // The user is at home and technically free, so the letter of rule 2 would
  // allow a heavy task here. The worked example does not, and it is right: the
  // hour before leaving is fajr, athkar, breakfast and getting out of the
  // door. A planner that put a thirty-minute walk in it would be describing a
  // morning nobody has.
  if (leave != null) {
    add(waking.start, leave, DayBlockKind.morning, allowsHeavy: false);
  }

  // Rule 3: the commute is a window, but only a light task may ride it.
  if (leave != null && workStart != null) {
    add(leave, workStart, DayBlockKind.morning, allowsHeavy: false);
  }

  // Work itself. Light tasks only — a break holds a tasbeeh, not a workout.
  if (workStart != null && workEnd != null) {
    add(workStart, workEnd, DayBlockKind.work, allowsHeavy: false);
  }

  // The ride home is a window too, and still light-only.
  if (workEnd != null && home != null) {
    add(workEnd, home, DayBlockKind.afterWork, allowsHeavy: false);
  }

  // Home and free. This is where the heavy work actually goes — after a
  // settling gap, because arriving is not the same as being available.
  if (home != null) {
    final free = home.add(config.settleAfterHome);
    add(free, prayers.maghrib, DayBlockKind.afterWork);

    // The evening cannot begin before the user is actually home. On a long
    // shift that ends after maghrib, opening the evening at maghrib would hand
    // the planner four free hours the user spends at work — and it would put a
    // heavy task in them.
    final eveningFrom = free.isAfter(prayers.maghrib) ? free : prayers.maghrib;
    add(eveningFrom, waking.end, DayBlockKind.evening);
  }

  return windows;
}

Duration _breakAfter(PlannedTask task, PlannerConfig config) =>
    task.weight == TaskWeight.heavy
        ? config.breakAfterHeavy
        : config.breakAfterLight;

/// A window that can take [task], preferring its requested block.
///
/// [latest] searches from the end of the day backwards, for tasks that belong
/// as late as they can go.
_Window? _fittingWindow(
  List<_Window> windows,
  PlannedTask task,
  DayBlockKind? preferred, {
  bool latest = false,
}) {
  bool fits(_Window w) =>
      (task.weight == TaskWeight.light || w.allowsHeavy) &&
      w.remaining >= task.duration;

  final search = latest ? windows.reversed.toList() : windows;

  if (preferred != null) {
    for (final w in search) {
      if (w.block == preferred && fits(w)) return w;
    }
  }
  for (final w in search) {
    if (fits(w)) return w;
  }
  return null;
}

DayBlockKind? _blockIn(
  Map<DayBlockKind, (DateTime, DateTime)> bounds,
  DateTime at,
) {
  for (final entry in bounds.entries) {
    if (!at.isBefore(entry.value.$1) && at.isBefore(entry.value.$2)) {
      return entry.key;
    }
  }
  // Between blocks — a prayer during the commute, say. The next block to open
  // owns it, so nothing falls off the day.
  DayBlockKind? next;
  DateTime? soonest;
  for (final entry in bounds.entries) {
    if (at.isBefore(entry.value.$2) &&
        (soonest == null || entry.value.$1.isBefore(soonest))) {
      soonest = entry.value.$1;
      next = entry.key;
    }
  }
  return next;
}

/// Marks the minutes from [at] as used, so nothing is placed on top of them.
///
/// Splits any window the used span falls inside, rather than advancing its
/// start past it. A prayer at 11:46 in a window running 04:00-18:00 leaves
/// *two* windows, not one starting at 12:01.
void _consume(List<_Window> windows, DateTime at, Duration length) {
  final until = at.add(length);
  final added = <_Window>[];

  for (final w in windows) {
    // No overlap at all.
    if (!w.start.isBefore(until) || !at.isBefore(w.end)) continue;

    final coversStart = !at.isAfter(w.start);
    final coversEnd = !until.isBefore(w.end);

    if (coversStart && coversEnd) {
      // Swallowed whole: collapse it to nothing.
      w.start = w.end;
    } else if (coversStart) {
      w.start = until;
    } else if (coversEnd) {
      w.end = at;
    } else {
      // Straddled: keep the front here and hand the back to a new window.
      added.add(_Window(
        start: until,
        end: w.end,
        block: w.block,
        allowsHeavy: w.allowsHeavy,
      ));
      w.end = at;
    }
  }

  windows
    ..addAll(added)
    ..removeWhere((w) => !w.start.isBefore(w.end))
    ..sort((a, b) => a.start.compareTo(b.start));
}

DateTime? _anchorTime(
  TaskAnchor anchor,
  DateTime day,
  DailyPrayerTimes prayers,
) =>
    switch (anchor) {
      ClockAnchor(:final at) => at.on(day),
      PrayerAnchor(:final prayer, :final offset) =>
        _prayerTime(prayers, prayer)?.add(offset),
      FlexibleAnchor() => null,
    };

DateTime? _prayerTime(DailyPrayerTimes p, String name) => switch (name) {
      'fajr' => p.fajr,
      'dhuhr' => p.dhuhr,
      'asr' => p.asr,
      'maghrib' => p.maghrib,
      'isha' => p.isha,
      _ => null,
    };
