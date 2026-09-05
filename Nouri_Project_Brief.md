# Nouri / نوري — Project Brief for Claude Code

> A personal life-companion Android app that takes the user's work schedule and
> fixed anchors (prayers, sleep, meals) and returns a ready-made daily plan —
> reminding, tracking, scoring, and reflecting across every area of life.
> The app's whole reason to exist: the user feels lost and that his day slips
> away. Nouri removes that by making the decisions for him and following up.

---

## 1. Product philosophy (read this first — it governs every design choice)

1. **Reduce load, never add it.** The home screen shows only what's next, not a
   long intimidating checklist. A cluttered dashboard would recreate the exact
   stress the app exists to remove.
2. **No self-blame.** Missed a prayer or a walk? Nouri never greets the user with
   red failure marks. It encourages continuation, it does not punish. This is the
   single biggest reason people abandon habit apps — do not violate it.
3. **Nouri is a guide, not a logging tool.** The user gives Nouri his shift
   schedule + fixed anchors; Nouri returns a daily plan to follow. The user's own
   words: *"I'll follow the app's instructions — it tells me when to sleep, when
   to eat, when to walk, when to read, based on what fits my shifts."*
4. **Neutral, direct voice.** Nouri speaks plainly. It states the fact and the
   guidance. Not overly cheerful, not a harsh coach. A calm, sensible companion.
5. **Health boundary.** Nouri is NOT a medical tool. The user has post-meal pain,
   bloating and gas (suspects inflammation). The app helps him regularize meals,
   run intermittent fasting, and LOG how he felt after each meal to surface
   patterns — but it must clearly state it is not a substitute for a doctor and
   should encourage a real medical check-up. Never diagnose or prescribe.

---

## 2. Core concept — the scheduling engine (the heart of the app)

This is the most important feature. Everything else is inputs and outputs around it.

**Input:** The user submits his duty schedule for the next 14 days (later up to a
month). Each day is one of a few shift types with known times (below), plus
day-offs.

**The engine then:**
- Marks **locked/fixed time**: work shift, commute, prayer times (auto by
  location), and *sufficient sleep*.
- Identifies **flexible time**: the gaps between fixed blocks.
- Distributes into flexible time: meals, exercise/walking, reading, learning,
  evening/morning athkar, Quran wird, calls, phone time.
- Classifies tasks as **heavy** (need focus/place: workout, book reading) →
  placed at home / real free time; or **light** (doable while moving: athkar,
  listening to a lecture, wird) → placed during commute or a break at work.
- Inserts **short, intentional breaks** between big blocks, length depending on
  the effort of the finished task (heavy task → longer break; light → short/none).
- **Prioritizes sufficient sleep** so the user can handle his shift; if a day is
  overloaded, Nouri defers lighter tasks rather than cutting sleep.
- If a day goes wrong (task missed / user tired), the engine **re-plans the rest
  of the day** automatically (this is an AI-assisted action — see §7).

### The user's shift schedule (real data — build the engine around this)

| Shift | Wake | Bus departs | Work hours | Home again |
|-------|------|-------------|-----------|-----------|
| Morning (صباحي) | 05:00 | 06:00 | 07:00–14:00 | 15:00–15:30 |
| Evening (مسائي) | 12:00 | 13:00 | 14:00–21:00 | 22:00 |
| Night (سهر/ليلي) | ~2h before | — | 22:00–07:00 | 08:00 |

- Works **6 days/week, 1 day off (not fixed)**.
- Per month: **5 night shifts** in a row, followed by **2 rest days**.
- **Night-shift day handling:** returns home 08:00; may do a light task until
  09:00–10:00, then sleeps enough to wake comfortably for the next duty. Sleep is
  the priority; Nouri computes wake time backwards from the next shift.
- **Commute is usable time** — light tasks can be scheduled there.
- Day is presented as **big blocks** (Morning / Work / After-work / Evening), each
  expandable to show its hour-by-hour detail. Big blocks by default because the
  user's core problem is feeling overwhelmed; hourly view only on tap.

---

## 3. Tech stack

- **Framework:** Flutter (Dart). Single codebase, Android first, iOS possible
  later from the same code. Chosen for speed of delivery and strong library
  support.
