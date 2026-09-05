# Nouri — Slice 1 Design: Foundation + Religious Core

**Date:** 2026-09-05
**Status:** Approved — ready for implementation planning
**Source brief:** `Nouri_Project_Brief.md`
**Scope:** Brief Phase 0 + Phase 1, plus a deterministic 7-day religious summary

---

## 1. Why this slice

Nouri exists because the user feels his day slips away. The fastest path to that
value is not the scheduling engine — it is the religious core, because it is used
five-plus times every single day, needs no AI, costs nothing to run, and proves
the hardest technical risk in the product (exact, reliable notifications while the
app is closed).

This slice ends with an APK installed on the user's phone that is genuinely useful
on its own: it calls him to prayer, records how he prayed, carries his athkar and
tasbeeh, tracks his Qur'an wird, and shows him the last seven days.

The project is decomposed into five slices. Each gets its own spec → plan →
implementation cycle, and each ends with an installable APK:

1. **Foundation + Religious core** ← this document
2. Scheduling engine + day view (deterministic, no AI)
3. Physical + self-development pillars
4. Financial pillar
5. AI layer + full six-pillar reports

---

## 2. Decisions locked with the user

| Area | Decision |
|---|---|
| Voice | MSA for structural text (tabs, pillar names, settings, report labels); Egyptian colloquial when Nouri speaks to the user (reminders, progress lines, end-of-day questions). Exception: the Home tab keeps its approved colloquial name «النهاردة». |
| Interface font | **Cairo** |
| Religious-text font | **Amiri** (naskh) — visually separates text to be recited from app chrome |
| Adhan sound | Ships with a synthesised calm chime. Any `takbir.mp3` / `adhan.mp3` dropped into `assets/audio/` is picked up instead, with no code change. No audio is downloaded from the internet. |
| Athkar corpus | Curated core set: ~15 morning, ~15 evening, ~10 before-sleep, plus the tasbeeh wird |
| Virtue (الفضل) | **Tap to reveal**, never shown by default. Ships only where wording is well-established; otherwise omitted entirely rather than guessed. Every entry carries its source. |
| Repeat counts | A dhikr with target *n* behaves as a mini-tasbeeh: shows `٠/n`, requires *n* taps, then advances. Going back is always allowed. |
| Prayer states | مسجد · جماعة · في الوقت · متأخرة · لسه (unlogged). Shown as coloured chips: gold / green / neutral / orange / plain. **Never red, never an ✗.** |
| Home layout | All five prayers listed (compact, next one emphasised, every row tappable to log); prominent next-prayer card above them; الورد اليومي as a 2×2 grid in the order أذكار الصباح · التسبيح · أذكار المساء · ورد القرآن |
| Report pillar order | Fixed (الديني · البدني · تطوير الذات · الاقتصادي · الوقت والدوام) so periods compare cleanly. Nouri's *prose* leads with the strongest pillar and names the weakest as the next step. |
| Notification strategy | Rolling 7-day window of exact alarms, re-armed on app open, boot, and a daily background top-up |
| Reports tab in this slice | Real but deterministic: last-7-days religious summary. No AI, no network. |
| Finance tab in this slice | Calm, polished «قريباً إن شاء الله» placeholder in the navy/gold language — must not read as broken |

### Contracts that later slices must not break

The Home header (Hijri date + greeting + نوري avatar), the daily progress ring,
and the next-prayer card are **fixed**. When the Phase-2 scheduler lands it
replaces only the middle section of Home (prayer list + wird grid → four
expandable day-blocks). This was validated visually with the user before approval.

---

## 3. Architecture

**Stack:** Flutter (Dart 3), Android only for now. `minSdk 26`, `targetSdk 35`.
minSdk 26 buys native notification channels and avoids every legacy notification
code path.

```
lib/
  core/
    theme/          colours, typography, radii, the Nouri design tokens
    l10n/           ARB files (ar default, en), RTL-first
    router/         go_router configuration
    time/           prayer-time computation, Hijri conversion, timezone helpers
    notifications/  channels, scheduler, permissions, boot + top-up handlers
  data/
    db/             drift database, tables, DAOs, migrations
    assets/         athkar JSON loader + schema validation
  features/
    home/           Home screen, progress ring, next-prayer card
    prayers/        prayer list, logging sheet, scoring
    athkar/         tabs, dhikr stepper, circular tasbeeh
    quran/          wird logging, khatma progress
    reports/        deterministic 7-day religious summary
    settings/       location, method, offsets, sound, target, language,
                    notification status + test notification
assets/
  athkar/           morning.json, evening.json, sleep.json, tasbeeh.json
  audio/            chime.ogg (+ optional user-supplied adhan.mp3)
  fonts/            Cairo, Amiri
```

**State management:** Riverpod. **Persistence:** drift (typed SQL + migrations).
**Navigation:** go_router. Feature-first folders keep each area independently
readable and testable; nothing in `features/` imports another feature directly —
shared behaviour lives in `core/` or `data/`.

