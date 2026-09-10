# Nouri — status

Last updated **10 September 2026** — after Slice 1 was merged to `master`.

**Next session starts at** `docs/superpowers/handoffs/2026-09-10-the-night-the-alarms-stopped-vanishing.md` → *Start here
next time*.

| | |
|---|---|
| Branch | **merged into `master`** on 10 September. `slice1-religious-core` is kept, and both point at the same tree |
| Head | `master` at `b5dafa9`, pushed to origin, tree clean |
| Tests | **1217 passing**, `flutter analyze` clean |
| On the phone | **current build, installed 10 Sep 12:43** (HONOR VNE-N41). 273 alarms, no gap; policy access held; the adhan bypasses DND and has been heard |
| On the emulator | tonight's build, verified across reboot and Doze. Powered off |
| Schema | v13 |

**Slice 1 is merged.** It was held back from `master` from 5 September on one
condition — that it be tested and the merge approved — and both are now on the
record: the user approved it on 10 September, and `docs/install.md` carries 81
checks, of which everything reachable without a second person has been run on a
device. What is *not* merged is nothing; what is not *finished* is the network
call behind «ابني خطتي», and that waits on a decision rather than on work.

---

## Pillars

| Pillar | State |
|---|---|
| **الديني** religious | Built. Prayers, athkar, tasbeeh, wird, adhan + iqama alarms, follow-ups, daily review. Qur'anic athkar now set as a mushaf page. |
| **البدني** physical | Built. 16/8 window, meal log with symptom, weight, walking sessions, guided home workouts, sunnah fasting reminders, **water**. Now placed by the planner. |
| **المالي** financial | Built. Pay-cycle month, budgets, expenses, savings rate. |
| **تطوير الذات** self-development | **Tracking built.** Knowledge time logged on Home, in the report, and placed by the planner. The *recommending* — books, a skill path — is AI work for Slice 5. |
| **الوقت والدوام** time & duty | **Built, and now complete against §5.5.** The planner places the day from the shift and the prayer times; Home shows it. Calendar reminders too. مكالمات is an hour placed by shift; وقت الموبايل is a reserved slot with a cap that reports. |
| **المتابعة والذكاء** tracking & AI | Reports now cover **all three logged pillars** plus **challenges**. **الملف الشخصي and «ابني خطتي» are built**, along with the summary assembler and the reply parser; only the network call itself is missing, and it waits on one decision — see below. |

## What runs today

- ~270 exact alarms over a rolling 14-day window; follow-ups over 3 days,
  task alarms over 3. قيام adds one a night when it is on; the budget note
  adds at most two. Measured on the HONOR: **271**
- **Five adhans by famous reciters**, one per prayer — العفاسي (فجر, with the
  morning adhan), عبد الباسط عبد الصمد, ناصر القطامي, المدينة ١٩٥٢, العفاسي
  again for isha. 5.0 MB, down from 7.0. Marked **مؤقت** until the user sends
  his own five. Each on its own channel with a full-screen intent.
- **The adhan gets through Do Not Disturb — on the real phone.** All five
  `adhan_*_v3d` channels read `mBypassDnd=true` on the HONOR, and MagicOS's own
  zen config flipped `areChannelsBypassingDnd: false → true` when they were
  created. On the emulator with DND on, the same channels read
  `intercepted=false` while the soft follow-ups read `intercepted=true` in the
  same instant. It also **loops until dealt with** (`FLAG_INSISTENT`), capped
  at ten minutes — watched doing exactly that at isha on 9 September.
- **ساعات الوردية** — how long one shift runs, which decides how much of a day
  is left once duty is taken out. Chips for 8/12/16/24 and a free field, since
  the user's own shifts are seven and nine hours. The shift *type* stays in
  الإعدادات → الدوام; one setting, one place.
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
  `planDay` from the shift and the day's prayers. The whole day, stable: it
  does not change depending on when it is opened
- **Water** — a count against a target in البدن, and a nudge after each prayer
  that disappears between fajr and maghrib on a day marked as a fast
- **قيام الليل** — in the last third of the night, computed from tonight's isha
  and tomorrow's fajr rather than a clock hour. **Off by default**, and silent
  on a night shift, when the whole last third is duty time
