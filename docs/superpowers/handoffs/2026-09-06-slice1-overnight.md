# Nouri — Slice 1 handoff (overnight autonomous session)

**Written:** 2026-09-06, early morning
**Branch:** `slice1-religious-core` (pushed to `origin`)
**Master:** untouched, as instructed — nothing merged

---

## 1. Where things stand

**All 18 code tasks of the Slice 1 plan are complete.** Task 19 (build,
install, verify) is complete on the **emulator**; the parts that require your
real HONOR VNE-N41 are listed in §7 and have deliberately **not** been claimed
as passing.

```
flutter test      254 passed, 0 failed
flutter analyze   No issues found!
```

| Task | Title | Status |
|---|---|---|
| 1 | Toolchain and project scaffold | ✅ |
| 2 | Design tokens and theme | ✅ |
| 3 | Arabic numerals, localization, RTL | ✅ |
| 4 | Database, DAOs, offline guard | ✅ |
| 5 | Prayer times and Hijri dates | ✅ |
| 6 | Notification slots, deterministic IDs | ✅ |
| 7 | Rolling 7-day window | ✅ |
| 8 | Channels, permissions, status, fallback | ✅ code; device checks pending |
| 9 | App shell, nav, Finance placeholder | ✅ |
| 10 | Home header, ring, next-prayer card | ✅ |
| 11 | Prayer rows, logging, scoring | ✅ |
| 12 | Athkar content + verification sheet | ✅ code; **human review pending** |
| 13 | Athkar tabs, stepper, multi-tap | ✅ |
| 14 | Circular tasbeeh | ✅ |
| 15 | Qur'an wird, wird grid | ✅ |
| 16 | Deterministic 7-day summary | ✅ |
| 17 | Settings, status panel, test notification | ✅ |
| 18 | First-launch permission flow | ✅ |
| 19 | Build, install, verify | ✅ emulator; ❗ real device pending |

---

## 2. What was built

- **Foundation** — Flutter app `com.nouri.nouri`, minSdk 26 / targetSdk 35 /
  compileSdk 37, Arabic-first with RTL as the default direction, Cairo (UI) and
  Amiri (religious text), the locked navy/gold palette.
- **Data** — drift/SQLite with four tables and four DAOs. Everything is
  on-device. A guard test fails the build if any network dependency, HTTP call
  or the INTERNET permission appears.
- **Prayer engine** — `adhan` with Kuwait defaults, Hijri dates with a ±1 day
  user offset, iqama offsets per prayer.
- **Notification engine** — five versioned channels, deterministic IDs, a
  rolling 7-day exact-alarm window that is idempotent on re-arm, an honest
  status model that degrades to inexact scheduling and says so.
- **Screens** — Home (header, ring, next-prayer card, five prayers, 2×2 wird
  grid), Athkar (tasbeeh + three athkar tabs), Reports (deterministic 7-day
  summary), Finance (calm placeholder), Settings (all preferences + live
  notification status + test notification), and a three-step permission flow.

---

## 3. Emulator functional tests actually performed

Device: **`emulator-5554`, Android 12 / API 31** — deliberately matched to your
HONOR's API level. Timezone Africa/Cairo, 1080×1920.

| Check | Result |
|---|---|
| App installs and launches | ✅ |
| Arabic renders correctly (Cairo) | ✅ |
| RTL layout — nav starts at the right | ✅ |
| Navy/gold theme, no red anywhere | ✅ |
| Hijri date in header | ✅ `٢٣ ربيع الاول ١٤٤٨ هـ` |
| Progress ring, Arabic-Indic digits | ✅ `٠/٩` → `١/٩` |
| Five prayers listed with times | ✅ |
| Prayer logging sheet opens on row tap | ✅ |
| Chip colours gold/green/muted/orange | ✅ |
| Logging a prayer updates the ring | ✅ |
| **Persistence across force-stop + relaunch** | ✅ ring and chip both survived |
| No crashes in logcat | ✅ |

Screenshots were captured at each step and reviewed.

**Not verifiable on the emulator** — anything about real-world alarm delivery
over hours or days, Doze behaviour, OEM battery managers, or reboot survival.
Those are §7.

---

## 4. Bugs found and fixed

Every one of these was caught by a test or by running the app, not by reading
code.

1. **drift upserts threw SQLite 2067.** `insertOnConflictUpdate` targets the
   primary key; with auto-increment ids the `(date, prayer)` and `(date, type)`
   unique indexes never matched, so logging the same prayer twice would have
   crashed. Every upsert now names its conflict target explicitly.
2. **Prayer-time tests were timezone-dependent.** They asserted raw local hours
   while this machine runs on Egypt time; the December case would have failed.
   Assertions now convert to Kuwait wall-clock, with a further test pinning the
   absolute UTC instant.
3. **The prayer log sheet overflowed short screens**, leaving the clear action
   unreachable. Fixed in the widget (scroll-controlled + scrollable), which also
   protects users with large system font sizes.
4. **`INTERNET` would have been merged into the manifest** via `package:http`,
   pulled in transitively by the notification plugins. The manifest now removes
   it with `tools:node="remove"` — stronger than absence, since the OS then
   makes network access impossible regardless of any dependency.
5. **Cairo is a variable font.** Declaring it under several `weight:` keys would
   have rendered every weight identically. Weight is applied through an explicit
   `FontVariation`, guarded by two tests.