**Key packages** (versions pinned at install time, not guessed here):
`adhan`, `hijri`, `flutter_local_notifications`, `timezone`, `flutter_timezone`,
`geolocator`, `drift` + `sqlite3_flutter_libs`, `flutter_riverpod`, `go_router`,
`workmanager`, `permission_handler`, `flutter_localizations` + `intl`,
`audioplayers` (in-app sound preview only — the notification sound itself is a
channel property, not a player call).

---

## 4. Data model (this slice)

Drift tables. Later slices add to this schema; nothing here is provisional.

```
settings          single row: locale, latitude, longitude, city_label,
                  calculation_method, madhab, iqama_offsets (JSON, per prayer),
                  adhan_sound_mode, tasbeeh_target, khatma_total_pages,
                  notifications_enabled (per channel), onboarding_complete

prayer_logs       id, date, prayer (fajr|dhuhr|asr|maghrib|isha),
                  scheduled_time, state (mosque|congregation|ontime|late|none),
                  score, logged_at
                  UNIQUE(date, prayer)

athkar_logs       id, date, type (morning|evening|sleep|tasbeeh),
                  progress_count, target_count, completed_at
                  UNIQUE(date, type)

quran_log         id, date, pages_read, running_khatma_pages, completed_at
                  UNIQUE(date)
```

Athkar **content** is not in the database. It is a versioned JSON asset — static,
diffable in git, and reviewable as a file, which matters for religious text.

### Athkar asset schema

```json
{
  "version": 1,
  "category": "morning",
  "items": [
    {
      "id": "morning-01",
      "text": "…",              // Arabic, fully vowelled
      "count": 3,
      "source": "رواه مسلم",     // required — always displayed
      "virtue": null,            // null when not well-established → hidden
      "note": null
    }
  ]
}
```

**Verification process:** the build generates `docs/athkar-verification.md`, a
plain sheet listing every dhikr with its text, count, source and virtue, for the
user (or someone he trusts) to check against a physical حصن المسلم before the app
is relied on. The loader validates the schema at startup and fails loudly in
debug, never silently in release.

---

## 5. Prayer engine

- `adhan` package, `CalculationMethod.kuwait`, standard (Shafi) Asr, all
  overridable in Settings.
- Coordinates from `geolocator`, with **Kuwait City (29.3759, 47.9774) hard-coded
  as the fallback**. The app is fully functional before any location permission is
  granted — location improves accuracy, it is never a gate.
- `timezone` + `flutter_timezone` so scheduling is correct across DST and travel.
- Hijri dates via `hijri`, with a user-adjustable ±1 day offset in Settings
  (Hijri civil calculation commonly differs from local moon sighting by a day).
- Iqama offsets, defaulting to Fajr +20, Dhuhr +15, Asr +15, Maghrib +10,
  Isha +15 minutes, each editable.

---

## 6. Notification engine

This is the highest-risk component in the slice. Everything below exists because
a missed adhan makes the app worthless.

### Channels

Five separate Android notification channels — `adhan`, `iqama`, `athkar`, `wird`,
`general` — so one can be silenced without killing the others. Channel sound is
immutable after creation, so channel IDs are **versioned** (`adhan_v1`); changing
a sound creates `adhan_v2` and deletes the old channel.

### Scheduling

- Compute and schedule a **rolling 7-day window** via
  `flutter_local_notifications.zonedSchedule` with
  `AndroidScheduleMode.exactAllowWhileIdle` (fires through Doze).
- ~100 pending alarms — far below Android's ~500-per-app cap.
- **Deterministic notification IDs** derived from date + slot, so re-arming is
  idempotent and can never duplicate or orphan an alarm.
- `USE_EXACT_ALARM` declared in the manifest. Because the APK is sideloaded rather
  than distributed through Play, Android grants it automatically — no runtime
  prompt, and the user cannot accidentally revoke it.

### Re-arming — three independent triggers

1. App resume
2. Device boot (`BOOT_COMPLETED` receiver)
3. Daily background top-up (`workmanager`)

Any one surviving keeps the adhan firing. This redundancy is deliberate.

### Required behaviours (user-specified)

1. **Notification status screen** in Settings, stating plainly whether
   notifications are enabled, whether exact alarms are permitted, and whether
   battery optimisation is exempted — each with a one-tap route to the relevant
   system settings page.
2. **"Send test notification"** action, so the whole chain can be verified on the
   real device in seconds.
3. **In-app battery-optimisation guidance** — clear, specific steps, since OEM
   battery managers are the most common cause of silently killed alarms.
4. **Explicit fallback:** if exact alarms are unavailable on a given device or
   Android version, Nouri says so plainly in the status screen and falls back to
   the best available scheduling mode. It never fails silently and never pretends
   to be reliable when it is not.
5. **Full reschedule on change:** any change to location, calculation method,
   madhab, timezone, iqama offsets, or notification preferences cancels and
   rebuilds the rolling window immediately.