- **وقت الموبايل** — a reserved evening slot the length of the cap, a card on
  Home, and a stated number when the cap is passed. The time is the user's
  word; Nouri does not read device usage
- **مكالمات** — the hour §5.5 asks for, placed after work on a morning shift
  and in the evening on the others
- **A gentle budget note** — one line, one evening, when a category is running
  ahead of the month. Never صدقة, and never a category with no budget set
- **حالة التنبيهات says whether the alarms are actually there**, not only
  whether Nouri is allowed to set them. A fifth row reads the device back —
  «٢٧٣ — لحد ٢٣ سبتمبر» — and names any upcoming day with nothing armed, with
  a «صلّح» that rebuilds the window. It exists because on 10 September the user
  carried four silent days behind four green ticks.
- **الإعدادات is a menu** — eight sections, each its own page
- **الأصوات** — every adhan and every task tone with a «شغّل» beside it, so a
  sound can be heard before the moment it fires rather than only at it. Posted
  on the real channel, so it is the real file at the real volume
- **The planned day announces itself** — one alarm per task at the time
  `planDay` gave it, over a **three-day** rolling window re-armed on every
  launch. Tapping one opens the screen where that task is done.
- **Nouri stops ringing about what it can already see you did** — completions
  derived from the logs you already keep, never stored twice, and the write
  sites cancel their own question so it does not wait for a relaunch.
  **Measured on a device:** logging العشاء removed exactly its two follow-ups
  (19:53, 20:53) and nothing else; logging a meal removed its alert and its
  «عملتها؟» (19:36, 20:06 — the documented thirty minutes apart)
- **A switch for the task alarms** in الإشعارات, on by default; it never
  touches the adhan
- **A sound per task that sounds like the task** — nineteen channels, nineteen
  tones, none shared. Generated by `tool/make_alert_sounds.py`, not downloaded:
  no licence to honour and 1.1 MB for all of them. Water *runs*, walking is
  four footsteps with a scuff, مكالمات is a landline's rasp, تمارين a whistle,
  وجبة a spoon on a glass, الميزانية coins, الإقامة two firm knocks against
  تسبيح's three light beads. Distinctness is **measured** by
  `alert_sound_character_test`, which reads the PCM.
- **الملف الشخصي** — who Nouri is planning for, with every field stating what
  it changes, fields the user adds himself, and «ابني خطتي». Nothing on it is
  a score, and it works empty. **A photo now picks**, through the system photo
  picker with no permission asked, stored beside the database; its own line
  says it changes nothing and goes nowhere, because that is true.
- **Opening Nouri and closing it no longer costs you the fortnight.** A re-arm
  cancels only what the new window does not contain and writes the rest over
  the top — rewriting an id is already a cancel. Measured by opening the app
  and swiping it away, which is what people do:

  | swiped away after | old | new |
  |---|---|---|
  | 3 seconds | 285 → **8 alarms** | 285 → **285** |
  | 6 seconds | 285 → **212 alarms** | 285 → **285** |

  This is a **robustness** change, not a speed one — `armWindow` is 24.4s
  before and 24.3s after, because the ~287 schedules are the cost and this does
  not touch them.
- **Every one of the nineteen is reachable, and nothing rings twice.** The
  iqama, قيام, the water nudge, the budget note, the fasting offer, the daily
  review and the user's own reminders each moved off the shared channel onto
  the tone that was made for them; the athkar and the wird no longer get a
  second ring from the Slice-1 path. Held by `one_sound_per_thing_test`.
- **«فكّرني بعد ٥ دقايق»** on every task alert — works with the app closed,
  repeats, and each press is measured from now so they accumulate
- **«عملتها؟»** after the tasks worth asking about — the meal thirty minutes
  later, in the user's own words
- **Knowledge time** — reading, skill or religious content, logged on Home and
  totalled in the weekly report as minutes *and* days
- **Onboarding asks which shift**, so the first day Nouri shows is the right
  shape rather than a morning guess
- Counters read «٠ من ٣», never «٠ / ٣» — the slash form reverses in RTL and
  said *three of zero*. Fixed app-wide and held by a guard test.