6. **`الإقامة` appeared twice in Settings** — a notification toggle and the
   offsets section. Renamed the section to `فرق وقت الإقامة`; a real UI
   ambiguity fixed in the screen, not papered over in the test.

### Build blockers resolved (environment, not code)

| Blocker | Fix |
|---|---|
| `Failed to find target 'android-37'` | `compileSdkMinor = 0` — SDK 37 installs as `android-37.0` |
| Kotlin `Could not close incremental caches` | `kotlin.incremental=false` (reproducible defect on Kotlin 2.3.20 + Gradle 9.1 + AGP 9.0.1 on Windows) |
| `checkDebugAarMetadata` desugaring error | `isCoreLibraryDesugaringEnabled` + `desugar_jdk_libs:2.1.5` |
| A build hung 25 min on a stalled download | 60 s HTTP socket/connection timeouts in `gradle.properties` |
| Gradle wiped its own 849 MB cache mid-session | Re-downloaded; no action needed, but it explains one long build |

---

## 5. Known limitations

- **The athkar text has not been checked against a printed copy.**
  `docs/athkar-verification.md` lists all 45 entries and opens by saying so.
  Only 8 carry a stated virtue; the other 37 ship with none by design.
  **Please review this before relying on the app for athkar.**
- **The adhan sound is a synthesised chime**, not a real adhan. Generated
  offline by `tool/generate_chime.py`. To swap it in: drop `adhan.mp3` into
  `android/app/src/main/res/raw/` and bump the channel id to `adhan_v2` in
  `notification_channels.dart` (Android freezes channel sound at creation).
- **Location is not yet wired to `geolocator`.** The permission step exists, but
  coordinates stay at the Kuwait default. Prayer times are correct for Kuwait;
  they will not follow you if you travel. Small, isolated follow-up.
- **The daily background top-up (`workmanager`) is not implemented.** Two of the
  three re-arm triggers are live — app resume and the boot receiver. The third
  is a robustness layer, not a requirement for correctness.
- **Generated code is gitignored** (`*.g.dart`). A fresh clone must run
  `dart run build_runner build` before `flutter test`. Documented in
  `docs/setup.md`.
- **The 05:13 reminder is session-only.** If the session ended, it did not fire.
  This document is the durable handoff.

---

## 6. Build artefacts

```
build/app/outputs/flutter-apk/app-debug.apk
```

Debug APK is ~175 MB because debug builds bundle every ABI and skip
minification. The release build is far smaller — see §8.

Rebuild with:

```powershell
$env:PATH = 'D:\dev-tools\flutter\bin;' + $env:PATH
flutter build apk --debug     # or --release
```

---

## 7. Remaining tests that need your HONOR VNE-N41

**None of these have been verified.** HONOR/MagicOS background-kill behaviour,
reboot survival and long-running exact-alarm reliability cannot be tested on an
emulator, and are not claimed as passing.

Install first:

```powershell
adb devices                                     # phone must be listed
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Then, in order:

1. **Open Nouri.** The permission flow should appear (three steps). Accept all
   three, or skip and set them from Settings.
2. **Settings → حالة التنبيهات.** Confirm all three rows show a green tick:
   الإشعارات مفعّلة · التنبيهات الدقيقة مسموحة · مستثنى من توفير البطارية.
   On Android 12 the first two are usually granted at install.
3. **HONOR App launch** — Settings → Battery → App launch → نوري → switch from
   *Manage automatically* to *Manage manually*, then enable all three:
   Auto-launch, Secondary launch, Run in background. **This is the step that
   most often decides whether the adhan keeps working after a day or two.**
4. **Battery** — Settings → Apps → نوري → Battery → **No restrictions**.
5. **Alarms & reminders** — Settings → Apps → نوري → Alarms & reminders →
   allowed. (Or Apps → ⋮ → Special access → Alarms & reminders.)
6. **Tap «إرسال إشعار تجريبي»** in Settings. A notification should appear
   immediately.
7. **Wait for a real prayer with the app swiped away.** Confirm the adhan fires
   at the right minute and the chime plays.
8. **Confirm the iqama notification** follows at the configured offset.
9. **Use the «صليت» action** on the follow-up notification and confirm the
   prayer is logged without opening the app.
10. **Reboot the phone.** Wait for the next prayer without opening Nouri.
    Confirm the adhan still fires — this proves the boot receiver.
11. **Leave it a full day untouched.** Confirm notifications are still arriving
    the next morning; this is what catches OEM battery-kill.
12. **Airplane mode.** Everything must keep working — the app makes no network
    calls at all.
13. **Check prayer times against your local Kuwait timetable.** If they are off
    by more than a minute or two, change the calculation method in Settings.

Record results in `docs/install.md` (not yet created — it should be written from
the actual outcomes rather than in advance).

---

## 8. Suggested next steps

1. Work through §7 on the phone.
2. Review `docs/athkar-verification.md`.
3. Supply a real adhan MP3 if you want one.
4. Build the release APK for daily use:
   `flutter build apk --release` — note the release build currently signs with
   debug keys (the Flutter default); a real signing config is worth adding
   before you rely on it long-term.
5. When Slice 1 is confirmed on the phone, merge `slice1-religious-core` into
   `master` and start Slice 2 (the scheduling engine).
