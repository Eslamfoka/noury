# Slice 5 — the day speaks · 8 September 2026

Read `docs/STATUS.md` for where the project stands, and
`docs/superpowers/handoffs/2026-09-09-slice4.md` for what came immediately
before. This file is Slice 5: the planned day announcing itself.

The plan is `docs/superpowers/plans/2026-09-08-slice5-the-day-speaks.md`.

---

## What you asked for, and what is built

> *"i don't need to open the app to know what i have to do, i need alarms for
> each task ... from alarms i know what this task"*

| # | Asked | State |
|---|---|---|
| 1 | An alarm for every planned task, at its planned time | **Built** |
| 2 | Tapping it opens that task's screen | **Built** |
| 3 | «Snooze 5 minutes», working with the app closed, repeatable | **Built** |
| 4 | Follow-ups where they make sense, meals especially | **Built** |
| 5 | A distinct sound per category | **Built** — nineteen |
| 6 | Do not touch adhan audio without approval | **Honoured** — untouched |
| 7 | Short window for tasks; snoozes only on press | **Built** — three days |
| 8 | Emulator only; nothing on the phone | **Honoured** |

---

## The one fact that shaped everything

**Android reads a notification's sound off its *channel*, not off the
notification.** So "a different sound for every task" and "a channel for every
task" are the same sentence. There are nineteen new channels, one per alert
kind, and `TaskAlertKind` is the single row that holds each one's sound,
channel, copy, route and follow-up. A test asserts no two share a sound or a
channel — otherwise the whole feature quietly collapses into one noise.

A channel's sound is also **frozen at creation**: Android ignores later changes
to the same id. That is why every id is versioned, and why changing a tone later
means `alert_water_v2`, not an edit.

## The sounds

**Generated, not downloaded.** `tool/make_alert_sounds.py` is committed and
re-runnable. No licence to honour, no attribution to track, nothing that can be
taken down, and any tone is retunable by editing one line. All nineteen together
are **788 KB** — less than one stock recording would have cost. The release APK
grew from 61.6 MB to 62.4 MB.

Several carry the shape of what they announce, which is what makes them
learnable rather than arbitrary:

| Sound | Shape |
|---|---|
| مياه | three drops, falling in pitch — water falls |
| مشي | four alternating steps |
| تمارين | three rising drives, brisker than the walk |
| وجبة | warm rising two-tone |
| تسبيح | three even bead taps |
| ورد القرآن | calm ascending triad, unhurried |
| أذكار الصباح | bright rising pair |
| أذكار المساء | **the exact mirror** — same two notes, reversed |
| أذكار النوم | low, slow, sinking |
| قيام الليل | one soft low tone; it arrives at 01:30 and must not startle |
| وقت المعرفة | a swell, then one chime |
| وقت الموبايل | two flat blips — deliberately the plainest thing here |
| مكالمات | gentle double ring |
| الميزانية | two low ticks, like coins set down |
| تذكير | a neutral bell |
| صيام | one gentle low tone |
| مراجعة اليوم | soft neutral two-tone |
| «عملتها؟» | the quietest and shortest — it is only asking |
| الإقامة | firm double knock |

**Alarm volume vs notification volume.** You asked for alarms, and a nudge at
notification volume on a phone in a pocket is not one — so anything that
summons you to *do* something uses alarm audio. The five that only *inform* stay
at notification volume: the budget note, the phone cap, the fasting offer, the
end-of-day review, and the soft «عملتها؟». Waking someone at alarm volume to
mention a budget would be the kind of app that gets uninstalled.

## The adhan is untouched

At your instruction. `chime` and `adhan_v2` are exactly as they were, no adhan
audio was downloaded, and the five-adhans-one-per-prayer task is **removed from
this slice** and left for a decision of yours. When you want it: it needs five
recitations you have chosen and are happy with the licence of, and a channel
each. Nothing in this slice blocks it.

---

## Window lengths, as you asked them documented

| What | Window | Why |
|---|---|---|
| Adhan, iqama, athkar, wird | **14 days** | Must survive the app going unopened. This is the whole point of the rolling window. |
| Prayer follow-ups | 3 days | "Did you pray asr?" is only worth asking of someone still using the app. |
| Water | 3 days | A nudge to drink twelve days out is worth nothing. |
| **Task alarms** | **3 days** | Your instruction, and the budget. The plan is recomputed every launch, so a fortnight of it would be stale anyway. |
| **Task follow-ups** | with their task | Same 3 days. |
| Budget note | 2 days | Budget state is not knowable ahead; two days is the most that can be honest. |
| قيام الليل | 14 days | Off by default; a standing invitation rather than a question. |
| **Snoozes** | **none — created on press only** | Exactly as you asked. |

**The alarm budget.** Android drops alarms somewhere past ~500, silently, which
is the worst way to find out. Measured: the phone carried 249 before this slice.
The task window costs **under 60** more, and a test pins the whole armed set
under 400. The adhan has first call on the budget and always will.

## The ID ranges, and why the boundaries matter

