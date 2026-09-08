# The phone install, and what reading it back found · 8 September 2026

Follows `2026-09-09-slice6-tasks-and-the-adhan.md`. You reconnected the HONOR
and asked to see المهام and hear the adhans. This is what went on the phone,
what I could prove without touching it, and the two faults that reading the
device found — neither of which any test in the suite could have caught.

**1118 tests passing**, `flutter analyze` clean, schema **v11**. Branch
`slice1-religious-core`, still **not merged to `master`**. Head `ba62f13`.

---

## On your phone now

Installed **19:43**, after isha (19:20) and after the iqama (19:35) — the
project's rule is to install after a prayer, never just before one.

The APK on the device is **byte-identical** to the one built here
(`md5 04c9feaa…`), which is worth stating because "installed" and "installed
the thing you think" are different claims.

What is new on it since the Slice 4 build it had been running:

- **المهام**, the day's list
- **Nineteen task tones**, one per kind
- **Five adhans**, one per prayer
- **`ActionBroadcastReceiver`** — so «فكّرني بعد ٥ دقايق» works on your phone
  for the first time. It was dead before, silently
- **The step-sensor fix** — البدن → امشي now offers «اسمح لنوري» instead of
  claiming there is no sensor

### Read back off the device, not assumed

```
adhan_fajr_v2     sound=adhan_fajr      deleted=false
adhan_dhuhr_v2    sound=adhan_dhuhr     deleted=false
adhan_asr_v2      sound=adhan_asr       deleted=false
adhan_maghrib_v2  sound=adhan_maghrib   deleted=false
adhan_isha_v2     sound=adhan_isha      deleted=false
adhan_v1, adhan_v2                      deleted=true
19 × alert_*      19 distinct sounds    deleted=false
```

Five recitations, nineteen tones, every placeholder-era channel retired.
**271 alarms armed**, up from 226 on the old build — the rise is the task
alarms. All three receivers are in the shipped manifest, confirmed by dumping
the APK's own manifest rather than by trusting the source.

`POST_NOTIFICATIONS` is not a runtime permission on Android 12, so the trap
that had silently swallowed every emulator alarm for weeks does not apply
here.

---

### المهام, seen on your phone at 20:04

Not the emulator — your HONOR, your data, your day:

```
٤ من ١٠ خلصوا النهاردة · لسه فيه وقت
ورد القرآن — ربع   ٤:٠٠   ✓ تمّت
مشي ٣٠ دقيقة       ٤:٥٥   ✓ تمّت
أذكار المساء       ٦:١٨     لسه
تسبيح              ٦:٣٨   ✓ تمّت
أول وجبة           ٧:٣٥     دلوقتي   ← the gold edge
استماع لمحاضرة     ٨:١٠     جاية
وقت الموبايل       ٨:٤٥   ✓ تمّت
آخر وجبة          ١٠:٠٠     جاية
مكالمات           ١٠:٣٥     جاية
```

All five states drawn, nothing red, no «فاتتك» anywhere, and the thing to be
doing now is the one carrying the gold border. **٢٥٩ alarms armed** after the
fix — down exactly twelve from 271, which is the four duplicated tasks over
the three-day task window and nothing else. `iqama_v1` reads `mDeleted=true`
on the device, so it has stopped cluttering your notification settings.

## What reading the device found

Both of these were **live on your phone**, and both undo the one thing the
nineteen sounds are for — *«from the sound i know what this task is»*.

### 1. The athkar and the wird rang twice a day

Slice 5 gave the four of them their own alarms off the day plan, on their own
channels, at the times المهام shows. It left the **Slice-1 reminders for the
same four things armed beside them** — on the shared `athkar_v1` / `wird_v1`,
with the **system default tone**, at a **different time**: those come from a
fixed settings hour, the plan's come from a prayer anchor.

So: two rings a day for one task, and whichever you heard first disagreed with
what the screen said. Directly against what you asked for — *"use the Tasks
tab as the single source of truth for normal task reminders"*.

`task_alarm_plan.dart` already refuses to do exactly this to prayers, and its
comment says why: *"two notifications for one prayer, seconds apart, with
different sounds"*. Nobody had applied the same argument to anything else.

The legacy path is **gated, not deleted**, and the gate has two halves:

```dart
cfg.notifyAthkar && (!cfg.notifyTasks || i >= kTaskAlarmWindowDays)
```

