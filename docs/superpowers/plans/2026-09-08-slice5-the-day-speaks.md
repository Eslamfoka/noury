# Slice 5 — the day speaks

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:executing-plans`
> to work this task by task. Steps use `- [ ]` so progress is trackable.

**Goal:** every task in the planned day announces itself at its own time, with
its own sound, so the user knows what is being asked without looking at the
screen — and can snooze it five minutes, repeatedly, or be asked afterwards
whether it happened.

**Architecture:** Android ties a notification's sound to its **channel**, not to
the notification, so "a different sound per task" means "a channel per task".
That single fact drives the whole design. A `TaskAlert` registry names, for each
kind of task, its channel, its sound resource, its copy and the screen it opens;
the scheduler arms one alarm per planned task from `planDay`'s output; a
background isolate handles snooze without opening the app; and follow-ups reuse
the shape prayers already have.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2, `flutter_local_notifications`,
Drift, Riverpod. Sounds are `res/raw` WAV. Everything offline.

**Spec:** the user's message of 8 September 2026, quoted verbatim in the
"What was asked" section below, plus `Nouri_Project_Brief.md` §5.5–§5.6.

## Global Constraints

- Do not merge to `master`, do not switch branches, do not force-push.
- **No network calls from the app.** `no_network_test` fails the build.
- Nothing is ever red, nothing is ever marked failed, no copy accuses.
- Counters read «٠ من ٣», never «٠ / ٣».
- Dates are constructed, never offset.
- Anything day-scoped watches `currentDayProvider`.
- **Append to `NotificationSlot`, never insert.** IDs derive from `index`.
- **Never mutate a channel's sound.** Android freezes it at creation; a new
  sound means a new versioned channel id and the old one retired.
- One place builds the alarm config: `schedulingConfigFromDb`. A guard test
  fails the build on a second one.
- Do not claim any HONOR/MagicOS behaviour has passed unless it ran on the real
  VNE-N41.

---

## What was asked, in the user's words

> i want the tasks have correct time and there is notification reminder as
> prayer — for example tasbih time according to the plan for my time according
> to duty, it will be when 1 pm; when time 1 pm send me notification and open
> the app to do it, and i can late it 5 mins many times. also walking and
> eating time send notification — for example 4:30 pm let's walk and open the
> app for walking, or 6pm time for eating, eat and enter your meal, and also
> after 30 mins ask me are you ate? like that for all tasks. i don't need to
> open the app to know what i have to do, i need alarms for each task.
>
> for alarms i need special alarm for each task regarding to this task —
> example, to drink water i need alarm has relation to water sound, because
> from alarms i know what this task. so think and know which alarm sound
> possible or good for this task and download this alarms and keep in the app,
> each alarm for each task.
>
> also adhan: download different adhan for each prayer time, separate and
> different adhan sound, so i need at least now 5 adhans. and for azkar sabah
> and masaa different sound, for tasbeeh — everything must be different alarm
> sound. so i need when the app sends notification reminder for the task i know
> what this task from the sound.

Six requirements, and every one of them gets a task below:

1. An alarm at each planned task's real time — Tasks 4, 5.
2. Tapping it opens the app *on that task* — Task 6.
3. Snooze five minutes, repeatable — Task 7.
4. A follow-up afterwards: "did you eat?" — Task 8.
5. A distinct sound per task — Tasks 1, 2, 3.
6. Five separate adhans, one per prayer — Task 9.

---

## Two things the user needs to know before this is built

**The sounds I can make, and the one I cannot.**

Every non-adhan alert in this plan is a short tone **synthesised in this repo**
by `tool/make_alert_sounds.py`, committed as source. That means: no download,
no licence to honour, no attribution to track, nothing that can be taken down,
and a file we can regenerate or retune at will. They are designed to be told
apart — water descends like drops, walking alternates like footsteps, the sleep
athkar sink and the morning athkar rise — which is exactly the property asked
for.

**An adhan is not a tone, and I will not fake one.** A synthesised approximation
of a muezzin would be worse than the current placeholder. Real recitations are
performances with rights holders, and *which* muezzin is a matter of taste and
religious preference — the same class of decision as `docs/fasting-verification.md`,
which this project already leaves to the user. So Task 9 builds **five separate
adhan channels and a tool that installs five files**, and the files come from
the user. Until they do, all five play the existing `chime` placeholder and the
app says so plainly.

**The alarm budget is real.** The phone carries ~249 pending alarms of Android's
~500 cap. Task alarms are therefore armed over **3 days**, not the adhan's 14 —
same reasoning as the follow-ups: a nudge to walk eleven days from now is worth
nothing, and it would cost 110 alarms. Measured cost of this slice: ~10 tasks ×
3 days = 30, plus follow-ups ~15, plus 4 more adhan channels costing nothing
extra. That lands near 295 of 500.

---

## File structure

| File | Responsibility |
|---|---|
| `tool/make_alert_sounds.py` | Generates every non-adhan `res/raw` WAV. Committed; re-runnable. |
| `android/app/src/main/res/raw/*.wav` | The generated tones. |
| `lib/core/notifications/task_alert.dart` | The registry: for each `TaskAlertKind`, its channel, sound, title, body, route and follow-up question. **The single source of truth this slice adds.** |
| `lib/core/notifications/notification_channels_ids.dart` | +18 channel ids, versioned. |
| `lib/core/notifications/notification_channels.dart` | The channel list, built from the registry. |
| `lib/core/notifications/notification_slot.dart` | +task and +task-follow-up slots. |
| `lib/core/notifications/task_alarm_plan.dart` | Pure: a `DayPlan` → the alerts to arm. |
| `lib/core/notifications/rolling_window_scheduler.dart` | Arms them. |
| `lib/core/notifications/notification_route.dart` | `task:<id>` routes. |
| `lib/core/notifications/snooze.dart` | The background-isolate snooze handler. |
| `lib/features/tasks/task_done_dao.dart` | Which tasks were done today, for the follow-up to skip. |

---

## Task 1: the sound generator

**Files:**
- Create: `tool/make_alert_sounds.py`
- Create: `android/app/src/main/res/raw/*.wav` (generated)
- Test: `test/core/notifications/alert_sounds_test.dart`

**Why synthesised rather than downloaded.** No licence, no attribution, no
takedown risk, regenerable, and about 40 KB each rather than a megabyte. The
point of the request is *distinguishability*, not fidelity — the user wants to
know which task is calling from the sound alone, and eighteen deliberately
contrasting tones do that better than eighteen stock recordings would.

**The palette.** Each is ≤ 2.0 s, mono, 22 050 Hz, 16-bit PCM, peak-normalised
to −3 dBFS with a 15 ms fade in and 60 ms fade out so nothing clicks.

| Resource | Task | Shape |
|---|---|---|
| `alert_water` | مياه | three descending droplet plinks, 880→660→550 Hz, fast decay |
| `alert_walk` | مشي | four alternating footsteps, 440/330 Hz, even spacing |
| `alert_meal` | وجبة | warm rising two-tone, 392→523 Hz |
| `alert_tasbeeh` | تسبيح | three soft bead taps, 660 Hz, short decay |
| `alert_wird` | ورد القرآن | calm ascending triad, 392–494–587 Hz |
| `alert_athkar_morning` | أذكار الصباح | bright rising pair, 523→784 Hz |
| `alert_athkar_evening` | أذكار المساء | its mirror, falling 784→523 Hz |
| `alert_athkar_sleep` | أذكار النوم | low slow fall, 330→220 Hz, long decay |
| `alert_qiyam` | قيام الليل | one very soft low tone, 262 Hz — it arrives at 01:30 |
| `alert_knowledge` | وقت المعرفة | soft swell then a single 587 Hz chime |
| `alert_phone` | وقت الموبايل | two flat digital blips, 700 Hz — deliberately plainest |
| `alert_calls` | مكالمات | gentle double ring burst, 480/440 Hz |
| `alert_budget` | الميزانية | two low coin ticks, 300 Hz |
| `alert_reminder` | تذكير من التقويم | neutral single bell, 660 Hz |
| `alert_fasting` | صيام بكرة | one gentle low tone, 349 Hz |
| `alert_review` | مراجعة اليوم | soft neutral two-tone, 440→494 Hz |
| `alert_followup` | «عملتها؟» | one very soft tick, 587 Hz, 0.4 s |
| `alert_iqama` | الإقامة | firm double knock, 294 Hz |

- [ ] **Step 1: write the failing test**

```dart
// test/core/notifications/alert_sounds_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/task_alert.dart';

void main() {
  test('every alert names a sound file that exists', () {
    for (final kind in TaskAlertKind.values) {
      final f = File('android/app/src/main/res/raw/${kind.sound}.wav');
      expect(f.existsSync(), isTrue, reason: '${kind.name} -> ${kind.sound}');
    }
  });

  test('no two alerts share a sound', () {
    final sounds = TaskAlertKind.values.map((k) => k.sound).toList();
    expect(sounds.toSet().length, sounds.length,
        reason: 'the whole point is telling them apart by ear');
  });

  test('every sound is small enough to ship eighteen of', () {
    for (final kind in TaskAlertKind.values) {
      final f = File('android/app/src/main/res/raw/${kind.sound}.wav');
      expect(f.lengthSync(), lessThan(120 * 1024), reason: kind.sound);
    }
  });

  test('resource names are legal Android raw identifiers', () {
    // res/raw names must be lowercase a-z, 0-9 and underscore, and must not
    // start with a digit. A bad one fails the Gradle build with a message
    // that does not mention the file.
    final legal = RegExp(r'^[a-z][a-z0-9_]*$');
    for (final kind in TaskAlertKind.values) {
      expect(legal.hasMatch(kind.sound), isTrue, reason: kind.sound);
    }
  });
}
```

- [ ] **Step 2: run it and watch it fail** — `TaskAlertKind` is not defined yet.
      This test is written before Task 2 on purpose: it is the contract Task 2
      has to satisfy.

- [ ] **Step 3: write `tool/make_alert_sounds.py`**

Standard library only — `wave`, `struct`, `math`. Each sound is a list of
`(freq_hz, start_s, dur_s, decay)` partials rendered into one buffer.

```python
#!/usr/bin/env python3
"""Generates Nouri's alert tones into android/app/src/main/res/raw/.

Synthesised rather than downloaded, deliberately: no licence to honour, no
attribution to track, nothing that can be taken down, and every tone can be
retuned by editing one line here and re-running. The point of the feature is
that the user can tell which task is calling *by ear*, so the tones are
designed to contrast with each other rather than to sound realistic.

Run:  python tool/make_alert_sounds.py
"""
import math, os, struct, wave

RATE = 22050
OUT = os.path.join("android", "app", "src", "main", "res", "raw")

def render(notes, length_s):
    n = int(RATE * length_s)
    buf = [0.0] * n
    for freq, start, dur, decay in notes:
        s = int(start * RATE)
        for i in range(int(dur * RATE)):
            if s + i >= n:
                break
            t = i / RATE
            env = math.exp(-decay * t)
            buf[s + i] += math.sin(2 * math.pi * freq * t) * env
    return buf

def normalise(buf, peak=0.7):
    m = max(abs(v) for v in buf) or 1.0
    return [v / m * peak for v in buf]

def fade(buf, in_s=0.015, out_s=0.06):
    a, b = int(in_s * RATE), int(out_s * RATE)
    for i in range(min(a, len(buf))):
        buf[i] *= i / a
    for i in range(min(b, len(buf))):
        buf[len(buf) - 1 - i] *= i / b
    return buf

def write(name, notes, length_s):
    buf = fade(normalise(render(notes, length_s)))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in buf))
    print(f"{name}.wav  {os.path.getsize(path)//1024} KB")

SOUNDS = {
    # Three descending drops. Water falls, so the pitch falls.
    "alert_water": ([(880, 0.00, 0.35, 12), (660, 0.28, 0.35, 12),
                     (550, 0.56, 0.45, 10)], 1.1),
    # Four alternating steps, evenly spaced, like walking.
    "alert_walk": ([(440, 0.00, 0.18, 18), (330, 0.22, 0.18, 18),
                    (440, 0.44, 0.18, 18), (330, 0.66, 0.22, 16)], 1.0),
    "alert_meal": ([(392, 0.00, 0.30, 8), (523, 0.26, 0.50, 6)], 0.9),
    "alert_tasbeeh": ([(660, 0.00, 0.22, 16), (660, 0.24, 0.22, 16),
                       (660, 0.48, 0.30, 14)], 0.9),
    "alert_wird": ([(392, 0.00, 0.45, 5), (494, 0.22, 0.45, 5),
                    (587, 0.44, 0.70, 4)], 1.3),
    "alert_athkar_morning": ([(523, 0.00, 0.35, 7), (784, 0.28, 0.60, 5)], 1.0),
    "alert_athkar_evening": ([(784, 0.00, 0.35, 7), (523, 0.28, 0.60, 5)], 1.0),
    "alert_athkar_sleep": ([(330, 0.00, 0.60, 3), (220, 0.45, 0.90, 2)], 1.5),
    # 01:30. Soft, low, slow — it must invite, not startle.
    "alert_qiyam": ([(262, 0.00, 1.20, 2)], 1.4),
    "alert_knowledge": ([(294, 0.00, 0.40, 4), (587, 0.35, 0.60, 5)], 1.1),
    # Deliberately the plainest sound here: it is a cap, not a treat.
    "alert_phone": ([(700, 0.00, 0.14, 22), (700, 0.20, 0.14, 22)], 0.5),
    "alert_calls": ([(480, 0.00, 0.20, 14), (440, 0.18, 0.20, 14),
                     (480, 0.44, 0.20, 14), (440, 0.62, 0.24, 12)], 1.0),
    "alert_budget": ([(300, 0.00, 0.25, 14), (300, 0.30, 0.30, 12)], 0.8),
    "alert_reminder": ([(660, 0.00, 0.70, 5)], 0.9),
    "alert_fasting": ([(349, 0.00, 0.80, 3)], 1.0),
    "alert_review": ([(440, 0.00, 0.30, 7), (494, 0.26, 0.50, 5)], 0.9),
    "alert_followup": ([(587, 0.00, 0.25, 12)], 0.4),
    "alert_iqama": ([(294, 0.00, 0.22, 16), (294, 0.26, 0.28, 14)], 0.7),
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, (notes, length) in SOUNDS.items():
        write(name, notes, length)
    print(f"\n{len(SOUNDS)} sounds written to {OUT}")
```

- [ ] **Step 4: run it**

```
python tool/make_alert_sounds.py
```
Expected: 18 files, each well under 120 KB.

- [ ] **Step 5: keep them from being stripped**

`res/raw/keep.xml` already protects `chime`. Add the new names, or widen it to
`@raw/*`. Confirm by checking the release APK still lists them (Task 10).

- [ ] **Step 6: commit** (after Task 2 makes the test compile)

---

## Task 2: the alert registry

**Files:**
- Create: `lib/core/notifications/task_alert.dart`
- Test: `test/core/notifications/task_alert_test.dart`

One enum is the single source of truth: sound, channel, copy, route, and
whether it asks afterwards. Everything else in this slice reads it, so a new
task type is one entry rather than five edits.

**Interfaces:**
- Produces: `enum TaskAlertKind` with `String get sound`, `String get channelId`,
  `String get title`, `String get body`, `String get payload`,
  `Duration? get followUpAfter`, `String? get followUpQuestion`.
- Produces: `TaskAlertKind? alertKindForTaskId(String taskId)` mapping
  `daily_tasks.dart` ids (`'tasbeeh'`, `'walk'`, `'first-meal'`, …) onto kinds.

- [ ] **Step 1: write the failing test**

```dart
void main() {
  test('every planned task id maps to an alert', () {
    // The ids dailyTasksFor emits. A task the planner places but that has no
    // sound would be silent, which is the one thing this slice exists to stop.
    const ids = [
      'morning-athkar', 'evening-athkar', 'tasbeeh', 'quran-wird',
      'sleep-athkar', 'first-meal', 'last-meal', 'walk',
      'knowledge-read', 'knowledge-listen', 'knowledge-skill',
      'calls', 'phone-time',
    ];
    for (final id in ids) {
      expect(alertKindForTaskId(id), isNotNull, reason: id);
    }
  });

  test('no two kinds share a channel', () {
    final ids = TaskAlertKind.values.map((k) => k.channelId).toList();
    expect(ids.toSet().length, ids.length,
        reason: 'Android ties sound to channel; sharing one merges the sounds');
  });

  test('every kind has real copy', () {
    for (final k in TaskAlertKind.values) {
      expect(k.title.trim(), isNotEmpty, reason: k.name);
      expect(k.body.trim(), isNotEmpty, reason: k.name);
    }
  });

  test('nothing accuses', () {
    for (final k in TaskAlertKind.values) {
      final text = '${k.title} ${k.body} ${k.followUpQuestion ?? ''}';
      for (final w in ['فاتتك', 'ضيعت', 'فشل', 'كسلان', 'لازم']) {
        expect(text.contains(w), isFalse, reason: '${k.name}: $w');
      }
    }
  });

  test('the meal asks afterwards, half an hour later', () {
    // The user's example, by name.
    expect(TaskAlertKind.meal.followUpAfter, const Duration(minutes: 30));
    expect(TaskAlertKind.meal.followUpQuestion, contains('كلت'));
  });

  test('payloads round-trip through the route parser', () {
    for (final k in TaskAlertKind.values) {
      expect(NotificationRoute.parse(k.payload), isNotNull, reason: k.name);
    }
  });
}
```

- [ ] **Step 2: run it, watch it fail.**
- [ ] **Step 3: implement the enum** with one entry per row of Task 1's table,
      each naming its `alert_*` sound and a fresh `*_v1` channel id.
- [ ] **Step 4: run both this and Task 1's test — they should now pass.**
- [ ] **Step 5: commit**

```bash
git add tool/make_alert_sounds.py android/app/src/main/res/raw lib/core/notifications/task_alert.dart test/core/notifications/
git commit -m "feat(sounds): a distinct tone for every task, generated not downloaded"
```

---

## Task 3: the channels

**Files:**
- Modify: `lib/core/notifications/notification_channels_ids.dart`
- Modify: `lib/core/notifications/notification_channels.dart`
- Test: `test/core/notifications/notification_channels_test.dart`

**The trap.** Android freezes a channel's sound at creation and silently ignores
later changes. `notification_channels_ids.dart` already says so. So each new
channel is born `_v1` and any future sound change bumps it.

- [ ] **Step 1: write the failing tests**

```dart
  test('every alert kind has a channel in the channel list', () {
    final defined = nouriChannels.map((c) => c.id).toSet();
    for (final k in TaskAlertKind.values) {
      expect(defined, contains(k.channelId), reason: k.name);
    }
  });

  test('every channel carries its own sound resource', () {
    for (final k in TaskAlertKind.values) {
      final c = nouriChannels.firstWhere((c) => c.id == k.channelId);
      expect(c.sound, isA<RawResourceAndroidNotificationSound>(), reason: k.name);
    }
  });

  test('allChannelIds lists every one, so none is orphaned in settings', () {
    for (final c in nouriChannels) {
      expect(allChannelIds, contains(c.id), reason: c.id);
    }
  });

  test('a task alert never lands on the adhan channel', () {
    // The adhan is the loudest thing Nouri owns and bypasses nothing else.
    for (final k in TaskAlertKind.values) {
      expect(k.channelId, isNot(channelAdhan), reason: k.name);
    }
  });
```

- [ ] **Step 2–4:** run (fail), add the channels built from the registry, run
      (pass).
- [ ] **Step 5: commit.**

---

## Task 4: which alerts a planned day produces

**Files:**
- Create: `lib/core/notifications/task_alarm_plan.dart`
- Test: `test/core/notifications/task_alarm_plan_test.dart`

Pure, like `planDay` itself: a `DayPlan` in, a list of `(when, kind, taskId)`
out. No database, no clock, no providers — so a day's alerts are entirely a
function of the plan, and the tests can state real times.

**Interfaces:**
- Produces: `class TaskAlert { DateTime when; TaskAlertKind kind; String taskId; }`
- Produces: `List<TaskAlert> taskAlertsFor(DayPlan plan)`

- [ ] **Step 1: write the failing tests**

```dart
  test('the tasbeeh alert lands at the time the plan gave it', () {
    // The user's own example: "tasbih time according to the plan ... it will
    // be 1 pm; when time 1 pm send me notification".
    final plan = planDay(
      date: day, shift: ShiftPattern.morning, prayers: prayers,
      tasks: dailyTasksFor(date: day, shift: ShiftPattern.morning),
    );
    final tasbeeh = plan.allTasks.firstWhere((t) => t.task.id == 'tasbeeh');
    final alert = taskAlertsFor(plan).firstWhere((a) => a.taskId == 'tasbeeh');
    expect(alert.when, tasbeeh.start);
  });

  test('every placed task gets exactly one alert', () {
    final plan = planDay(/* as above */);
    final alerts = taskAlertsFor(plan);
    for (final t in plan.allTasks) {
      if (t.task.id.startsWith('prayer-')) continue; // the adhan already does these
      expect(alerts.where((a) => a.taskId == t.task.id).length, 1,
          reason: t.task.id);
    }
  });

  test('prayers are not doubled — the adhan already announces them', () {
    final plan = planDay(/* as above */);
    expect(taskAlertsFor(plan).where((a) => a.taskId.startsWith('prayer-')),
        isEmpty);
  });

  test('a deferred task is not announced', () {
    // Nouri never asks for something it has already said does not fit today.
    final plan = planDay(/* a saturated day */);
    final deferredIds = plan.deferred.map((d) => d.task.id).toSet();
    for (final a in taskAlertsFor(plan)) {
      expect(deferredIds, isNot(contains(a.taskId)));
    }
  });

  test('alerts come out in time order', () {
    final alerts = taskAlertsFor(planDay(/* as above */));
    for (var i = 1; i < alerts.length; i++) {
      expect(alerts[i].when.isBefore(alerts[i - 1].when), isFalse);
    }
  });