- Finance and body tabs, both writing to the local database
- No network calls at all — `INTERNET` is removed from the manifest

## Known limits, stated plainly

- **MagicOS caps the adhan channels at HIGH**, not MAX, and re-locks it within
  seconds of creation. HIGH is enough for the full-screen intent. A future
  channel bump will land at HIGH again — that is device policy, not a bug.
- **Nobody has heard any of the five adhans.** For fajr the evidence is as far
  as it can be taken without ears: it is the only file in its source collection
  labelled the *morning* adhan, and it runs 263s against 157s for the **same
  reciter's** ordinary adhan — consistent with «الصلاة خير من النوم», not proof
  of it. **الإعدادات → الأصوات settles it in one minute** and carries a «مؤقت»
  badge asking exactly that.
- **The recitations' licences cannot be individually verified.** The Wikimedia
  set could be; these cannot. The user asked for famous reciters, was told the
  trade-off, and accepted it for personal use on his own phone. Nothing is
  distributed. If Nouri ever goes in front of anyone else, this is the first
  thing to revisit.
- **«ابني خطتي» cannot call anything yet.** `INTERNET` is still absent from the
  manifest by deliberate choice, and the AI layer needs it back. The plan is to
  narrow `no_network_test` rather than delete it — one file may open a socket,
  and only to `api.anthropic.com`. That reverses a decision made on purpose, so
  it waits for the user's yes.
- **المهام is confirmed on the phone**, with real data: five states drawn,
  «أول وجبة» carrying the gold edge as the thing due now, nothing red. 259
  alarms armed — exactly twelve fewer than before the duplicate fix, which is
  four tasks over the three-day window and nothing else.
- **The whole notification chain is confirmed working on the emulator** —
  first time in this project. A task alert fires on its own channel, its
  snooze button puts it off five minutes without opening the app, and المهام
  shows the new time. The maghrib adhan and a «مشيت؟» follow-up were seen in
  the same run.
- **Check POST_NOTIFICATIONS before concluding anything about alarms.** It is
  a runtime permission on SDK 33+, it was never granted on the emulator, and
  every alarm this project armed there fired into nothing for weeks. That is
  the whole explanation for "no notification has ever been watched arriving".
- **`flutter_local_notifications` declares no receivers of its own.** All three
  are the app's to declare, and a *silent* notification action needs the third
  one — `ActionBroadcastReceiver` — or the button does nothing at all, with no
  log and no error.
- **With DND on, the adhan is heard but does not take over the screen.** The
  consolidated zen policy carries `SUPPRESSED_EFFECT_FULL_SCREEN_INTENT`, so
  the sound passes and the full-screen intent is suppressed. Android's rule,
  not a Nouri setting.
- **Holding `ACCESS_NOTIFICATION_POLICY` is not the same as having policy
  access.** The manifest permission reads `granted=true` at install while
  `enabled_notification_policy_access_packages` stays null until the user
  grants it on a system screen. Nouri reads the second, not the first, and
  builds the non-bypassing channels until it is real.
- **The step counter needs hardware *and a permission*.** The HONOR has the
  hardware — an HONOR `pedometer` on `android.sensor.step_counter(19)` — and
  Nouri held `ACTIVITY_RECOGNITION: granted=false`, having never asked. That
  is fixed: the walk screen distinguishes "no sensor" from "not allowed yet"
  and offers «اسمح لنوري». **Nobody has yet granted it and watched a real step
  arrive**, which is the last thing needing a person holding the phone.
- **A walk is only counted while its screen is open.** Android keeps counting
  in the OS, so a backgrounded session reconciles correctly on resume, but
  there is no foreground service and a killed app loses the session.
- **The shift is a single setting, not a rota.** The brief describes a rotating
  pattern; guessing at one would put wrong times in front of the user daily.
  Set today's shift in الإعدادات → الدوام.
- **المهام is the day's list** — every task, its time, and one of five states:
  تمّت · دلوقتي · جاية · مأجّلة · لسه. It stores nothing; every status is
  derived, and there is no checkbox, because that would be a second place for
  the truth to live.