- **Local storage:** all user data lives **on-device** (SQLite via `drift` or
  `sqflite`, or `isar`). Nothing is sent to any server except AI summaries.
- **Notifications:** `flutter_local_notifications` + `android_alarm_manager_plus`
  for exact-time prayer/adhan and task reminders. Handle Android 13+ notification
  permission and exact-alarm permission.
- **Prayer times:** compute locally from location using the `adhan` (adhan-dart)
  package. Kuwait as default region. Include adhan sound at prayer time + a second
  notification at iqama.
- **AI:** Anthropic Claude API (see §7). Online only when AI runs.
- **Localization:** Arabic + English from the start (`flutter_localizations`,
  `intl`). Full RTL support. Arabic is primary.

---

## 4. Visual identity / design system

Locked with the user. Calm, spiritual, uncluttered.

- **Palette:**
  - Background deep navy/petrol: `#0E2A3B`
  - Card surface: `#16384C`
  - Active/highlighted card: `#1B4763` with border `#2C6486`
  - **Gold accent (the "light"):** `#D9A73E`
  - Primary text: `#EAF2F5`
  - Muted text: `#8FB3C4`
  - Success/good: `#5DCAA5`
  - Needs-attention (never harsh red): `#E8955A`
- **Feel:** flat, generous whitespace, rounded cards (14–16px radius), a
  comfortable Arabic font, no gradients or heavy shadows.
- **Score is visual by default** (rings, filling circles/bars — easy on the mind),
  and becomes **numeric only inside reports** (every 2 weeks / monthly) for
  precise comparison.
- **Nouri identity** is present throughout: a small gold "نوري" avatar in the
  header, in reminders, and in reports (Nouri "speaks" to the user).
- **Bottom nav (5):** Home (النهاردة) · Athkar & Tasbeeh · Reports · Finance ·
  Settings.

Three reference screens have already been approved by the user (Home, Athkar &
Tasbeeh, Report). Rebuild them faithfully in Flutter:

- **Home / النهاردة:** header (Hijri date + time-of-day greeting + Nouri avatar);
  a daily-progress ring with a short Nouri line ("خلّصت ٥ من ٨…"); a prominent
  "next prayer" card with countdown + iqama time; then the 4 big day-blocks
  (completed ones subtly dimmed with a soft green check, the current one
  highlighted gold), each expandable.
- **Athkar & Tasbeeh:** tabs (Tasbeeh / Morning / Evening / Sleep); current
  dhikr in Arabic; a **circular interactive tasbeeh** — gold beads fill with each
  count, big counter in the centre (e.g. ٣٣ من ١٠٠), progress bar, a big "سبّح"
  button and a reset button. Tapping the bead ring or the button increments.
  Default target 100, adjustable upward.
- **Report:** two top cards (overall score, change vs previous period); per-pillar
  score bars (gold = excellent, green = good, orange = needs work); a "Nouri's
  guidance" card that praises what's stable, names the weakest point, ties it to
  its consequences, and gives the next step.

---

## 5. The six pillars (full spec)

### 5.1 Religious (الديني)

**Prayer (core):**
- Auto prayer times by location (Kuwait default).
- Adhan notification at each prayer's entry + a second notification at iqama.
- User logs each prayer with a state, each state carries a **score**:
  - Congregation in mosque → highest
  - Congregation (e.g. at work) → slightly lower
  - Alone, on time → medium
  - Late / qada → lowest
- Goal: hit the highest score each day (positive challenge, not guilt).

**Athkar (fully inside Nouri):**
- Morning athkar, Evening athkar, Before-sleep athkar (ties to sleep time from the
  physical pillar), and a daily **tasbeeh wird** (min 100, adjustable) with the
  interactive circular tasbeeh.

**Quran:**
- Daily wird = a rubʿ (~3 pages). **Nouri does NOT contain a mushaf.** It sends a
  reminder to read the wird from the user's own mushaf/app, the user marks it
  done, and Nouri tracks progress toward a full khatma.

**Qiyam al-layl:** a reminder, timed around the user's sleep schedule.

**Daily religious content:** Nouri recommends one video/story per day, counted as
part of the flexible "knowledge time" (see 5.3).