```

- [ ] **Step 2–4:** run (fail), implement, run (pass).
- [ ] **Step 5: commit.**

---

## Task 5: arming them

**Files:**
- Modify: `lib/core/notifications/notification_slot.dart`
- Modify: `lib/core/notifications/rolling_window_scheduler.dart`
- Modify: `lib/core/notifications/scheduling_config_from_db.dart`
- Test: `test/core/notifications/task_alarms_test.dart`

**The budget.** Armed over `kTaskAlarmWindowDays = 3`, not 14. The phone carries
~249 of Android's ~500; 10 tasks × 14 days would be 140 more and a nudge to walk
eleven days out is worth nothing to anyone. Three days matches the follow-ups
and costs ~30.

**Slots.** One per alert kind, appended: `taskAlert0 … taskAlert17`, plus
`taskFollowUp0 … taskFollowUp17`. That is 36 more against `kSlotsPerDay = 64`
with 33 used — **which does not fit.** Raise `kSlotsPerDay` to 128 in this task,
with the same reasoning already written on the constant: `cancelAllBelow`
enumerates pending ids rather than recomputing them, so the first re-arm after
the upgrade clears the old numbering. Re-verify on the phone in Task 10 by
checking the count does not roughly double.

- [ ] **Step 1: write the failing tests**

```dart
  test('a task alarm is armed for each task, over three days not fourteen',
      () async {
    await scheduler.rearm(config.copyWith(notifyTasks: true, plan: aPlan));
    final taskAlarms = gateway.scheduled.where((n) => n.payload!.startsWith('task:'));
    expect(taskAlarms.map((n) => dayOf(n.when)).toSet().length,
        kTaskAlarmWindowDays);
  });

  test('each one carries its own channel, so each one sounds different',
      () async {
    await scheduler.rearm(config.copyWith(notifyTasks: true, plan: aPlan));
    final byPayload = <String, String>{};
    for (final n in gateway.scheduled.where((n) => n.payload!.startsWith('task:'))) {
      byPayload[n.payload!] = n.channelId;
    }
    expect(byPayload.values.toSet().length, byPayload.length,
        reason: 'two tasks sharing a channel would sound identical');
  });

  test('turning task alarms off arms none of them', () async {
    await scheduler.rearm(config.copyWith(notifyTasks: false, plan: aPlan));
    expect(gateway.scheduled.where((n) => n.payload!.startsWith('task:')),
        isEmpty);
  });

  test('the whole window still fits Android\'s pending-alarm cap', () async {
    // Measured, not assumed: the phone was at 249 before this slice.
    await scheduler.rearm(config.copyWith(notifyTasks: true, plan: aPlan));
    expect(gateway.scheduled.length, lessThan(400));
  });

  test('nothing is armed into the past', () async {
    await scheduler.rearm(config.copyWith(notifyTasks: true, plan: aPlan));
    for (final n in gateway.scheduled) {
      expect(n.when.isAfter(now), isTrue, reason: '${n.slot} at ${n.when}');
    }
  });