- **Seven bottom tabs, two past Material's recommendation**, and the labels are
  cramped. الأذكار is the candidate to fold into النهاردة next. Everything
  else stays where it is: the calendar opens from the Home header, walking and
  workouts sit inside البدن, challenges inside التقارير, the planned day
  inside Home.
- **The planned day is read-only, but no longer blind.** Blocks expand to show
  their hours, and a task the logs show as done carries a tick — derived, not
  stored. Nothing is *tapped* done from there: whether the plan should also be
  a place to log is still an open question about where the truth lives.
- **Verified on the HONOR on 8 September:** no orphaned alarms across the
  stride change (232 old-stride alarms → 249, not ~470), a window spanning
  exactly 14 days, exact alarms permitted, Nouri whitelisted from battery
  optimisation, and the MagicOS importance cap measured (`adhan_v2` at
  `mImportance=4`, `mOriginalImp=5`, importance field locked).
- **Reboot survival, Doze and the day turning over are now measured — on the
  emulator, not on the phone.** 289 alarms went into a reboot and 289 came
  out, every `origWhen` identical and every one still exact, with the app never
  opened; one of the restored alarms then fired (`adhan_dhuhr_v3d`, insistent,
  alarm importance, app still never opened). The iqama arrived in **deep Doze**
  with Nouri *not* on the deviceidle whitelist. A day rolled over cleanly — the
  window re-anchored to the new date with nothing orphaned. **None of it has
  been repeated on the HONOR**, where MagicOS's own power management is the
  variable an emulator cannot speak for.
- **Still untested anywhere:** battery-kill across several real days.
- **Nouri can now notice this itself.** The armed window is read back from the
  device in حالة التنبيهات and any upcoming empty day is named. **Reach is the
  wrong measure** — his window still ran to the 23rd; the hole was at the near
  end, which is where an interrupted cancel pass leaves one. So the question
  asked is "is there a day between here and there with nothing in it".
- **It had already happened, on the real phone.** On 10 September, before the
  new build went on, the HONOR held **137 alarms with a four-day hole** — none
  at all from that moment until 14 September, and a *partially* cancelled day
  on the 14th, which only an interrupted per-alarm pass can produce. No crash
  was recorded, the app was not force-stopped, it sits at standby bucket 5
  (EXEMPTED) and is on the Doze whitelist. The process was simply killed
  mid-re-arm. This is the one piece of evidence in the project that says an
  alarm bug reached the user rather than the test suite.
  **How long the hole lasts is not known.** `dumpsys alarm` contends for the
  lock the cancel loop needs, so sampling it hard stretches the decline: it
  spanned ~14s of a 32s `armWindow` under heavy sampling and the same pass runs
  in 24s unobserved. Depth is measured; duration is not, and no number for it
  should be quoted.
- **`armWindow` is ~24s on a warm emulator in debug, and the re-arm fix did not
  change that** (24.4s → 24.3s). The 42s figure from 8 September was a
  *cold-booted* emulator and has not been reproduced warm. Whatever costs those
  seconds is the ~287 `zonedSchedule` round-trips, which nothing has yet
  addressed. It runs off the critical path, so it costs no blank screen.
- **Prayer times come from the stored Kuwait coordinates, not the device.**
  `ACCESS_COARSE_LOCATION: granted=false` on the phone. By design — Nouri is
  never blocked on a permission — but they are not from GPS.
- **وقت الموبايل is reported, not measured.** Nouri does not read device usage
  and asks for no usage permission. The reasoning is decision 7 in
  `docs/planner-decisions.md`; the card takes sittings rather than running a
  live timer, which is the smaller half of the same choice.
- **The budget note is armed over two days, from the numbers at re-arm time.**
  Budget state is not knowable a fortnight ahead. If Nouri goes unopened the
  note reflects the last state it saw, which is honest but not current.
- **قيام الليل has now been watched firing**, on the emulator at 01:32:40:
  `id=156447 channel=alert_qiyam_v2 importance=4 flags=AUTO_CANCEL
  category=reminder`, no full-screen intent, reading «قيام الليل — الثلث الأخير
  — لو قدرت». The isha adhan that fired in the same run read
  `importance=5 flags=INSISTENT|AUTO_CANCEL|HIGH_PRIORITY category=alarm`.
  **An invitation and a summons, and the device treats them differently** —
  which was the design and is no longer only an assertion. Still off by
  default.
