import '../../features/planner/day_plan.dart';
import 'task_alert.dart';

/// «فكّرني تاني» — asking again about a task that has not been done.
///
/// The user's request of 13 September 2026:
///
///   «لو مش عملته تفضل تذكرني كل فترة مثلا كل ٥ دقايق او ١٠ دقايق زي ما انا
///    اختار لحد معاد التاسك التاني ما ييجي ولما ييجي التاسك التاني تفكرني ان
///    معملتش التاسك اللي فاتني وكده»
///
/// Every few minutes, until the next task's time; and when the next task
/// comes, one word that the last one was not done.
///
/// **Not armed as alarms.** A day has about eleven tasks and eighteen waking
/// hours; at ten-minute steps that is a hundred alarms a day, at five it is
/// two hundred, on top of the three hundred the window already holds against
/// Android's cap of five hundred per app — and every one of them would have
/// to be cancelled at the write site when the task was done. So instead:
/// **one tick**, every N minutes, that reads two small files and posts at
/// most one notification. `nag_tick.dart` is the tick; this file is what it
/// reads and the decision it makes, pure, so the whole behaviour is testable
/// by stating a plan, a clock, and what is done.
///
/// **The plan is a file, not the database.** The tick runs in a background
/// isolate with nothing of the app alive, and this project does not open a
/// second connection to the SQLite file from a second isolate — see
/// `snooze_store.dart` for the rule and the reason. The window writes
/// `nag_plan.json` on every re-arm; the write sites append to
/// `nag_done.json` as they go.
class NagTask {
  const NagTask({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.channelId,
    required this.payload,
    this.question,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;

  /// The task's own channel, so the nag arrives in the task's own voice.
  final String channelId;

  /// Where tapping it goes — the same route the task's alarm carries.
  final String payload;

  /// The kind's «عملتها؟», when it has one.
  final String? question;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'channelId': channelId,
        'payload': payload,
        if (question != null) 'question': question,
      };

  static NagTask? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final start = DateTime.tryParse('${raw['start']}');
    final end = DateTime.tryParse('${raw['end']}');
    final id = raw['id'];
    final title = raw['title'];
    final channelId = raw['channelId'];
    final payload = raw['payload'];
    if (start == null || end == null) return null;
    if (id is! String || title is! String) return null;
    if (channelId is! String || payload is! String) return null;
    return NagTask(
      id: id,
      title: title,
      start: start,
      end: end,
      channelId: channelId,
      payload: payload,
      question: raw['question'] as String?,
    );
  }
}

class NagDay {
  const NagDay({required this.tasks, this.sleepStart});

  /// In the order they start.
  final List<NagTask> tasks;

  /// When the plan puts the user to bed. Nothing is asked after it.
  final DateTime? sleepStart;

  Map<String, Object?> toJson() => {
        'tasks': [for (final t in tasks) t.toJson()],
        if (sleepStart != null) 'sleepStart': sleepStart!.toIso8601String(),
      };

  static NagDay? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final tasks = <NagTask>[
      for (final t in (raw['tasks'] is List ? raw['tasks'] as List : const []))
        if (NagTask.fromJson(t) case final task?) task,
    ]..sort((a, b) => a.start.compareTo(b.start));
    return NagDay(
      tasks: tasks,
      sleepStart: DateTime.tryParse('${raw['sleepStart'] ?? ''}'),
    );
  }
}

/// What the window writes and the tick reads.
class NagPlan {
  const NagPlan({
    required this.intervalMinutes,
    required this.enabled,
    required this.days,
  });

  /// Zero means off.
  final int intervalMinutes;

  /// The task-alarm switch. Off means the day is not announcing itself, and
  /// a nag about a task that never rang would be the app nagging alone.
  final bool enabled;

  /// Keyed by `yyyy-mm-dd`.
  final Map<String, NagDay> days;

  bool get active => enabled && intervalMinutes > 0;

  Duration get interval => Duration(minutes: intervalMinutes);