```

- [ ] **Step 2–5:** run (fail); raise the stride; append the slots; arm from
      `taskAlertsFor`; run (pass); commit.

---

## Task 6: tapping it opens that task

**Files:**
- Modify: `lib/core/notifications/notification_route.dart`
- Modify: wherever `NotificationRoute` is acted on
- Test: `test/core/notifications/notification_route_test.dart`

> "when time 1 pm send me notification and open the app to do it"

- [ ] **Step 1: write the failing tests**

```dart
  test('a task payload routes to that task', () {
    expect(NotificationRoute.parse('task:walk'), const TaskRoute('walk'));
  });

  test('the walk alert opens the walk screen, not Home', () {
    expect(screenFor(const TaskRoute('walk')), isA<WalkScreen>());
  });

  test('the meal alert opens the meal log', () {
    expect(screenFor(const TaskRoute('first-meal')), isA<LogMealSheet>());
  });

  test('an unknown task id does not throw', () {
    // An alarm from an older version can still be sitting in AlarmManager.
    expect(NotificationRoute.parse('task:nonsense-from-2025'), isNotNull);
    expect(() => screenFor(const TaskRoute('nonsense')), returnsNormally);
  });
```

- [ ] **Step 2–5:** run, implement, run, commit.

---

## Task 7: snooze five minutes, as many times as you like

**Files:**
- Create: `lib/core/notifications/snooze.dart`
- Modify: `lib/main.dart` (register the background handler)
- Modify: `lib/core/notifications/local_notification_gateway.dart` (the action)
- Test: `test/core/notifications/snooze_test.dart`

> "i can late it 5 mins many times"

**The trap this must not repeat.** `local_notification_gateway.dart` records
that the «صليت» action was once `showsUserInterface: false`, which routes the
tap to a **background isolate** — and no background handler was ever registered,
so the button did nothing at all. Snooze must not open the app (that defeats the
point), so this time the handler is actually registered:
`onDidReceiveBackgroundNotificationResponse` with a top-level
`@pragma('vm:entry-point')` function that re-initialises the plugin in that
isolate and schedules one notification five minutes out.

- [ ] **Step 1: write the failing tests**

```dart
  test('snoozing schedules the same alert five minutes later', () {
    final next = snoozedTime(from: DateTime(2026, 9, 8, 13, 0));
    expect(next, DateTime(2026, 9, 8, 13, 5));
  });

  test('snoozing twice moves it ten minutes, not five', () {
    // "many times" — each snooze is from *now*, so they accumulate.
    var t = snoozedTime(from: DateTime(2026, 9, 8, 13, 0));
    t = snoozedTime(from: t);
    expect(t, DateTime(2026, 9, 8, 13, 10));
  });

  test('a snoozed alert keeps its own sound', () {
    final n = snoozedNotification(
      kind: TaskAlertKind.water, taskId: 'water', from: DateTime(2026, 9, 8, 13, 0));
    expect(n.channelId, TaskAlertKind.water.channelId);
  });

  test('the snooze id never collides with the window', () {
    final n = snoozedNotification(
      kind: TaskAlertKind.water, taskId: 'water', from: DateTime(2026, 9, 8, 13, 0));
    expect(n.id, greaterThanOrEqualTo(kSnoozeIdBase));
    expect(n.id, lessThan(kOutOfWindowIdBase));
  });

  test('snoozing across midnight lands on the right day', () {
    expect(snoozedTime(from: DateTime(2026, 9, 8, 23, 58)),
        DateTime(2026, 9, 9, 0, 3));
  });