- **`docs/athkar-verification.md` has not been checked by a human** against a
  printed حصن المسلم. The mushaf rendering did not change a letter of it —
  enforced by a test — so that review is still valid and still outstanding.
- **The sunnah fasting days have not been reviewed by a person.**
  `docs/fasting-verification.md` lists what is and is not covered and asks for
  that review. عرفة, عاشوراء and الست من شوال are deliberately absent — the
  brief does not name them and choosing which to add is a religious judgement.

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
| `notification_slot_test` | Slots outgrowing the stride; and it now also states *why* widening the stride orphans nothing |
| `schema_test` | An accidental schema bump — a migration nobody wrote |
| `scheduling_config_source_test` | A second place building the alarm config, which is how قيام and the budget note were silently dropped on every launch |
| `background_action_test` | A notification action that does not open the app, with no background handler registered — the trap «صليت» already fell into |
| `task_alert_test` | Two tasks sharing a sound, and the append-only order alarm ids depend on |
| `alert_sound_character_test` | Two tones that *measure* alike — it reads the PCM, not the filename. It caught قيام opening like a struck bell at 01:30 |
| `plan_request_test` | A logged meal, expense, weight or prayer state reaching the payload sent to Claude |
| `schema_test` (v13) | The shift *length* being confused with the shift *type*, which lives in settings |

## Decisions already made (do not relitigate)

- Prayer log states are append-only; reordering rewrites history. Same for
  `MealFeeling`, `ReminderRepeat` and `KnowledgeKind`.
- **Anything day-scoped watches `currentDayProvider`**, never `DateTime.now()`
  directly. Five more reads were found still frozen at launch on 8 September —
  the weekly report, البدن والمالية, the challenge window, the financial month
  and the paced budget allowance — so check this when adding a provider. It changes once a day, so the app turns over at midnight instead
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
- **Android reads a notification's sound off its channel**, so a sound per task
  means a channel per task. A channel's sound is frozen at creation, so
  changing a tone means bumping it to `_v2` — never editing in place.
- **Five adhan recitations, one per prayer**, each on its own channel with its
  own version so one can be replaced without resetting the others. All five are
  freely licensed from Wikimedia Commons — CC0, CC BY and CC BY-SA — chosen
  because their licences can actually be stated. The user accepted the
  copyright risk of a famous recording in writing; taking a verifiable licence
  instead means that risk did not have to be spent.
- **Attribution in عن نوري is a condition of use, not a courtesy.** Four of the
  five are CC BY or CC BY-SA. A test asserts every bundled recording has a
  credit.
- **Alarm ids are keyed on the task, never on the alert kind.** Several tasks
  share a kind — both meals, all three knowledge faces — and keying on the kind
  gave them the same id, so the later silently overwrote the earlier.
- **Rewriting an alarm id is already a cancel**, so a re-arm cancels only the
  ids the new window does not contain. `AlarmManager.setExactAndAllowWhileIdle`
  cancels whatever is held under an equal PendingIntent before setting the new
  one, and the plugin keys that PendingIntent on the notification id with
  `FLAG_UPDATE_CURRENT` — read in the plugin's source, not assumed. The cancel
  pass still enumerates what is *pending* rather than recomputing ids, which is
  what keeps widening `kSlotsPerDay` safe.
- **The startup path asks `readMode`, not `readStatus`.** The full read answers
  four questions across four platform round-trips and three of them exist for
  the settings panel. Only the exact-alarm answer changes what gets scheduled.
- **A test fake must not be kinder than the platform.** The fake gateway
  appended on `schedule` where Android replaces by id; left that way, the
  re-arm change would have looked correct in tests and been wrong on the phone.
- **The profile photo asks for no permission.** The system photo picker returns
  the one chosen image and nothing else. `READ_MEDIA_IMAGES` would buy nothing,
  and it is not a trade worth offering the user for a thumbnail. The photo is
  also the one field on that screen whose stated effect is *nothing* — it is
  not in `PlanRequest` and a test asserts it never reaches the payload.
