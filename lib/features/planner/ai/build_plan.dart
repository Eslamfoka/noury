import '../../../core/notifications/task_alert.dart';
import '../../../core/time/geo_config.dart';
import '../../../core/time/prayer_times_service.dart';
import '../../../data/db/nouri_database.dart';
import '../../ai/ai_client.dart';
import '../../prayers/prayer_names.dart';
import '../daily_tasks.dart';
import '../day_planner.dart';
import '../day_plan.dart';
import '../shift_settings.dart';
import 'locked_windows.dart';
import 'plan_document.dart';
import 'plan_request.dart';

/// What «ابني خطتي» does, from press to sheet.
///
/// Three steps that were built and tested separately in September — the
/// summary assembler, the one call, the reply parser — joined here in the
/// order the spec gives them, with the same rule at every join: **nothing
/// throws into the UI.** A missing key, a dead network, a reply that is not
/// JSON — each ends as an [BuildPlanOutcome] with a sentence.
///
/// **Three days per call.** The spec left "how many days" open; three is
/// the smallest number that is a plan rather than a day, and the task-alarm
/// window is three days too, so the two agree without anyone deciding
/// more. It is one number, here, for the user to change.
///
/// **Proposed, not applied.** The plan that comes back is shown; it is not
/// written into the day. That is the reversible direction the spec built
/// toward and the question the user has not answered yet — see the handoff.
const planDaysPerCall = 3;

/// Assembles what leaves the phone: the profile, the anchors, the allowed
/// task ids. **Never a logged row** — `plan_request_test` writes into every
/// logging table and fails if any of it appears in the payload.
Future<PlanRequest> assemblePlanRequest({
  required NouriDatabase db,
  required PrayerTimesService prayerTimes,
  required DateTime from,
  int days = planDaysPerCall,
}) async {
  final settings = await db.settingsDao.get();
  final profile = await db.profileDao.get();
  final custom = await db.profileDao.customFields();

  final geo = GeoConfig(
    latitude: settings.latitude,
    longitude: settings.longitude,
    method: settings.calculationMethod,
    madhab: settings.madhab,
  );

  final start = DateTime(from.year, from.month, from.day);
  final dates = [
    // Constructed day by day, never `add(Duration(days: 1))` — the rule this
    // project keeps re-learning about DST and midnight.
    for (var i = 0; i < days; i++) DateTime(start.year, start.month, start.day + i),
  ];

  // The same days `planDay` would build, so the hours the model is told are
  // the hours the app itself keeps — the sleep it sized, the work block the
  // user set. See locked_windows.dart.
  final plans = _plansFor(dates, prayerTimes, settings);

  return PlanRequest(
    profile: profile,
    customFields: custom,
    days: dates,
    shiftType: settings.shiftType,
    prayerTimesByDay: {
      for (final date in dates)
        date: {
          for (final slot in prayerTimes.forDate(date, geo).ordered)
            arabicPrayerName(slot.name): _hhmm(slot.time),
        },
    },
    targetSleepHours: const PlannerConfig().targetSleep.inMinutes / 60,
    eatingWindowStartHour: settings.eatingWindowStartHour,
    // 16/8, the brief's base system. The window's length is not a setting;
    // its start is.
    eatingWindowHours: 8,
    waterTargetGlasses: settings.waterTargetGlasses,
    lockedByDay: {
      for (final e in plans.entries) e.key: lockedWindowsFor(e.value),
    },
  );
}

/// The days as `planDay` builds them — what the request describes to the
/// model and what the reply is checked against, from one function so the
/// two cannot differ.
Map<DateTime, DayPlan> _plansFor(
  List<DateTime> dates,
  PrayerTimesService prayerTimes,
  SettingsRow settings,
) {
  final geo = GeoConfig(
    latitude: settings.latitude,
    longitude: settings.longitude,
    method: settings.calculationMethod,
    madhab: settings.madhab,
  );
  final shift = shiftPatternFromSettings(settings);
  return {
    for (final date in dates)
      date: planDay(
        date: date,
        shift: shift,
        prayers: prayerTimes.forDate(date, geo),
        tasks: dailyTasksFor(
          date: date,
          shift: shift,
          eatingWindowStartHour: settings.eatingWindowStartHour,
        ),
      ),
  };
}