```

- [ ] **Step 2–5:** run, implement, run, commit. Note `kSnoozeIdBase` needs a
      home in the id map between the window and `kOutOfWindowIdBase`; document
      it on the constant the way the others are.

---

## Task 8: "did you eat?"

**Files:**
- Create: `lib/features/tasks/task_done_dao.dart` (schema v11, `task_completions`)
- Modify: `lib/core/notifications/rolling_window_scheduler.dart`
- Test: `test/features/tasks/task_follow_up_test.dart`

> "after 30 mins ask me are you ate? like that for all tasks"

Prayers already have this shape — `followUpsFor`, and logging one cancels its
asks. This generalises it: a task alert whose kind has a `followUpAfter` arms a
second, softer notification, and marking the task done cancels it.

- [ ] **Step 1: write the failing tests**

```dart
  test('the meal is asked about thirty minutes later', () async {
    await scheduler.rearm(config.copyWith(notifyTasks: true, plan: aPlan));
    final meal = alarmFor('task:first-meal');
    final ask = alarmFor('taskask:first-meal');
    expect(ask.when.difference(meal.when), const Duration(minutes: 30));
  });

  test('the question is a question, and it is soft', () async {
    final ask = alarmFor('taskask:first-meal');
    expect(ask.body, contains('؟'));
    expect(ask.channelId, TaskAlertKind.followUp.channelId);
  });

  test('marking it done cancels the ask, like logging a prayer does', () async {
    await dao.markDone(date: today, taskId: 'first-meal');
    await controller.onTaskDone('first-meal');
    expect(gateway.cancelled, contains(idFor('taskask:first-meal')));
  });

  test('a task with no follow-up is not asked about', () async {
    // Not everything wants a question. Phone time already reports itself.
    expect(TaskAlertKind.phone.followUpAfter, isNull);
    expect(gateway.scheduled.where((n) => n.payload == 'taskask:phone-time'),
        isEmpty);
  });