- **One place builds the alarm window's config**, `schedulingConfigFromDb`.
  There were two and they drifted, which cost قيام and the budget note on
  every launch. A guard fails the build on a second one.
- **Any setting that can change an alarm must re-arm.** The shift now can,
  because قيام depends on it.
- **The notification slot space was widened on 8 September** — `kSlotsPerDay`
  32 → 64, with 33 slots used. It is safe for one specific reason, written on
  the constant: `cancelAllBelow` enumerates what is *pending* rather than
  recomputing IDs, so the first re-arm after the upgrade finds and clears the
  old-stride alarms. A test states that property directly.
- **Nouri recommends nothing.** No book, no skill path, no reading of the
  week. All of it is AI work for Slice 5, and every screen asks rather than
  claims — tests assert it makes no such claim.
- **A channel's DND bypass is frozen at creation, like its sound**, and is
  ignored outright without notification-policy access. So a bypassing adhan is
  a *different channel id* — `adhan_fajr_v3d` — and only one variant exists at
  a time. Granting the access re-arms the window, because the armed alarms
  point at the other one.
- **Do Not Disturb is not a delivery warning.** It does not delay or drop
  anything; the notification arrives punctually and silently. It has its own
  row in the panel rather than joining `warnings`, which is about lateness —
  otherwise every user with DND off would see a permanent warning about
  nothing.
- **A display filter is never a persistence rule.** `read()` hiding a stale
  snooze must not mean `record()` deletes it. That conflation lost a snooze
  every time a second task was put off.
- **The AI plan feeds the existing pipeline**, arriving as the same
  `PlannedTask` values `planDay` already emits. A second parallel plan with its
  own screen and its own alarms is how قيام and the budget note were lost —
  two sources for one truth, drifting.
- **Drop, never invent.** A task id in a model's reply that Nouri cannot ring
  is discarded however plausible: a task with no alert never fires, and a
  silent row in المهام reads as a promise that was not kept.
- **A value the user can set, the user can unset.** Text empties, a chosen
  chip deselects, and a date now clears — a picker has no "none", so before the
  × existed a date set by accident was permanent. That is not hypothetical: a
  stray swipe wrote 2001/1/1 into the real profile on 9 September.
- **Confirming focus is necessary and not sufficient.** The rule was followed —
  `mCurrentFocus` was Nouri before every tap — and a swipe still landed on a
  field and opened a picker. Read the screen *between* gestures, not only
  before the first.
- **Nothing about the profile is a score.** No percentage, no bar, no «٣ من ٨».
  A completion meter over a form about the user's own life is self-blame
  wearing a progress bar.
- **`.claude/` is not tracked and never should be.** A lock file inside it was
  committed early on and went unnoticed until the directory acquired ACLs this
  account cannot read — at which point every checkout that had to write it
  failed, including the merge to `master`. It is in `.gitignore` now. Nothing
  on disk was changed to fix it: the removal was made with git plumbing,
  because checking the branch out to fix it normally was the very thing the
  tracked file prevented.
- Nothing is ever marked failed, and nothing is ever red.

## Where things live

```
docs/setup.md          toolchain, timezone handling, adhan sound swap
docs/install.md        device checks; 40-47 are the adhan_v2 ones, 48-56 Slice
                       1b, 57-65 the reboot/Doze/re-arm run of 10 September,
                       66-71 the HONOR install, 72-81 the day's on-device pass
docs/STATUS.md         this file
docs/superpowers/handoffs/    dated session handoffs; the 10 September one
                              ends with the merge and how it was unblocked
docs/planner-decisions.md     the six Slice 2 answers, and why each is reversible
docs/fasting-verification.md  the sunnah fasting days, awaiting a human read
docs/superpowers/plans/       2026-09-08-slice5-the-day-speaks.md is the
                              alarm work; slice4 the night before
docs/superpowers/specs/       slice2-worked-example.md holds the open questions
tool/install_adhan_sound.sh   validates and installs an adhan recording
tool/make_alert_sounds.py     the nineteen tones; each builder says what it
                              should sound like
docs/superpowers/specs/2026-09-09-profile-and-the-built-plan-design.md
                              الملف الشخصي → «ابني خطتي» → tasks, and the
                              INTERNET decision that is still open
```
