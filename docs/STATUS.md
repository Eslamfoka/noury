# Nouri — status

Last updated **7 September 2026**, overnight session.

| | |
|---|---|
| Branch | `slice1-religious-core` — **not merged to `master`** |
| Head | `b4950d9`, working tree clean |
| Tests | **668 passing**, `flutter analyze` clean |
| On the phone | build from 15:20 on 6 Sep (HONOR VNE-N41) — **two days stale** |
| On the emulator | current build, `nourdm-api35` |
| Schema | v4 |

`master` stays clean until Slice 1 is tested and merging is approved.

---

## Pillars

| Pillar | State |
|---|---|
| **الديني** religious | Built. Prayers, athkar, tasbeeh, wird, adhan + iqama alarms, follow-ups, daily review. Qur'anic athkar now set as a mushaf page. |
| **البدني** physical | Built. 16/8 window, meal log with symptom, weight, **walking sessions**, **guided home workouts**. No planner integration yet. |
| **المالي** financial | Built. Pay-cycle month, budgets, expenses, savings rate. |
| **تطوير الذات** self-development | **Not started.** §5.3 of the brief. |
| **الوقت والدوام** time & duty | Models only, plus **calendar reminders**. The planner itself is Slice 2. |
| **المتابعة والذكاء** tracking & AI | Reports are religious-only, plus **challenges**. The Claude layer is Slice 5, unstarted. |

## What runs today

- 230 exact alarms over a rolling 14-day window; follow-ups over 3 days
- Adhan on `adhan_v2` at HIGH with a full-screen intent — wakes a locked screen
- Prayer logging from Home, from the review sheet, and from a notification tap
- **Calendar reminders** — pick a day, write what to be reminded of, once or
  daily/weekly/monthly. One alarm per reminder, re-armed on every launch.
- **Walking sessions** — steps, distance, pace and calories, live
- **Home workouts** — three routines, work/rest intervals, animated figures
- **Challenges** — seven, evaluated from the logs already kept
- Finance and body tabs, both writing to the local database
- No network calls at all — `INTERNET` is removed from the manifest

## Known limits, stated plainly

- **`chime.wav` is a 1.90 s placeholder, not an adhan.** Still the single
  biggest gap.
- **MagicOS caps the adhan channel at HIGH**, not MAX, and re-locks it within
  seconds of creation. HIGH is enough for the full-screen intent. A future
  channel bump will land at HIGH again — that is device policy, not a bug.
- **The phone's build is from 6 September** and has none of tonight's work,
  nor the follow-up cancellation fix. It needs a reinstall.
- **The step counter needs hardware Nouri cannot assume.** The emulator has no
  `TYPE_STEP_COUNTER`, so the walk screen says so and offers a clearly labelled
  simulated run only when the opt-in switch in الإعدادات is on. **The real
  sensor path has never run on real hardware.**
- **A walk is only counted while its screen is open.** Android keeps counting
  in the OS, so a backgrounded session reconciles correctly on resume, but
  there is no foreground service and a killed app loses the session.
- **Six bottom tabs**, one past Material's recommendation. Nothing was added
  tonight: the calendar opens from the Home header, walking and workouts sit
  inside البدن, challenges inside التقارير.
- **Untested on real hardware:** reboot survival, battery-kill, multi-day
  reliability, and every one of tonight's five features. Emulator results say
  nothing about MagicOS.
- **`docs/athkar-verification.md` has not been checked by a human** against a
  printed حصن المسلم. The mushaf rendering did not change a letter of it —
  enforced by a test — so that review is still valid and still outstanding.
- Reports covers the religious pillar plus challenges; body and wealth still
  appear nowhere in it.
- A counter like the athkar repeat pill reads «٣ / ٠» at zero of three,
  because RTL lays the slash form out right to left. Pre-existing, app-wide,
  and left alone rather than fixed on one screen — see the handoff.

## Decisions already made (do not relitigate)

- Prayer log states are append-only; reordering rewrites history. Same for
  `MealFeeling` and `ReminderRepeat`.
- Alarms are scheduled in **UTC** — the plugin's zone round-trip disagreed with
  the device's tzdata and moved the adhan by an hour.
- Dates are **constructed, never offset**. `add(Duration(days: 1))` is 24 hours,
  which broke the pay cycle across Egypt's DST.
- **The rolling window clears only its own ID range.** `rearm()` used
  `cancelAll()`, which would have deleted every reminder on the next settings
  change. Reminders are numbered from `kOutOfWindowIdBase` (900,000,000)
  upward, which the window does not reach until roughly 2098.
- `MainActivity` stays **behind the keyguard**. Showing it over the lock screen
  would expose the prayer log and المالية. See
  `docs/superpowers/specs/slice2-worked-example.md`.
- No calorie counting for food, and no naming a cause for a symptom. The
  walking estimate is a different thing and is labelled «تقريبية».
- Challenge progress is **derived, never stored**.
- Nothing is ever marked failed, and nothing is ever red.

## Where things live

```
docs/setup.md          toolchain, timezone handling, adhan sound swap
docs/install.md        device checks; 40-47 are the adhan_v2 ones, 48-56 Slice 1b
docs/STATUS.md         this file
docs/superpowers/handoffs/    dated session handoffs
docs/superpowers/plans/       2026-09-07-slice1b-five-features.md is tonight's
docs/superpowers/specs/       slice2-worked-example.md holds the open questions
tool/install_adhan_sound.sh   validates and installs an adhan recording
```