```

- [ ] **Step 2–5:** run, implement, run, commit.

---

## Task 9: five adhans

**Files:**
- Modify: `lib/core/notifications/notification_channels_ids.dart`
- Modify: `lib/core/notifications/rolling_window_scheduler.dart`
- Modify: `tool/install_adhan_sound.sh`
- Test: `test/core/notifications/adhan_channels_test.dart`

> "download different adhan for each prayer time, separate and different adhan
> sound, so i need at least now 5 adhans"

**What this task does and does not do.** It builds five separate adhan channels
— `adhan_fajr_v1`, `adhan_dhuhr_v1`, `adhan_asr_v1`, `adhan_maghrib_v1`,
`adhan_isha_v1` — each naming its own raw resource, and extends the install tool
to take five files. **It does not ship five recitations.** A synthesised adhan
would be worse than the placeholder; a downloaded one is a performance with a
rights holder; and *which* muezzin is a matter of taste and religious preference
— the same class of decision this project already leaves to the user in
`docs/fasting-verification.md`.

Until the user supplies files, all five resources point at the existing `chime`
and the settings screen says so in one line.

- [ ] **Step 1: write the failing tests**

```dart
  test('each prayer has its own adhan channel', () {
    for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      expect(adhanChannelFor(p), isNotNull, reason: p);
    }
    final ids = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']
        .map(adhanChannelFor).toSet();
    expect(ids.length, 5, reason: 'five prayers, five sounds');
  });

  test('the scheduler puts each adhan on its own channel', () async {
    await scheduler.rearm(config);
    for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      final n = gateway.scheduled.firstWhere((n) => n.payload == 'prayer:$p');
      expect(n.channelId, adhanChannelFor(p), reason: p);
    }
  });

  test('until real recitations are installed, they share the placeholder', () {
    // Honest rather than silent: the app must not pretend to five adhans it
    // has not got.
    for (final p in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      expect(adhanSoundFor(p), 'chime');
    }
  });

  test('the old single adhan channel is retired, not left in settings', () {
    expect(retiredChannelIds, contains('adhan_v2'));
  });
