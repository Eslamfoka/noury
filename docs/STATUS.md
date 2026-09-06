# Nouri — status

Last updated **6 September 2026**, end of day.

| | |
|---|---|
| Branch | `slice1-religious-core` — **not merged to `master`** |
| Head | `dc05519`, pushed, working tree clean |
| Tests | **474 passing**, `flutter analyze` clean |
| On the phone | build from 15:20 (HONOR VNE-N41) |
| Schema | v3 |

`master` stays clean until Slice 1 is tested and merging is approved.

---

## Pillars

| Pillar | State |
|---|---|
| **الديني** religious | Built. Prayers, athkar, tasbeeh, wird, adhan + iqama alarms, follow-ups, daily review. |
| **البدني** physical | Built today. 16/8 window, meal log with symptom, weight. No planner integration yet. |
| **المالي** financial | Built. Pay-cycle month, budgets, expenses, savings rate. |
| **تطوير الذات** self-development | **Not started.** §5.3 of the brief. |
| **الوقت والدوام** time & duty | Models only. The planner itself is Slice 2. |
| **المتابعة والذكاء** tracking & AI | Reports are religious-only. The Claude layer is Slice 5, unstarted. |

## What runs on the phone today

- 230 exact alarms over a rolling 14-day window; follow-ups over 3 days
- Adhan on `adhan_v2` at HIGH with a full-screen intent — wakes a locked screen
- Prayer logging from Home, from the review sheet, and from a notification tap
- Finance and body tabs, both writing to the local database
- No network calls at all — `INTERNET` is removed from the manifest

## Known limits, stated plainly

- **`chime.wav` is a 1.90 s placeholder, not an adhan.** The single biggest gap.
- **MagicOS caps the adhan channel at HIGH**, not MAX, and re-locks it within
  seconds of creation. HIGH is enough for the full-screen intent. A future
  channel bump will land at HIGH again — that is device policy, not a bug.
- **The phone's build predates the follow-up cancellation fix**, so ask 2 still
  fires there even after a prayer is logged. Fixed in `0690711`, needs a new
  install.
- **Six bottom tabs**, one past Material's recommendation.
- **Untested on real hardware:** reboot survival, battery-kill, multi-day
  reliability. Emulator results say nothing about MagicOS.
- **`docs/athkar-verification.md` has not been checked by a human** against a
  printed حصن المسلم.
- Reports covers the religious pillar only.

## Decisions already made (do not relitigate)

- Prayer log states are append-only; reordering rewrites history. Same for
  `MealFeeling`.
- Alarms are scheduled in **UTC** — the plugin's zone round-trip disagreed with
  the device's tzdata and moved the adhan by an hour.
- Dates are **constructed, never offset**. `add(Duration(days: 1))` is 24 hours,
  which broke the pay cycle across Egypt's DST.
- `MainActivity` stays **behind the keyguard**. Showing it over the lock screen
  would expose the prayer log and المالية. See
  `docs/superpowers/specs/slice2-worked-example.md`.
- No calorie counting, and no naming a cause for a symptom.
- Nothing is ever marked failed, and nothing is ever red.

## Where things live

```
docs/setup.md          toolchain, timezone handling, adhan sound swap
docs/install.md        47 device checks, 40-47 are the adhan_v2 ones
docs/STATUS.md         this file
docs/superpowers/handoffs/    dated session handoffs
docs/superpowers/specs/       slice2-worked-example.md holds the open questions
tool/install_adhan_sound.sh   validates and installs an adhan recording
```