### Prayer follow-up

After each adhan, a follow-up notification carries a **«صليت»** action that logs
`في الوقت` directly from the shade. Opening the app allows upgrading that entry to
جماعة or في المسجد. No notification ever scolds; an unlogged prayer stays «لسه».

### First-launch permission flow

Notifications (Android 13+ runtime permission) → battery-optimisation exemption →
location. Each step explains *why* in one plain sentence, and each is skippable —
the app degrades rather than blocks.

---

## 7. Scoring

| State | Score |
|---|---|
| في المسجد | 100 |
| جماعة | 85 |
| في الوقت | 70 |
| متأخرة / قضاء | 40 |
| لسه (unlogged) | not counted — never penalised |

The Home ring shows a **plain count of the nine daily religious items** (5 prayers
+ morning athkar + evening athkar + tasbeeh + Qur'an wird), not a percentage. It
fills; it never turns red; an incomplete day is simply a partly-filled ring.
Numeric scores appear only in the Reports tab, per the brief.

---

## 8. Screens

All three were mocked and approved visually before this spec was written.

**Home / النهاردة** — Hijri date + time-of-day greeting + نوري avatar; daily
progress ring with a colloquial Nouri line; prominent next-prayer card (name,
time, live countdown, iqama); all five prayers as compact tappable rows with state
chips; الورد اليومي 2×2 grid (أذكار الصباح · التسبيح · أذكار المساء · ورد القرآن)
with completed cards subtly dimmed and softly green-checked.

**الأذكار والتسبيح** — four tabs (التسبيح · الصباح · المساء · النوم). Tasbeeh: a
100-bead gold ring that fills as you count, large centre counter (`٣٣ من ١٠٠`),
progress bar, large «سبّح» button, reset, adjustable target. Athkar tabs: step
dots for position in the set, dhikr in Amiri, `٠/n` count pill requiring *n* taps,
«تمّ» to advance, back always available, tap-to-reveal virtue, source always shown.

**التقارير (this slice: deterministic religious summary)** — last 7 days: prayer
states per day, daily completion count, Qur'an wird streak, tasbeeh totals. Uses
the approved report visual language, but labelled clearly as a local religious
summary. No AI, no network, no cross-pillar scoring yet.

**المالية** — calm «قريباً إن شاء الله» placeholder in the navy/gold language.

**الإعدادات** — location and city, calculation method, madhab, Hijri offset, iqama
offsets, adhan sound mode, tasbeeh target, khatma length, language (ar/en),
per-channel notification toggles, notification status panel, test notification.

---

## 9. Testing strategy

Tests are written **before** implementation (TDD). Priority order reflects where
failure is invisible:

1. **Prayer-time computation** — verified against known Kuwait timetable values
   for several dates across the year, including DST-adjacent and year boundaries.
2. **Rolling-window logic** — window never empties, re-arming is idempotent, IDs
   are stable, changing a setting fully rebuilds the window.
3. **Notification ID generation** — no collisions across dates and slots.
4. **Scoring rules** — every state, plus the rule that unlogged is never penalised.
5. **Athkar JSON** — schema validation, required `source`, counts ≥ 1, entries
   with no established virtue carry `null` rather than invented text.
6. **Hijri conversion** including the user offset.
7. **Widget tests** — tasbeeh increment/reset/target-change; prayer logging sheet;
   dhikr stepper advancing only after *n* taps.

---

## 10. Build, permissions, install

Manifest declares `POST_NOTIFICATIONS`, `USE_EXACT_ALARM`,
`RECEIVE_BOOT_COMPLETED`, `FOREGROUND_SERVICE` (top-up), and location permissions.
Delivery is `flutter build apk --release` installed over USB via `flutter install`
/ `adb install`, with written steps for granting notification and exact-alarm
permissions and exempting Nouri from battery optimisation.

---

## 11. Risks and open items

| Risk | Handling |
|---|---|
| **Flutter SDK is not installed** on this machine (Android SDK, JDK 17 and adb are present) | First implementation step installs it; ~3 GB, D: has 34.5 GB free |
| OEM battery managers killing alarms | Three independent re-arm triggers + explicit in-app guidance + status screen |
| Religious text accuracy | Sources on every entry; virtue omitted rather than guessed; generated verification sheet for human review before reliance |
| Adhan audio | Synthesised chime ships; user's own file drops in with no code change |
| Hijri date disagreeing with local sighting | User-adjustable ±1 day offset |
| Exact alarms unavailable on some device | Detected, stated plainly in the status screen, best-available fallback used |

---

## 12. Explicitly out of scope for this slice

The scheduling engine and shift input; the four big day-blocks on Home; meals,
fasting, sleep and exercise tracking; knowledge time; all financial features; the
Claude API integration and any network call whatsoever; six-pillar bi-weekly and
monthly reports; iOS.

**This slice makes no network requests of any kind.**