| Range | From | Cleared by a re-arm? |
|---|---|---|
| the rolling window | ~156,000, climbing | **yes** — that is the point |
| **task alarms** | 500,000,000 | **yes**, deliberately |
| reminders | 900,000,000 | no |
| **snoozes** | 950,000,000 | **no**, deliberately |

Task alarms *want* clearing: the plan is rebuilt on every launch and yesterday's
arrangement must not survive into today's. A snooze must *not* be — you pressed
it, and opening the app afterwards would otherwise silently take it away. That
one boundary is the difference between the snooze working and it being a lie.

---

## Two traps, one of them already sprung once

**Snooze cannot open the app**, because being dragged into a screen is the
opposite of putting something off. So it is `showsUserInterface: false`, which
Android delivers to a **background isolate** rather than to the running app.

**This project has already been caught by exactly that.** The «صليت» action was
written that way and no background handler was ever registered, so the button
did nothing at all — the note is still in `local_notification_gateway.dart`.
This time the handler exists, is top-level, and carries
`@pragma('vm:entry-point')` so the release tree-shaker cannot remove it. A new
guard states the implication directly — *any* silent action requires a
registered background handler — and it was proved by deleting the registration
and watching it fail.

Both paths work: Android hands the action to the running app when there is one
and to the isolate when there is not, and handling only the isolate would have
made the button work only while Nouri was closed.

**The bug the tests caught.** Alarm ids were first keyed on the alert *kind*,
and several tasks share a kind — both meals, all three faces of knowledge time.
So أول وجبة and آخر وجبة got the same id, the later silently overwrote the
earlier, and **the first meal of the day would never have been announced**. Ids
are keyed on the task now, through an append-only `alarmableTaskIds` whose order
is load-bearing and pinned by its own test.

---

## Decisions taken alone

1. **Both meals share one sound.** They mean the same thing — eat — and giving
   them different tones would teach a distinction that does not exist. Same for
   the three faces of knowledge time, which the planner already treats as one
   rotating block.
2. **Prayers are not double-announced.** The adhan has called them since Slice 1;
   a second notification seconds later with a different sound would be worse
   than none.
3. **A deferred task is never rung about.** If the plan has already said
   something does not fit today, Nouri does not then ring to demand it.
4. **وقت الموبايل is not asked about.** It reports itself on its card, and
   «قعدت على الموبايل؟» would be Nouri policing something it has no business
   policing.
5. **The workout has a sound but no planner slot yet.** You listed it as a
   category, so it has its own tone and channel ready; `dailyTasksFor` does not
   place a workout, so nothing is armed for it. When the planner does place one,
   it will already sound like itself.
6. **The snooze is five minutes measured from *now*.** Press it twice and the
   task moves ten minutes, not five — "many times" only means something if they
   accumulate.

---

## Verified on the emulator

Release APK on `nourdm-api35`. Nothing touched the phone.

**Nineteen channels, nineteen distinct sounds, none shared.** Read back off the
device rather than trusted from the source:

```
alert_water_v1            .../raw/alert_water
alert_walk_v1             .../raw/alert_walk
alert_workout_v1          .../raw/alert_workout
alert_meal_v1             .../raw/alert_meal
alert_tasbeeh_v1          .../raw/alert_tasbeeh
...                       (19 in all)
channels sharing a sound: none
distinct sounds: 19 of 19
```

That is the property the whole slice rests on. Two channels sharing a sound
would silently collapse two tasks into one noise, however different the files
were.

**The sounds survive R8.** All nineteen are in the release APK — AAPT2 shortens
the paths (`res/0I.wav` and so on) but the resource table still maps the names,
which is exactly what `res/raw/keep.xml` exists to guarantee. 1,116 KB of WAV
in total including the old chime; the APK went from 61.6 MB to 62.4 MB.

**The day is armed.** 294 alarms, up from 256 before this slice — the task
window costs **38**, comfortably inside Android's ~500. Thirty of them fall in
the rest of today, spread across the afternoon and evening as the plan places
them.

**The adhan is untouched**, checked rather than assumed:

```
mId='adhan_v2' ... mSound=android.resource://com.nouri.nouri/raw/chime
```

Same channel, same placeholder, same everything.

## Not verified anywhere

- **Nothing on the HONOR.** By your instruction, and the phone is on the Slice 4
  build.
- **No sound has been *heard*.** The channels are created with the right
  resources and the alarms are armed at the right times, but a tone is a thing
  only an ear can check. That is the one part of this slice that needs you.
- Whether nineteen tones are actually distinguishable **in practice**, which is
  a judgement rather than a test. Any of them is one line in
  `tool/make_alert_sounds.py` away from changing — but changing a sound means
  bumping its channel to `_v2`, because Android freezes the sound at creation.

## What needs you

1. **Listen to them**, and say which ones do not read. Retuning is cheap.
2. **The adhan decision**, when you want it: five recitations, chosen by you.
3. **Whether the planner should place a workout**, now that it has a sound.
4. Still outstanding from before: `docs/fasting-verification.md`,
   `docs/athkar-verification.md`, the rota, the adhan recitation, and the DND
   finding in the Slice 4 handoff — the adhan does not bypass Do Not Disturb,
   which matters when you sleep in the daytime.