```

- [ ] **Step 2–5:** run, implement, run, commit.

- [ ] **Step 6: extend `tool/install_adhan_sound.sh`** to
      `install_adhan_sound.sh <prayer> <file.ogg>`, validating the prayer name
      and printing the channel bump needed.

---

## Task 10: on the phone

The alarm budget and the sounds are both things only the device can settle.

- [ ] **Step 1:** stop the emulator, `flutter build apk --release`, install on
      the HONOR **after a prayer, not just before one**.
- [ ] **Step 2: the count.** `adb shell dumpsys alarm | grep -c
      "walarm\*:com.nouri.nouri"`. It was 249. It must land near 295 and
      **must not roughly double** — a doubling means the `kSlotsPerDay` 64→128
      change orphaned the old numbering.
- [ ] **Step 3: the sounds are in the APK.**
      `unzip -l build/app/outputs/flutter-apk/app-release.apk | grep raw/` —
      all 18 present, none stripped by R8.
- [ ] **Step 4: the channels exist and carry their sounds.**
      `adb shell dumpsys notification --noredact | grep -A1 alert_` — each
      channel's `mSound` names its own resource.
- [ ] **Step 5: hear one.** Ask the user to run it — this is the whole point of
      the slice and cannot be verified by dumpsys.

---

## Self-review

**Spec coverage.** Alarm per task at the planned time → Tasks 4, 5. Opens the
app on that task → Task 6. Snooze 5 min repeatedly → Task 7. "Did you eat?"
after 30 min → Task 8. A sound per task → Tasks 1, 2, 3. Five adhans → Task 9.

**The one requirement not fully met, and why.** "Download this alarms" — the
non-adhan tones are *generated* rather than downloaded, which is better on every
axis that matters here (licence, size, retunability) and meets the actual goal
of telling tasks apart by ear. The five adhan *recitations* are not supplied at
all; that needs the user's choice of muezzin and a licence, and Task 9 builds
everything around them so installing five files is the only remaining step.

**Type consistency.** `TaskAlertKind` (Task 2) is used by Tasks 3, 4, 5, 7, 8.
`TaskAlert`/`taskAlertsFor` (Task 4) by Task 5. `TaskRoute` (Task 6) parses the
`task:` payloads Task 5 writes. `kSnoozeIdBase` (Task 7) sits between the window
and `kOutOfWindowIdBase`. `adhanChannelFor`/`adhanSoundFor` (Task 9) only.

**Not in this plan.** Re-planning around a missed task, and marking a task done
*from the plan* — both are still the open decisions recorded in
`docs/planner-decisions.md`. Task 8 adds `task_completions`, which is the
storage those would need, but does not decide where the truth lives.