/// The whole thing, one press.
Future<BuildPlanOutcome> buildPlan({
  required NouriDatabase db,
  required PrayerTimesService prayerTimes,
  required AiClient client,
  required AiConnection? connection,
  required DateTime now,
}) async {
  if (connection == null) return const BuildPlanOutcome.noConnection();

  final request = await assemblePlanRequest(
    db: db,
    prayerTimes: prayerTimes,
    from: now,
  );

  final allowed = alarmableTaskIds;
  final reply = await client.complete(
    connection,
    system: PlanRequest.systemPrompt,
    user: request.toPrompt(allowedTaskIds: allowed),
    // Three days of tasks, a few books and two lines is two to three
    // thousand tokens. Eight, not four: the first real reply — Gemini 2.5
    // Flash, 13 September — spent the cap on its own thinking and came back
    // with the JSON cut off. The cap is a ceiling on cost, not a size.
    maxTokens: 8192,
    json: true,
  );

  if (!reply.ok) {
    final f = reply.failure!;
    return BuildPlanOutcome.failed(
      f.detail == null ? f.message : '${f.message}\n${f.detail}',
    );
  }

  final parsed = PlanDocument.parse(reply.value!, allowedTaskIds: allowed.toSet());
  if (!parsed.ok) {
    // What actually came back, so a screenshot of the sheet says enough to
    // fix the prompt — the first failure gave nothing to go on.
    return BuildPlanOutcome.failed(parsed.failure!, rawReply: reply.value);
  }

  final settings = await db.settingsDao.get();
  final plans = _plansFor(request.days, prayerTimes, settings);

  // The titles المهام would show for each id, so the sheet reads «مشي» and
  // not «walk» — and each task's weight, which decides whether it may ride
  // the commute. Titles and weights do not vary by date.
  final today = plans[DateTime(now.year, now.month, now.day)] ??
      plans.values.first;
  final byId = {
    for (final s in today.allTasks) s.task.id: s.task,
  };
  final titles = {for (final e in byId.entries) e.key: e.value.title};

  // Telling the model was a courtesy; this is the guarantee. A task inside
  // sleep or work is removed however sensible it looks, a heavy one in the
  // commute too, and the sheet says how many — never silently.
  final removed = <RemovedTask>[];
  final kept = <PlannedDay>[];
  for (final day in parsed.document!.days) {
    final plan = plans[day.date];
    final windows = plan == null ? const <LockedWindow>[] : lockedWindowsFor(plan);
    final tasks = <PlannedEntry>[];
    for (final t in day.tasks) {
      final heavy = byId[t.id]?.weight == TaskWeight.heavy;
      final why = violationFor(t.at, windows: windows, heavy: heavy);
      if (why == null) {
        tasks.add(t);
      } else {
        removed.add(RemovedTask(id: t.id, at: t.at, reason: why));
      }
    }
    if (tasks.isNotEmpty) kept.add(PlannedDay(date: day.date, tasks: tasks));
  }

  return BuildPlanOutcome.built(
    PlanDocument(
      days: kept,
      books: parsed.document!.books,
      note: parsed.document!.note,
    ),
    titles: titles,
    model: connection.model,
    droppedTaskIds: parsed.droppedTaskIds,
    removed: removed,
  );
}

/// What the press produced.
class BuildPlanOutcome {
  const BuildPlanOutcome.noConnection()
      : document = null,
        titles = const {},
        model = null,
        droppedTaskIds = const [],
        removed = const [],
        failure = null,
        rawReply = null,
        needsConnection = true;

  const BuildPlanOutcome.failed(String this.failure, {this.rawReply})
      : document = null,
        titles = const {},
        model = null,
        droppedTaskIds = const [],
        removed = const [],
        needsConnection = false;

  const BuildPlanOutcome.built(
    PlanDocument this.document, {
    required this.titles,
    required this.model,
    this.droppedTaskIds = const [],
    this.removed = const [],
  })  : failure = null,
        rawReply = null,
        needsConnection = false;

  final PlanDocument? document;

  /// Task id → the title المهام uses for it.
  final Map<String, String> titles;

  /// Which model answered, for the sheet's small print.
  final String? model;

  /// Ids the model invented and the parser dropped. Not shown to the user;
  /// kept so the handoff can say whether the prompt needs work.
  final List<String> droppedTaskIds;

  /// Tasks the model placed in sleep, in work, or heavy in the commute —
  /// removed, and **counted on the sheet**: «٣ مهام اتشالت لأنها كانت وقت
  /// النوم أو الدوام». The day is always told what it dropped.
  final List<RemovedTask> removed;

  /// In Arabic, ready to show.
  final String? failure;

  /// The service's reply as it came, when it could not be read as a plan.
  /// Shown in small print under the failure so the user can send it on.
  final String? rawReply;

  /// No key: the sheet should point at الإعدادات rather than at the network.
  final bool needsConnection;

  bool get ok => document != null;

  /// The title for one entry, falling back to the id — which cannot happen
  /// for an id that passed the parser, but a fallback beats a crash.
  String titleOf(String id) => titles[id] ?? id;
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