  /// Built from the same plans the window armed, so a nag and its alarm can
  /// never disagree about when a task was.
  factory NagPlan.fromDayPlans({
    required List<DayPlan> plans,
    required int intervalMinutes,
    required bool enabled,
  }) =>
      NagPlan(
        intervalMinutes: intervalMinutes,
        enabled: enabled,
        days: {
          for (final plan in plans)
            dateKey(plan.date): NagDay(
              tasks: [
                for (final s in plan.allTasks)
                  if (alertKindForTaskId(s.task.id) case final kind?)
                    NagTask(
                      id: s.task.id,
                      title: s.task.title,
                      start: s.start,
                      end: s.end,
                      channelId: kind.channelId,
                      payload: 'task:${s.task.id}',
                      question: kind.followUpQuestion,
                    ),
              ]..sort((a, b) => a.start.compareTo(b.start)),
              sleepStart: plan.sleep?.start,
            ),
        },
      );

  Map<String, Object?> toJson() => {
        'intervalMinutes': intervalMinutes,
        'enabled': enabled,
        'days': {for (final e in days.entries) e.key: e.value.toJson()},
      };

  static NagPlan? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final interval = raw['intervalMinutes'];
    final rawDays = raw['days'];
    return NagPlan(
      intervalMinutes: interval is int ? interval : 0,
      enabled: raw['enabled'] == true,
      days: {
        if (rawDays is Map)
          for (final e in rawDays.entries)
            if (NagDay.fromJson(e.value) case final day?) '${e.key}': day,
      },
      // ignore_for_file: use_null_aware_elements
    );
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// One notification the tick should post, or nothing.
class NagDecision {
  const NagDecision({
    required this.title,
    required this.body,
    required this.channelId,
    required this.payload,
  });

  final String title;
  final String body;
  final String channelId;
  final String payload;

  @override
  String toString() => 'NagDecision($title: $body)';
}

/// The one notification id every nag posts under.
///
/// One id, so a new nag replaces the last in the shade rather than stacking
/// six copies of «لسه معملتهاش». Above every other range — window ids are
/// below 500 million, task alarms and reminders below 950 million, snoozes
/// just above that.
const kNagNotificationId = 990000000;

/// What to say now, if anything.
///
/// The rules, in the order they decide:
///
/// - Off, no plan for today, or nothing has started yet: nothing.
/// - Bedtime has come: nothing. A nag at 01:00 about a walk is not help.
/// - **The first tick after a task starts** does not nag about *that* task
///   — its own alarm just rang, and a second ring a minute later is noise.
///   It is the moment for the other half of the request: if the task
///   *before* it is still not done, say so, once, in that task's voice.
/// - Every later tick, while the current task is open, asks again — in the
///   task's own channel, with its own «عملتها؟» — and adds the previous
///   task in one clause if it is open too. Only the previous: a list of
///   everything undone since morning is the shape of blame, and this app
///   does not do that.
/// - A task that is done, or snoozed to a later time, is not asked about.
///   The snooze has its own notification coming.
///
/// [now] is the tick's clock; [done] is `nag_done.json` for today;
/// [snoozedUntil] is the snooze file.
NagDecision? decideNag({
  required NagPlan plan,
  required Set<String> done,
  required Map<String, DateTime> snoozedUntil,
  required DateTime now,
}) {
  if (!plan.active) return null;
  final day = plan.days[NagPlan.dateKey(now)];
  if (day == null || day.tasks.isEmpty) return null;

  final sleep = day.sleepStart;
  if (sleep != null && !now.isBefore(sleep)) return null;

  NagTask? current;
  NagTask? previous;
  for (final t in day.tasks) {
    if (t.start.isAfter(now)) break;
    previous = current;
    current = t;
  }
  if (current == null) return null;

  bool open(NagTask t) {
    if (done.contains(t.id)) return false;
    final snoozed = snoozedUntil[t.id];
    if (snoozed != null && snoozed.isAfter(now)) return false;
    return true;
  }

  final previousOpen = previous != null && open(previous);
  final firstTick = now.difference(current.start) < plan.interval;

  if (firstTick) {
    if (!previousOpen) return null;
    return NagDecision(
      title: previous.title,
      body: 'فاتك ${previous.title} — لسه ينفع تعمله.',
      channelId: previous.channelId,
      payload: previous.payload,
    );
  }

  if (!open(current)) return null;

  final ask = current.question ?? 'عملتها؟';
  final tail = previousOpen ? ' و${previous.title} فاتك قبلها.' : '';
  return NagDecision(
    title: current.title,
    body: 'لسه معملتهاش — $ask$tail',
    channelId: current.channelId,
    payload: current.payload,
  );
}