**Fasting** is specced in the physical pillar; **charity** in the financial pillar.

**Scoring:** all religious actions roll up into a daily religious score, visual
day-to-day, numeric in reports.

### 5.2 Physical (البدني)

Goal: lose weight (from **87 kg → target 74 kg**) but **calming the stomach is
more important than the number** (post-meal pain/bloating/gas).

**Eating:**
- Fix regular meal times (his current habits are irregular — this is the main fix).
- **16/8 intermittent fasting** as the base system to rest the stomach and aid
  weight.
- After each meal, a quick log: "How did you feel?" (good / bloating / pain /
  gas) — to surface which foods/timings hurt him, useful for him and his doctor.
- Do **not** demand calorie counting; meal logging is enough at first.
- Include the medical-boundary note (§1.5).

**Sleep:** tied to the shift schedule (not a fixed time). Nouri computes correct
sleep/wake windows per shift and reminds accordingly; links to before-sleep athkar.

**Exercise/Walking:** Nouri places it in the free time after subtracting work +
commute. Daily by default, or as the plan best allows.

**Fasting:**
- Islamic: reminders for Mondays & Thursdays, the white days (Ayyam al-Beed),
  and other occasions.
- Diet: 16/8 intermittent, until reaching the target / stomach relief.

### 5.3 Self-development (تطوير الذات) — "knowledge time"

Treated as one flexible **"knowledge time"** block holding three things — Nouri
balances between them by day and mood (one day "read", another "learn", another
"listen to the lecture"), so the day isn't split into three separate items.

- **Reading:** minimum 10 min/day, paper or PDF. **Nouri recommends useful
  books** across ALL fields, varying the genre each time (self-dev, religious,
  history, psychology, business, tech, health...) — goal: broad general culture.
- **Skill learning:** no fixed skill yet. **Nouri proposes skills and builds a
  learning path.** The user already builds apps with Claude Code / works with AI,
  so Nouri can build on that.
- **Daily religious content:** part of this knowledge time.

### 5.4 Financial (الاقتصادي)

All financial data stays **on-device**; AI only receives aggregated numbers.

- **Income:** monthly salary; paid between the **20th and 25th** — Nouri's
  "financial month" starts then, not on the 1st.
- **Budgets (fixed monthly categories):** rent, food & drink, family support,
  transport, internet, variable personal (clothes, perfume, etc.), and **charity**
  (a fixed amount inside the monthly budget).
- **Daily expense logging:** "spent X on Y"; Nouri deducts from that category and,
  in the report, flags each category as "fine / over budget".
- **Savings:** = what remains after all budgets and expenses. Nouri computes the
  **actual savings rate** and compares it to a target. As an expatriate whose goal
  is to save, suggest a target of **30–40%** — but derive the real, achievable
  number from his actual logged budgets and advise adjustments to raise it.
  (Include a "not a financial advisor — general framework only" note.)
- **Gentle budget alerts:** when a category nears its limit, notify softly (not an
  alarm) so month-end isn't a surprise.

### 5.5 Time & duty (الوقت والدوام)

Mostly realized by the scheduling engine (§2). Additional specifics:

- Day shown as **big blocks**, each expandable to hourly detail.
- **Phone/social time:** Nouri reserves a **fixed slot** and notifies if exceeded
  (the user wants a hard-ish cap here).
- **Calls time:** **one hour**, placed by shift — after morning/evening shift or
  before sleep; for the night shift, before duty or during it if there's a chance.
- **Short breaks:** length depends on the effort of the finished task (Nouri
  computes it, not a fixed number).

### 5.6 Tracking & intelligence (المتابعة والذكاء)

- **Per-task follow-up:** after each task/prayer, a timely notification (e.g. after
  dhuhr adhan: "صليت؟"). Marking it done at the right time logs it at the highest
  score.
- **End-of-day:** a single "review your day" notification — user reviews completed
  tasks, marks anything he forgot, and Nouri asks one short question (sleep /
  stomach).
- **AI roles** (§7): builds the plan; re-plans a disrupted day; produces periodic
  reports.
- **Report content:** numbers + guidance together. Neutral, direct Nouri voice.
- **Report cadence:** every 2 weeks and monthly.

---

