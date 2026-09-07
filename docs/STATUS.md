# Nouri — status

Last updated **7 September 2026**, overnight session.

| | |
|---|---|
| Branch | `slice1-religious-core` — **not merged to `master`** |
| Head | `b78671e`, working tree clean |
| Tests | **837 passing**, `flutter analyze` clean |
| On the phone | build from 15:20 on 6 Sep (HONOR VNE-N41) — **two days stale** |
| On the emulator | current build, `nourdm-api35` |
| Schema | v8 |

`master` stays clean until Slice 1 is tested and merging is approved.

---

## Pillars

| Pillar | State |
|---|---|
| **الديني** religious | Built. Prayers, athkar, tasbeeh, wird, adhan + iqama alarms, follow-ups, daily review. Qur'anic athkar now set as a mushaf page. |
| **البدني** physical | Built. 16/8 window, meal log with symptom, weight, walking sessions, guided home workouts, sunnah fasting reminders, **water**. Now placed by the planner. |
| **المالي** financial | Built. Pay-cycle month, budgets, expenses, savings rate. |
| **تطوير الذات** self-development | **Tracking built.** Knowledge time logged on Home, in the report, and placed by the planner. The *recommending* — books, a skill path — is AI work for Slice 5. |
| **الوقت والدوام** time & duty | **Built.** The planner places the day from the shift and the prayer times; Home shows it. Calendar reminders too. |
| **المتابعة والذكاء** tracking & AI | Reports now cover **all three logged pillars** plus **challenges**. The Claude layer is Slice 5, unstarted. |

## What runs today

- 230 exact alarms over a rolling 14-day window; follow-ups over 3 days
- Adhan on `adhan_v2` at HIGH with a full-screen intent — wakes a locked screen
- Prayer logging from Home, from the review sheet, and from a notification tap
- **Calendar reminders** — pick a day, write what to be reminded of, once or
  daily/weekly/monthly. One alarm per reminder, re-armed on every launch.
- **Walking sessions** — steps, distance, pace and calories, live
- **Home workouts** — three routines, work/rest intervals, animated figures
- **Challenges** — seven, evaluated from the logs already kept
- **Sunnah fasting** — Mondays, Thursdays and the white days, offered at 20:00
  the evening before, with the prohibited days excluded
- **Reports across البدن والمالية** as well as the religious summary
- **The planned day** — blocks, times and what sits in them, decided by
  `planDay` from the shift and the day's prayers, re-planned from now
- **Water** — a count against a target in البدن, and a nudge after each prayer
  that disappears between fajr and maghrib on a day marked as a fast
- **Knowledge time** — reading, skill or religious content, logged on Home and
  totalled in the weekly report as minutes *and* days
- **Onboarding asks which shift**, so the first day Nouri shows is the right
  shape rather than a morning guess
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
  inside البدن, challenges inside التقارير, the planned day inside Home.
- **The shift is a single setting, not a rota.** The brief describes a rotating
  pattern; guessing at one would put wrong times in front of the user daily.
  Set today's shift in الإعدادات → الدوام.
- **The planned day is read-only.** Blocks expand to show their hours; nothing
  is tapped done from there yet. Prayers are still logged from Home and from
  the notification.
- **Untested on real hardware:** reboot survival, battery-kill, multi-day
  reliability, and every one of tonight's five features. Emulator results say
  nothing about MagicOS.
- **`docs/athkar-verification.md` has not been checked by a human** against a
  printed حصن المسلم. The mushaf rendering did not change a letter of it —
  enforced by a test — so that review is still valid and still outstanding.
- **The sunnah fasting days have not been reviewed by a person.**
  `docs/fasting-verification.md` lists what is and is not covered and asks for
  that review. عرفة, عاشوراء and الست من شوال are deliberately absent — the
  brief does not name them and choosing which to add is a religious judgement.
- A counter like the athkar repeat pill reads «٣ / ٠» at zero of three,
  because RTL lays the slash form out right to left. Pre-existing, app-wide,
  and left alone rather than fixed on one screen — see the handoff.

## Guards that fail the build

Invariants worth more as a failing test than as a comment. Each one's regex is
itself tested both ways, so none can pass vacuously.

| Guard | What it stops |
|---|---|
| `no_network_test` | Slice 1 reaching the network; `INTERNET` in a release APK |
| `day_stepping_test` | `add(Duration(days:))` — the DST bug, found three times |
| `counter_form_test` | «٠ / ٣» counters, which read backwards in RTL |
| `palette_test` | A red anywhere, and colour defined outside the palette |
| `notification_receivers_test` | The boot receiver going missing |
| `notification_sound_test` | The adhan sound and channel drifting apart |

## Decisions already made (do not relitigate)

- Prayer log states are append-only; reordering rewrites history. Same for
  `MealFeeling`, `ReminderRepeat` and `KnowledgeKind`.
- **Anything day-scoped watches `currentDayProvider`**, never `DateTime.now()`
  directly. It changes once a day, so the app turns over at midnight instead
  of showing yesterday until something else invalidates it — which matters
  because the user works nights.
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
- **The planner's six open questions are answered** in
  `docs/planner-decisions.md`, each the safest reversible way, each a setting
  or a constant away from changing.
- **A fasting day is the user's word, never inferred.** Nouri suggests the
  sunnah fasts but cannot know whether one was kept, and guessing wrong means
  nudging a fasting person to drink at noon.
- **The notification slot space is full** — 31 of `kSlotsPerDay` = 32. Raising
  it renumbers every alarm already on a device, so it needs a deliberate
  re-arm rather than a quiet bump.
- **Nouri recommends nothing.** No book, no skill path, no reading of the
  week. All of it is AI work for Slice 5, and every screen asks rather than
  claims — tests assert it makes no such claim.
- Nothing is ever marked failed, and nothing is ever red.

## Where things live

```
docs/setup.md          toolchain, timezone handling, adhan sound swap
docs/install.md        device checks; 40-47 are the adhan_v2 ones, 48-56 Slice 1b
docs/STATUS.md         this file
docs/superpowers/handoffs/    dated session handoffs
docs/planner-decisions.md     the six Slice 2 answers, and why each is reversible
docs/fasting-verification.md  the sunnah fasting days, awaiting a human read
docs/superpowers/plans/       2026-09-07-slice1b-five-features.md is tonight's
docs/superpowers/specs/       slice2-worked-example.md holds the open questions
tool/install_adhan_sound.sh   validates and installs an adhan recording
```