It is what someone who wants the athkar announced without the whole day
announcing itself still gets — and it is the **safety net past day three**.
The task alarms reach three days, by your own instruction; these reach
fourteen. Gating on `notifyTasks` alone would have quietly cut the athkar and
the wird from a fortnight to three days for anyone who did not open Nouri over
a long weekend. Past the task window there is no duplicate to avoid, so the
old reminder stands in — with the generic tone, replaced by the task alarm the
moment you next open the app.

### 2. Seven of the nineteen tones had nothing that could play them

`alert_iqama_v2`, `alert_qiyam_v1`, `alert_water_v1`, `alert_budget_v1`,
`alert_fasting_v1`, `alert_review_v1` and `alert_reminder_v1` each shipped a
tone in the APK and created a row in your system notification settings — and
**nothing ever fired on any of them**. The things they were made for were
still going out on `general_v1` with the default sound.

The worst of them is the **iqama**: the one notification that most needs to be
told apart from the adhan sounded like every other app on your phone.

Each is routed to its own channel now, and `iqama_v1` is retired so it stops
cluttering your settings.

> **A judgment call you can reverse in one line.** You said to keep
> "prayer/adhan/iqama separate and unchanged". I read that as *keep them out
> of the task system* — which they still are — rather than *never give the
> iqama a sound*. The channel had been built and version-bumped for exactly
> this and then never used. If you would rather the iqama went back to the
> system default, say so and it is one constant.

### Why no test caught either

Nothing in the suite knew that a **bundled sound ought to be reachable**, or
that **a task ought to ring once**. `one_sound_per_thing_test` now fails on
both: it walks every `TaskAlertKind` and asserts something fires on its
channel, and it counts the rings per task per day. Two exemptions are written
down with their reasons — reminders (armed by a different scheduler) and
workout (the planner does not place one yet).

---

## Not done, and why

**No adhan has been played on your phone.** You were on a call from 19:24
through the whole session — Messenger held the audio mode — and an adhan is
loud. Firing one into a call would have been the wrong call to make on your
behalf. Say the word and it takes a few seconds.

**الأصوات has not been opened on the phone.** It is installed and its tests
pass, but you asked me to stop with ten minutes to go, so the screen itself
has only been seen in a widget test. Everything else above was watched on the
device.

Throughout, the rule from the earlier incident held: no screenshot and no tap
without first confirming `mCurrentFocus` is Nouri. While you were on the call
and in WhatsApp, Gmail and Facebook, everything came from `dumpsys` instead.

---

## And a way to answer the questions I keep asking you

**الإعدادات → الأصوات.** Every adhan and every task tone, each with a «شغّل».

You have been asked in three handoffs running which adhan carries «الصلاة خير
من النوم» and which of the nineteen tones do not read — and there was no way
to answer either without living with the app for a day and remembering what
each sound was. Now it is two minutes on the sofa.

It posts a real notification on the real channel rather than playing the file
through an audio player, because Android reads a sound off its **channel** —
so what you hear is the actual file, at the actual volume, through any change
you have made to that channel in your own system settings. The full-screen
takeover is dropped for previews only; comparing five adhans that each seize
the screen would be unusable.

Each adhan carries its credit next to the button as well as in عن نوري. Four
of the five are CC BY or CC BY-SA, where attribution is a condition of use.

## Still needing you

Unchanged from the Slice 6 handoff, in priority order:

1. **Listen to the five adhans** in الإعدادات → الأصوات, and say whether the
   fajr one carries «الصلاة خير من النوم». Religious content — it waits for a
   person.
2. **Listen to the nineteen tones** on the same screen and say which do not
   read. They are synthesised, so any of them can be retuned by editing one
   line of `tool/make_alert_sounds.py`.
3. **The DND finding**, which matters most for a night worker: all five
   `adhan_*_v2` channels have `mBypassDnd=false`, so DND silences the adhan.
   Nouri cannot set it — `flutter_local_notifications` does not expose
   `bypassDnd`. One manual toggle in system settings fixes it.
4. **Grant `ACTIVITY_RECOGNITION`** — البدن → امشي → «اسمح لنوري» — or the
   step counter stays dark.
5. The seven-tab question, the rota, whether the plan should be a place to
   log, `docs/fasting-verification.md`, `docs/athkar-verification.md`.

## One thing measured that is worth knowing

MagicOS creates the adhan channels at **importance 4, not the 5 the app asks
for**, and locks the field within seconds (`mUserLockedFields=4`,
`mOriginalImp=5`). HIGH is still heads-up with sound, and the full-screen
intent is independent of it, so nothing is lost — but a future channel bump
will land at HIGH again. That is device policy, not a bug to chase.