## 6. Data model (starting point — refine in code)

Local SQLite tables (suggested):

- `settings` — language, location, API key (encrypted), notification prefs,
  targets (weight, savings %), tasbeeh target, financial-month start day.
- `shifts` — date, shift_type (morning/evening/night/off), computed wake/commute/
  work/home times.
- `plan_days` — date, generated blocks (JSON), status.
- `tasks` — date, pillar, title, type (heavy/light), scheduled_start, duration,
  status, completed_at, score.
- `prayers` — date, prayer_name, state (mosque/congregation/alone-ontime/late),
  score.
- `athkar_logs` — date, type (morning/evening/sleep/tasbeeh), count/completed.
- `quran_log` — date, pages_read, khatma_progress.
- `meals` — datetime, description, feeling (good/bloating/pain/gas).
- `fasting_log` — date, type (islamic/diet-16-8), window, completed.
- `expenses` — datetime, category, amount, note.
- `budgets` — month, category, limit.
- `reports` — period, per-pillar scores, overall, delta, ai_text.

**Secure the API key** with `flutter_secure_storage`. Never log it, never send it
anywhere but api.anthropic.com.

---

## 7. AI integration (Claude API)

- **Setup:** Settings screen has a field for the user's own Claude API key
  (obtained from the Anthropic console). Stored encrypted on-device. All calls go
  directly to `https://api.anthropic.com/v1/messages`.
- **Cost discipline (important):** the user pays per call, so:
  - Use a **cheap model (e.g. Claude Haiku)** for routine work (daily re-plan,
    small nudges).
  - Use a **stronger model** only for the deep periodic reports.
  - **Batch** data and call at deliberate moments (plan build every ~2 weeks,
    monthly report, occasional re-plan) — never per tap.
  - Only send **aggregated summaries**, never raw sensitive detail.
- **Three AI moments:**
  1. **Plan build** — user submits 14-day duty schedule → AI returns the daily
     plans respecting all fixed anchors, task weights, and sleep priority.
  2. **Daily re-plan** — a disrupted day → AI reshuffles the remainder.
  3. **Periodic report** — AI reads aggregated data and writes numbers + guidance
     in Nouri's neutral, direct voice.
- Prompt the API to **return structured JSON** for plans (so the app maps it to UI
  reliably) and prose for report guidance. Parse defensively (strip code fences,
  try/catch).

### 7.1 How the app actually talks to the AI (the request/response flow)

There is **no intermediary server**. The app on the phone talks **directly** to
the Anthropic API over HTTPS. Think of it as a phone call the app makes on the
user's behalf: the app writes the message, sends it, and reads the reply — all
in-app. The user never leaves Nouri; the reply appears inside the relevant screen
(e.g. the Report screen), never via email/WhatsApp/any external channel.

**The flow, step by step:**

1. **Assemble (on-device).** When it's time (e.g. the 2-week report), Nouri
   gathers the user's local data and builds a compact **summary** — never the raw
   rows. Example of what gets sent:

   ```
   Data (period: 8–22 Safar):
   - Prayers: 65% on time, 20% late, 15% congregation
   - Sleep: avg 5h, late on evening shifts
   - Eating: 4/14 days kept 16/8
   - Walking: 3/14 days
   - Savings rate: 28%
   Task: analyze and produce a report — numbers + guidance, neutral direct voice, in Arabic.
   ```

2. **Send (needs internet — the only online moment).** Nouri POSTs this to
   `https://api.anthropic.com/v1/messages` with the user's **API key** in the
   `x-api-key` header (the key = the user's "entry card"; billing goes to his
   Anthropic account). Request shape:

   ```
   POST https://api.anthropic.com/v1/messages
   headers:
     x-api-key: <user's key from secure storage>
     anthropic-version: 2023-06-01
     content-type: application/json
   body:
     {
       "model": "claude-haiku-...",        // cheap model for routine; stronger only for deep reports
       "max_tokens": 1024,
       "system": "<Nouri's role + voice instructions>",
       "messages": [ { "role": "user", "content": "<the summary above>" } ]
     }
   ```

3. **AI thinks and replies.** Claude reads the summary and returns text in
   `response.content[].text`. For **plans** the reply is **JSON** (so the app maps
   it straight to blocks/tasks); for **reports** the reply is **prose** (for
   reading). Parse defensively: strip ``` fences, `try/catch`, and fall back
   gracefully if the network or parse fails (show a "couldn't update now, retry"
   state — never crash, never lose local data).

4. **Deliver (back on-device).** Nouri saves the reply locally (e.g. into the
   `reports` table, or converts the plan JSON into `tasks`/`plan_days`) and shows
   it in the UI. The user simply opens the Report/Home screen and finds it ready.

**Same mechanism for all three AI moments** — only the content differs:
plan-build sends the 14-day schedule → gets JSON plan back; re-plan sends what
went wrong today → gets a revised remainder; report sends the aggregated summary →
gets prose guidance.

**Hard rules Claude Code must follow here (privacy + cost):**
- API key stored **encrypted** (`flutter_secure_storage`); never logged, never
  sent anywhere except `api.anthropic.com`.
- Send **aggregated summaries only** — never raw meals/expenses/personal detail.
- Call **only at deliberate moments** (plan every ~2 weeks, monthly report,
  occasional re-plan) — **never per tap / per task**.
- Route models by cost: **Haiku** for routine, stronger model **only** for deep
  reports. Keep `max_tokens` modest.
- All AI features must **degrade gracefully offline**: the deterministic scheduler
  and all logging/tracking keep working with no internet; AI is an enhancement,
  not a dependency.

---

## 8. Implementation phases (build in this order — deliver a working app early)

The user's goal: get Nouri built, installed on his phone, and tested. Ship a
usable core first, layer intelligence after.

**Phase 0 — Foundation**
- Flutter project, Android target, AR/EN localization + RTL, navy/gold theme,
  bottom nav shell (5 tabs), local DB, secure storage.

**Phase 1 — Religious core (highest daily value)**
- Prayer times by location + adhan/iqama notifications.
- Prayer logging with scored states + visual daily score.
- Athkar screens + interactive circular tasbeeh.
- Quran wird reminder + khatma progress.

**Phase 2 — The day view & manual plan**
- Home screen with big blocks (expandable), next-prayer card, daily progress ring.
- Shift-schedule input (14 days). A **deterministic (non-AI) scheduler** first:
  place fixed anchors, then slot flexible tasks with heavy/light rules, breaks,
  and sleep priority. (This makes the app fully useful before any AI cost.)
- Per-task reminders + end-of-day review.

**Phase 3 — Physical & self-development**
- Meal times + 16/8 fasting + post-meal feeling log (+ medical note).
- Sleep windows per shift; exercise/walk placement.
- Islamic-fasting reminders (Mon/Thu, white days).
- Knowledge time (reading min 10 min, book recommendations, skill path,
  daily religious content).

**Phase 4 — Financial**
- Financial month (20–25th start), budgets, daily expense logging, category
  alerts, savings-rate calc + target, charity.

**Phase 5 — AI layer**
- API key setup + secure storage.
- AI plan build, daily re-plan, and the periodic report (numbers + guidance).
- Model routing (Haiku for routine, stronger for reports) + batching for cost.

**Phase 6 — Reports, polish, and device install**
- Bi-weekly + monthly reports UI (visual → numeric).
- Notification-permission flows (Android 13+), exact-alarm permission,
  battery-optimization guidance.
- Build the APK, install on the user's phone, test end-to-end.

---

## 9. Build & install (target: on the user's phone)

- Provide clear steps to build a release/debug APK (`flutter build apk`) and
  install via USB (`flutter install` / `adb install`) or by transferring the APK.
- Document the required Android permissions and how to grant exact-alarm +
  notifications so prayer/adhan fires reliably.
- Note battery-optimization exemption so scheduled notifications aren't killed.

---

## 10. What to confirm with the user as you build

- Exact Arabic wording for reminders and Nouri's lines (keep them neutral/direct).
- Preferred Arabic font.
- The deterministic scheduler's default rules before wiring AI on top.
- Which cheap/strong Claude models to use once he has his API key.

---

*End of brief. Build Nouri step by step, keep it calm and uncluttered, never
guilt the user, and remember: Nouri is the companion that hands him a ready day
so he stops feeling lost.*
