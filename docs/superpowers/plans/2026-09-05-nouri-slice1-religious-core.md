# Nouri Slice 1 — Foundation + Religious Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an installable Android APK that calls the user to prayer on time with the app closed, records how he prayed without ever shaming him, and carries his athkar, tasbeeh and Qur'an wird — with a deterministic 7-day summary of all of it.

**Architecture:** Flutter app, Android-only, entirely offline. Riverpod for state, drift for typed SQLite, go_router for navigation, feature-first folders. Prayer times are computed on-device with the `adhan` package and scheduled as a rolling 7-day window of exact alarms, re-armed from three independent triggers (app resume, device boot, daily background top-up) so no single failure silences the adhan.

**Tech Stack:** Flutter (Dart 3) · drift + sqlite3_flutter_libs · flutter_riverpod · go_router · adhan · hijri · flutter_local_notifications · timezone + flutter_timezone · geolocator · workmanager · permission_handler · flutter_localizations + intl

**Spec:** `docs/superpowers/specs/2026-09-05-nouri-slice1-religious-core-design.md`

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Platform:** Android only. `minSdk 26`, `targetSdk 35`, `compileSdk 35`. JDK 17.
- **No network. At all.** This slice makes zero HTTP requests. No `http`, `dio`, `anthropic` or any network package may appear in `pubspec.yaml`. Task 4 adds a test that enforces this.
- **Default locale is Arabic; default direction is RTL.** English is a supported alternative, never the baseline. Never hardcode a user-visible string in a widget — every string goes through the ARB files.
- **Voice rule.** Structural text (tab names, settings labels, report labels, pillar names) is MSA. Text where Nouri speaks to the user (reminders, progress lines, questions) is Egyptian colloquial. The Home tab keeps its approved colloquial name «النهاردة».
- **Never punish.** No red, no ✗, no "failed", no "missed" anywhere in UI or notification copy. An unlogged item reads «لسه». The only warm colour permitted for attention is `#E8955A`, and never for a religious action the user simply hasn't done yet.
- **Colours (exact):** background `#0E2A3B` · surface `#16384C` · surface-active `#1B4763` · border `#2C6486` · gold `#D9A73E` · text `#EAF2F5` · muted `#8FB3C4` · success `#5DCAA5` · attention `#E8955A`. Card radius 14–16. Flat: no gradients, no heavy shadows.
- **Fonts:** Cairo for all interface text. Amiri for athkar and Qur'an text only.
- **Numerals:** all user-facing numbers render as Arabic-Indic (٠١٢٣٤٥٦٧٨٩) in the Arabic locale via the shared formatter from Task 3. Never `toString()` a number straight into a widget.
- **Religious text integrity:** every athkar entry carries a non-empty `source`. The `virtue` field is `null` unless the wording is well-established — never invented, never embellished. The app hides the reveal when `virtue` is null.
- **Prayer scores:** مسجد 100 · جماعة 85 · في الوقت 70 · متأخرة 40 · unlogged is not counted and never penalised.
- **TDD.** Every task writes the failing test first, watches it fail, then implements. Commit at the end of every task.
- **Test command:** `flutter test` from the project root. Single file: `flutter test test/path/to/file_test.dart`.

---

## File Structure

```
lib/
  main.dart                                    app entry, ProviderScope, init
  core/
    theme/nouri_colors.dart                    colour tokens
    theme/nouri_theme.dart                     ThemeData, text styles, radii
    l10n/app_ar.arb, app_en.arb                strings (ar is the template)
    l10n/l10n.dart                             locale list + helpers
    format/arabic_numerals.dart                digit + duration + time formatting
    time/hijri_date.dart                       Hijri conversion + user offset
    time/prayer_times_service.dart             adhan wrapper, DailyPrayerTimes
    time/geo_config.dart                       coordinates, method, madhab
    notifications/notification_slot.dart       slot enum + deterministic IDs
    notifications/notification_gateway.dart    abstract gateway (testable seam)
    notifications/local_notification_gateway.dart   flutter_local_notifications impl
    notifications/notification_channels.dart   5 versioned channels
    notifications/rolling_window_scheduler.dart     the 7-day window
    notifications/notification_status.dart     permission + exact-alarm status
    notifications/rearm_triggers.dart          resume / boot / workmanager wiring
    router/app_router.dart                     go_router config
  data/
    db/nouri_database.dart                     drift database + migrations
    db/tables.dart                             settings, prayer_logs, athkar_logs, quran_log
    db/settings_dao.dart
    db/prayer_dao.dart
    db/athkar_dao.dart
    db/quran_dao.dart
    athkar/athkar_item.dart                    model + JSON parsing + validation
    athkar/athkar_repository.dart              asset loader
  features/
    shell/app_shell.dart                       5-tab scaffold + bottom nav
    home/home_screen.dart
    home/widgets/home_header.dart
    home/widgets/progress_ring.dart
    home/widgets/next_prayer_card.dart
    home/widgets/wird_grid.dart
    home/daily_items.dart                      the nine-item model behind the ring
    prayers/prayer_row.dart
    prayers/prayer_log_sheet.dart
    prayers/prayer_scoring.dart
    athkar/athkar_screen.dart
    athkar/widgets/dhikr_card.dart
    athkar/widgets/dhikr_stepper.dart
    athkar/widgets/tasbeeh_ring.dart
    quran/quran_wird_card.dart
    reports/reports_screen.dart
    reports/weekly_summary.dart                pure computation over DAO rows
    finance/finance_placeholder.dart
    settings/settings_screen.dart
    settings/notification_status_panel.dart
    onboarding/permission_flow.dart
assets/
  athkar/morning.json, evening.json, sleep.json, tasbeeh.json
  audio/chime.ogg
  fonts/Cairo-Regular.ttf, Cairo-SemiBold.ttf, Cairo-Bold.ttf, Amiri-Regular.ttf
tool/
  generate_athkar_verification.dart            writes docs/athkar-verification.md
test/
  (mirrors lib/ structure)
```

---

## Task 1: Toolchain and project scaffold

Flutter is **not installed** on this machine. The Android SDK (`D:\dev-tools\android-sdk`, platforms 34/35/36), JDK 17 and adb are already present.

**Files:**
- Create: the Flutter project at `E:\cloud\noury` (project name `nouri`)
- Modify: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- Create: `docs/setup.md`

**Interfaces:**
- Consumes: nothing
- Produces: a runnable Flutter app; `flutter test` and `flutter build apk` both work

- [ ] **Step 1: Install the Flutter SDK**

```bash
git clone https://github.com/flutter/flutter.git -b stable D:/dev-tools/flutter
```

Then add `D:\dev-tools\flutter\bin` to the user PATH (PowerShell, then restart the shell):

```powershell
[Environment]::SetEnvironmentVariable('Path', $env:Path + ';D:\dev-tools\flutter\bin', 'User')
```

- [ ] **Step 2: Verify the toolchain**

Run:
```bash
flutter config --android-sdk D:/dev-tools/android-sdk
flutter doctor -v
flutter doctor --android-licenses
```
Expected: "Flutter" and "Android toolchain" both ✓. Chrome/Visual Studio warnings are fine — this is an Android-only app.

- [ ] **Step 3: Create the project in place**

The directory already contains the brief, `docs/` and `.git`. Scaffold into a temp dir and move, so nothing is clobbered:

```bash
cd /d/dev-tools && flutter create --org com.nouri --project-name nouri --platforms android nouri_tmp
cp -r nouri_tmp/. /e/cloud/noury/
rm -rf nouri_tmp
cd /e/cloud/noury && git status --short
```
Expected: `lib/`, `test/`, `android/`, `pubspec.yaml` appear; `Nouri_Project_Brief.md`, `docs/` and `.gitignore` are untouched.

- [ ] **Step 4: Set the Android SDK levels**

In `android/app/build.gradle.kts`, inside `android { ... }`:

```kotlin
compileSdk = 35

defaultConfig {
    applicationId = "com.nouri.nouri"
    minSdk = 26
    targetSdk = 35
    versionCode = 1
    versionName = "0.1.0"
}
```

- [ ] **Step 5: Confirm the scaffold runs its own test**

Run: `flutter test`
Expected: PASS — the generated counter widget test passes. This proves the toolchain end-to-end before any Nouri code exists.

- [ ] **Step 6: Write the setup document**

Create `docs/setup.md` recording: the Flutter clone path, the PATH entry, the `flutter config --android-sdk` command, `flutter doctor` expectations, and how to run tests. A future session (or a new machine) must be able to reproduce the environment from this file alone.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter project and document toolchain setup"
```

---

## Task 2: Design tokens and theme

**Files:**
- Create: `lib/core/theme/nouri_colors.dart`, `lib/core/theme/nouri_theme.dart`
- Create: `assets/fonts/` (Cairo variable, Amiri Regular + Bold, both OFL texts)
- Modify: `pubspec.yaml` (fonts + assets)
- Test: `test/core/theme/nouri_theme_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `NouriColors` (static `Color` constants), `nouriTheme()` returning `ThemeData`, `NouriText.dhikr` / `NouriText.counter`, and `cairo({double size, FontWeight weight, Color color, double? height})` — the helper that applies the variable weight axis

- [x] **Step 1: Download the fonts** *(done ahead of Task 1, while the SDK downloaded)*

Google Fonts ships Cairo as a **variable font only** — `Cairo[slnt,wght].ttf`, axes `slnt` and `wght`. There are no static Regular/SemiBold/Bold files, and the upstream project publishes none either. Declaring one variable file under three `weight:` entries in `pubspec.yaml` does **not** work: Flutter would pick the file but render its default instance, so "bold" would come out regular.

So the font is bundled once and the weight axis is driven explicitly with `fontVariations`. Files now in `assets/fonts/`:

| File | Size | Purpose |
|---|---|---|
| `Cairo-Variable.ttf` | 586 KB | all interface text, weight via `wght` axis |
| `Amiri-Regular.ttf` | 421 KB | athkar and Qur'an text |
| `Amiri-Bold.ttf` | 404 KB | emphasis within religious text |
| `OFL-Cairo.txt`, `OFL-Amiri.txt` | 4 KB each | SIL Open Font License, both families |

- [ ] **Step 2: Write the failing test**

```dart
// test/core/theme/nouri_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/core/theme/nouri_theme.dart';

void main() {
  test('palette matches the approved design tokens exactly', () {
    expect(NouriColors.background.value, 0xFF0E2A3B);
    expect(NouriColors.surface.value, 0xFF16384C);
    expect(NouriColors.surfaceActive.value, 0xFF1B4763);
    expect(NouriColors.border.value, 0xFF2C6486);
    expect(NouriColors.gold.value, 0xFFD9A73E);
    expect(NouriColors.text.value, 0xFFEAF2F5);
    expect(NouriColors.muted.value, 0xFF8FB3C4);
    expect(NouriColors.success.value, 0xFF5DCAA5);
    expect(NouriColors.attention.value, 0xFFE8955A);
  });

  test('theme uses Cairo for interface text and the navy background', () {
    final theme = nouriTheme();
    expect(theme.scaffoldBackgroundColor, NouriColors.background);
    expect(theme.textTheme.bodyMedium!.fontFamily, 'Cairo');
  });

  test('religious text style uses Amiri with generous line height', () {
    expect(NouriText.dhikr.fontFamily, 'Amiri');
    expect(NouriText.dhikr.height, greaterThanOrEqualTo(1.9));
  });

  test('cairo() carries the weight on the variable wght axis', () {
    // Cairo is a variable font: without an explicit FontVariation the engine
    // renders the default instance and "bold" silently comes out regular.
    final bold = cairo(size: 14, weight: FontWeight.w700);
    expect(bold.fontFamily, 'Cairo');
    expect(bold.fontWeight, FontWeight.w700);
    expect(bold.fontVariations, contains(const FontVariation('wght', 700)));

    final regular = cairo(size: 14);
    expect(regular.fontVariations, contains(const FontVariation('wght', 400)));
  });

  test('every theme text style carries its wght variation', () {
    final t = nouriTheme().textTheme;
    for (final style in [t.titleLarge!, t.bodyMedium!, t.bodySmall!]) {
      expect(style.fontVariations, isNotEmpty,
          reason: 'a Cairo style without fontVariations renders at default weight');
    }
  });

  test('palette contains no red', () {
    for (final c in NouriColors.all) {
      final isRed = c.red > 200 && c.green < 90 && c.blue < 90;
      expect(isRed, isFalse, reason: 'Nouri never shows a failure red: $c');
    }
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/theme/nouri_theme_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:nouri/core/theme/nouri_colors.dart'`

- [ ] **Step 4: Implement the colour tokens**

```dart
// lib/core/theme/nouri_colors.dart
import 'package:flutter/material.dart';

/// The locked Nouri palette. Calm, spiritual, uncluttered — and deliberately
/// without a failure red: Nouri encourages continuation, it never punishes.
abstract final class NouriColors {
  static const background    = Color(0xFF0E2A3B);
  static const surface       = Color(0xFF16384C);
  static const surfaceActive = Color(0xFF1B4763);
  static const border        = Color(0xFF2C6486);
  static const gold          = Color(0xFFD9A73E);
  static const text          = Color(0xFFEAF2F5);
  static const muted         = Color(0xFF8FB3C4);
  static const success       = Color(0xFF5DCAA5);
  static const attention     = Color(0xFFE8955A);

  static const all = <Color>[
    background, surface, surfaceActive, border,
    gold, text, muted, success, attention,
  ];
}
```

- [ ] **Step 5: Implement the theme**

```dart
// lib/core/theme/nouri_theme.dart
import 'package:flutter/material.dart';
import 'nouri_colors.dart';

abstract final class NouriRadius {
  static const card = 15.0;
  static const chip = 20.0;
}

/// Cairo is a variable font. `fontWeight` alone selects the file but renders
/// its default instance, so every Cairo style must also set the `wght`
/// variation. This helper is the only sanctioned way to build one.
TextStyle cairo({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = NouriColors.text,
  double? height,
}) =>
    TextStyle(
      fontFamily: 'Cairo',
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
      color: color,
      height: height,
    );

abstract final class NouriText {
  /// Athkar and Qur'an text only — never interface chrome. Amiri ships static
  /// Regular and Bold, so it needs no variation axis.
  static const dhikr = TextStyle(
    fontFamily: 'Amiri', fontSize: 21, height: 2.0, color: NouriColors.text,
  );
  static final counter = cairo(size: 46, weight: FontWeight.w700, height: 1.0);
}

ThemeData nouriTheme() {
  const scheme = ColorScheme.dark(
    primary: NouriColors.gold,
    surface: NouriColors.surface,
    onSurface: NouriColors.text,
    secondary: NouriColors.success,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: NouriColors.background,
    fontFamily: 'Cairo',
    cardTheme: const CardThemeData(
      color: NouriColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    textTheme: TextTheme(
      titleLarge: cairo(size: 19, weight: FontWeight.w700),
      bodyMedium: cairo(size: 14),
      bodySmall: cairo(size: 12, color: NouriColors.muted),
    ),
  );
}
```

- [ ] **Step 6: Register fonts and assets in `pubspec.yaml`**

One entry per family. Cairo is declared once — listing the same variable file
under several `weight:` keys would not produce different weights.

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/athkar/
    - assets/audio/
  fonts:
    - family: Cairo
      fonts:
        - asset: assets/fonts/Cairo-Variable.ttf
    - family: Amiri
      fonts:
        - asset: assets/fonts/Amiri-Regular.ttf
        - asset: assets/fonts/Amiri-Bold.ttf
          weight: 700
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/core/theme/nouri_theme_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml assets/fonts lib/core/theme test/core/theme
git commit -m "feat: add Nouri design tokens, theme, and Cairo/Amiri fonts"
```

---

## Task 3: Arabic numerals, localization and RTL

**Files:**
- Create: `lib/core/format/arabic_numerals.dart`, `lib/core/l10n/app_ar.arb`, `lib/core/l10n/app_en.arb`, `lib/core/l10n/l10n.dart`, `l10n.yaml`
- Modify: `pubspec.yaml`, `lib/main.dart`
- Test: `test/core/format/arabic_numerals_test.dart`, `test/core/l10n/l10n_test.dart`

**Interfaces:**
- Consumes: `nouriTheme()` from Task 2
- Produces: `toArabicDigits(String)`, `formatCountdown(Duration)`, `formatClock(DateTime, {bool arabic})`, `L10n.supportedLocales`, and the generated `AppLocalizations`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/format/arabic_numerals_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/format/arabic_numerals.dart';

void main() {
  group('toArabicDigits', () {
    test('converts every western digit', () {
      expect(toArabicDigits('0123456789'), '٠١٢٣٤٥٦٧٨٩');
    });
    test('preserves separators and letters', () {
      expect(toArabicDigits('1:24:10'), '١:٢٤:١٠');
      expect(toArabicDigits('33 من 100'), '٣٣ من ١٠٠');
    });
    test('is a no-op on text with no digits', () {
      expect(toArabicDigits('الفجر'), 'الفجر');
    });
  });

  group('formatCountdown', () {
    test('renders h:mm:ss in Arabic-Indic digits', () {
      expect(formatCountdown(const Duration(hours: 1, minutes: 24, seconds: 10)),
          '١:٢٤:١٠');
    });
    test('pads minutes and seconds', () {
      expect(formatCountdown(const Duration(hours: 2, minutes: 5, seconds: 3)),
          '٢:٠٥:٠٣');
    });
    test('clamps a negative duration to zero rather than showing a minus', () {
      expect(formatCountdown(const Duration(seconds: -30)), '٠:٠٠:٠٠');
    });
  });

  group('formatClock', () {
    test('renders 12-hour time in Arabic-Indic digits', () {
      expect(formatClock(DateTime(2026, 9, 5, 15, 15)), '٣:١٥');
      expect(formatClock(DateTime(2026, 9, 5, 4, 21)), '٤:٢١');
      expect(formatClock(DateTime(2026, 9, 5, 0, 5)), '١٢:٠٥');
    });
    test('renders western digits when arabic is false', () {
      expect(formatClock(DateTime(2026, 9, 5, 15, 15), arabic: false), '3:15');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/format/arabic_numerals_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement the formatter**

```dart
// lib/core/format/arabic_numerals.dart

const _arabicZero = 0x0660;
const _westernZero = 0x30;

/// Rewrites western digits as Arabic-Indic, leaving everything else alone.
/// Every user-facing number in the Arabic locale goes through here — Nouri
/// never renders a raw `toString()` into the UI.
String toArabicDigits(String input) => input.replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => String.fromCharCode(
          m.group(0)!.codeUnitAt(0) - _westernZero + _arabicZero),
    );

/// `h:mm:ss`, clamped at zero — a passed prayer shows ٠:٠٠:٠٠, never a minus.
String formatCountdown(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  final h = safe.inHours;
  final m = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return toArabicDigits('$h:$m:$s');
}

/// 12-hour clock without the am/pm marker (the surrounding UI carries it).
String formatClock(DateTime t, {bool arabic = true}) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final raw = '$hour12:${t.minute.toString().padLeft(2, '0')}';
  return arabic ? toArabicDigits(raw) : raw;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/format/arabic_numerals_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Add localization configuration**

Create `l10n.yaml` at the project root:

```yaml
arb-dir: lib/core/l10n
template-arb-file: app_ar.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
```

Add to `pubspec.yaml` under `dependencies:`:

```yaml
  flutter_localizations:
    sdk: flutter
  intl: any
```

and under `flutter:` add `generate: true`.

- [ ] **Step 6: Write the Arabic strings (the template)**

`lib/core/l10n/app_ar.arb` — note the voice rule: `tab*`, `settings*` and `label*` keys are MSA; `nouri*` keys are Egyptian colloquial.

```json
{
  "@@locale": "ar",
  "appName": "نوري",
  "tabToday": "النهاردة",
  "tabAthkar": "الأذكار",
  "tabReports": "التقارير",
  "tabFinance": "المالية",
  "tabSettings": "الإعدادات",
  "labelNextPrayer": "الصلاة القادمة",
  "labelIqama": "الإقامة",
  "labelTodayPrayers": "صلوات اليوم",
  "labelDailyWird": "الورد اليومي",
  "labelMorningAthkar": "أذكار الصباح",
  "labelEveningAthkar": "أذكار المساء",
  "labelSleepAthkar": "أذكار النوم",
  "labelTasbeeh": "التسبيح",
  "labelQuranWird": "ورد القرآن",
  "labelSource": "المصدر",
  "labelVirtue": "الفضل",
  "stateMosque": "في المسجد",
  "stateCongregation": "جماعة",
  "stateOnTime": "في الوقت",
  "stateLate": "متأخرة",
  "stateNotYet": "لسه",
  "prayerFajr": "الفجر",
  "prayerDhuhr": "الظهر",
  "prayerAsr": "العصر",
  "prayerMaghrib": "المغرب",
  "prayerIsha": "العشاء",
  "nouriRemainingOnAdhan": "باقي على الأذان",
  "nouriDidYouPray": "صليت {prayer}؟",
  "@nouriDidYouPray": { "placeholders": { "prayer": { "type": "String" } } },
  "nouriPrayedAction": "صليت",
  "nouriProgress": "خلّصت {done} من {total}",
  "@nouriProgress": {
    "placeholders": { "done": { "type": "String" }, "total": { "type": "String" } }
  },
  "nouriComingSoon": "قريباً إن شاء الله",
  "nouriFinancePlaceholder": "الجزء ده لسه في الطريق. لما يجهز هتلاقي هنا مصاريفك وميزانيتك.",
  "nouriTargetAdjustable": "تقدر تزوّده"
}
```

- [ ] **Step 7: Write the English strings**

`lib/core/l10n/app_en.arb` — same keys, plain English (Nouri's colloquial register has no English equivalent; keep English neutral and direct):

```json
{
  "@@locale": "en",
  "appName": "Nouri",
  "tabToday": "Today",
  "tabAthkar": "Athkar",
  "tabReports": "Reports",
  "tabFinance": "Finance",
  "tabSettings": "Settings",
  "labelNextPrayer": "Next prayer",
  "labelIqama": "Iqama",
  "labelTodayPrayers": "Today's prayers",
  "labelDailyWird": "Daily wird",
  "labelMorningAthkar": "Morning athkar",
  "labelEveningAthkar": "Evening athkar",
  "labelSleepAthkar": "Before-sleep athkar",
  "labelTasbeeh": "Tasbeeh",
  "labelQuranWird": "Qur'an wird",
  "labelSource": "Source",
  "labelVirtue": "Virtue",
  "stateMosque": "In the mosque",
  "stateCongregation": "In congregation",
  "stateOnTime": "On time",
  "stateLate": "Late",
  "stateNotYet": "Not yet",
  "prayerFajr": "Fajr",
  "prayerDhuhr": "Dhuhr",
  "prayerAsr": "Asr",
  "prayerMaghrib": "Maghrib",
  "prayerIsha": "Isha",
  "nouriRemainingOnAdhan": "until the adhan",
  "nouriDidYouPray": "Did you pray {prayer}?",
  "nouriPrayedAction": "Prayed",
  "nouriProgress": "You've done {done} of {total}",
  "nouriComingSoon": "Coming soon",
  "nouriFinancePlaceholder": "This part is on its way. Your expenses and budget will live here.",
  "nouriTargetAdjustable": "you can raise it"
}
```

- [ ] **Step 8: Write the localization test**

```dart
// test/core/l10n/l10n_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> load(String p) =>
      jsonDecode(File(p).readAsStringSync()) as Map<String, dynamic>;

  test('ar and en define exactly the same message keys', () {
    final ar = load('lib/core/l10n/app_ar.arb');
    final en = load('lib/core/l10n/app_en.arb');
    keys(Map<String, dynamic> m) =>
        m.keys.where((k) => !k.startsWith('@')).toSet();
    expect(keys(ar).difference(keys(en)), isEmpty,
        reason: 'keys present in Arabic but missing in English');
    expect(keys(en).difference(keys(ar)), isEmpty,
        reason: 'keys present in English but missing in Arabic');
  });

  test('Arabic is the template locale', () {
    expect(load('lib/core/l10n/app_ar.arb')['@@locale'], 'ar');
  });

  test('no Arabic string contains a western digit', () {
    final ar = load('lib/core/l10n/app_ar.arb');
    for (final e in ar.entries) {
      if (e.key.startsWith('@') || e.value is! String) continue;
      final hasPlaceholder = (e.value as String).contains('{');
      if (hasPlaceholder) continue;
      expect(RegExp(r'[0-9]').hasMatch(e.value as String), isFalse,
          reason: '${e.key} must use Arabic-Indic digits');
    }
  });
}
```

- [ ] **Step 9: Run the test and wire up the app**

Run: `flutter test test/core/l10n/l10n_test.dart`
Expected: PASS (3 tests)

Then in `lib/main.dart`, set `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: const [Locale('ar'), Locale('en')]`, `locale: const Locale('ar')` and `theme: nouriTheme()`.

- [ ] **Step 10: Verify RTL is the default**

Run: `flutter run` (or `flutter test` after adding a smoke widget test) and confirm the app renders right-to-left with Cairo. Expected: Arabic UI, RTL direction, navy background.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: add Arabic-Indic numeral formatting, AR/EN localization, RTL default"
```

---

## Task 4: Database, tables and the no-network guard

**Files:**
- Create: `lib/data/db/tables.dart`, `lib/data/db/nouri_database.dart`, `lib/data/db/settings_dao.dart`, `lib/data/db/prayer_dao.dart`, `lib/data/db/athkar_dao.dart`, `lib/data/db/quran_dao.dart`
- Modify: `pubspec.yaml`
- Test: `test/data/db/nouri_database_test.dart`, `test/guard/no_network_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `NouriDatabase`, the `PrayerState` enum (`mosque`, `congregation`, `onTime`, `late_`, `none`), and DAO methods `SettingsDao.get()/update()`, `PrayerDao.upsertLog()/logsForDate()/logsBetween()`, `AthkarDao.upsert()/forDate()/streak()`, `QuranDao.upsert()/forDate()/totalPages()`

- [ ] **Step 1: Add dependencies**

```yaml
dependencies:
  drift: ^2.20.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
dev_dependencies:
  drift_dev: ^2.20.0
  build_runner: ^2.4.13
```

Run: `flutter pub get`

- [ ] **Step 2: Write the failing test**

```dart
// test/data/db/nouri_database_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';

void main() {
  late NouriDatabase db;

  setUp(() => db = NouriDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('settings row is created with Kuwait defaults on first read', () async {
    final s = await db.settingsDao.get();
    expect(s.latitude, closeTo(29.3759, 0.0001));
    expect(s.longitude, closeTo(47.9774, 0.0001));
    expect(s.calculationMethod, 'kuwait');
    expect(s.madhab, 'shafi');
    expect(s.tasbeehTarget, 100);
    expect(s.khatmaTotalPages, 604);
    expect(s.locale, 'ar');
  });

  test('prayer log upsert is idempotent per (date, prayer)', () async {
    final d = DateTime(2026, 9, 5);
    await db.prayerDao.upsertLog(date: d, prayer: 'asr',
        scheduledTime: DateTime(2026, 9, 5, 15, 15), state: PrayerState.onTime);
    await db.prayerDao.upsertLog(date: d, prayer: 'asr',
        scheduledTime: DateTime(2026, 9, 5, 15, 15), state: PrayerState.mosque);

    final logs = await db.prayerDao.logsForDate(d);
    expect(logs, hasLength(1));
    expect(logs.single.state, PrayerState.mosque);
    expect(logs.single.score, 100);
  });

  test('an unlogged prayer scores nothing and is never negative', () async {
    final d = DateTime(2026, 9, 5);
    await db.prayerDao.upsertLog(date: d, prayer: 'fajr',
        scheduledTime: DateTime(2026, 9, 5, 4, 21), state: PrayerState.none);
    final logs = await db.prayerDao.logsForDate(d);
    expect(logs.single.score, 0);
  });

  test('athkar progress is stored per date and type', () async {
    final d = DateTime(2026, 9, 5);
    await db.athkarDao.upsert(date: d, type: 'tasbeeh', progress: 33, target: 100);
    await db.athkarDao.upsert(date: d, type: 'tasbeeh', progress: 47, target: 100);
    final rows = await db.athkarDao.forDate(d);
    expect(rows, hasLength(1));
    expect(rows.single.progressCount, 47);
    expect(rows.single.completedAt, isNull);
  });

  test('reaching the target stamps completedAt exactly once', () async {
    final d = DateTime(2026, 9, 5);
    await db.athkarDao.upsert(date: d, type: 'tasbeeh', progress: 100, target: 100);
    final first = (await db.athkarDao.forDate(d)).single.completedAt;
    expect(first, isNotNull);

    await db.athkarDao.upsert(date: d, type: 'tasbeeh', progress: 120, target: 100);
    final second = (await db.athkarDao.forDate(d)).single.completedAt;
    expect(second, first, reason: 'completion time must not drift on extra taps');
  });

  test('quran pages accumulate into a running khatma total', () async {
    await db.quranDao.upsert(date: DateTime(2026, 9, 4), pages: 3);
    await db.quranDao.upsert(date: DateTime(2026, 9, 5), pages: 3);
    expect(await db.quranDao.totalPages(), 6);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/data/db/nouri_database_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 4: Define the tables**

```dart
// lib/data/db/tables.dart
import 'package:drift/drift.dart';

/// How a prayer was performed. Ordered best to worst, but note that `none`
/// is not a failure — it simply has not been logged yet.
enum PrayerState { mosque, congregation, onTime, late_, none }

extension PrayerStateScore on PrayerState {
  int get score => switch (this) {
        PrayerState.mosque => 100,
        PrayerState.congregation => 85,
        PrayerState.onTime => 70,
        PrayerState.late_ => 40,
        PrayerState.none => 0,
      };
}

class SettingsRows extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get locale => text().withDefault(const Constant('ar'))();
  RealColumn get latitude => real().withDefault(const Constant(29.3759))();
  RealColumn get longitude => real().withDefault(const Constant(47.9774))();
  TextColumn get cityLabel => text().withDefault(const Constant('الكويت'))();
  TextColumn get calculationMethod => text().withDefault(const Constant('kuwait'))();
  TextColumn get madhab => text().withDefault(const Constant('shafi'))();
  IntColumn get hijriOffsetDays => integer().withDefault(const Constant(0))();
  /// JSON: {"fajr":20,"dhuhr":15,"asr":15,"maghrib":10,"isha":15}
  TextColumn get iqamaOffsetsJson => text()
      .withDefault(const Constant('{"fajr":20,"dhuhr":15,"asr":15,"maghrib":10,"isha":15}'))();
  TextColumn get adhanSoundMode => text().withDefault(const Constant('chime'))();
  IntColumn get tasbeehTarget => integer().withDefault(const Constant(100))();
  IntColumn get khatmaTotalPages => integer().withDefault(const Constant(604))();
  BoolColumn get notifyAdhan => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyIqama => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyAthkar => boolean().withDefault(const Constant(true))();
  BoolColumn get notifyWird => boolean().withDefault(const Constant(true))();
  BoolColumn get onboardingComplete => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class PrayerLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  TextColumn get prayer => text()();
  DateTimeColumn get scheduledTime => dateTime()();
  IntColumn get state => intEnum<PrayerState>()();
  IntColumn get score => integer()();
  DateTimeColumn get loggedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{date, prayer}];
}

class AthkarLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  /// morning | evening | sleep | tasbeeh
  TextColumn get type => text()();
  IntColumn get progressCount => integer().withDefault(const Constant(0))();
  IntColumn get targetCount => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{date, type}];
}

class QuranLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get pagesRead => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [{date}];
}
```

- [ ] **Step 5: Implement the database and DAOs**

Rules the DAOs must enforce, because the tests above pin them:
- `SettingsDao.get()` inserts the default row on first call, then returns it.
- `PrayerDao.upsertLog` writes `score` from `state.score` and sets `loggedAt` when `state != PrayerState.none`.
- `AthkarDao.upsert` stamps `completedAt` only on the **first** transition to `progress >= target`; later calls leave it untouched.
- All date columns store a date normalised to midnight local (`dayOf`) so the `(date, type)` uniqueness behaves.

```dart
// lib/data/db/nouri_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';
export 'tables.dart';

part 'nouri_database.g.dart';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

@DriftDatabase(tables: [SettingsRows, PrayerLogs, AthkarLogs, QuranLogs])
class NouriDatabase extends _$NouriDatabase {
  NouriDatabase() : super(_open());
  NouriDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  SettingsDao get settingsDao => SettingsDao(this);
  PrayerDao get prayerDao => PrayerDao(this);
  AthkarDao get athkarDao => AthkarDao(this);
  QuranDao get quranDao => QuranDao(this);

  static QueryExecutor _open() => LazyDatabase(() async {
        final dir = await getApplicationDocumentsDirectory();
        return NativeDatabase.createInBackground(File(p.join(dir.path, 'nouri.sqlite')));
      });
}
```

`AthkarDao.upsert` in full, since its completion rule is subtle:

```dart
// lib/data/db/athkar_dao.dart
import 'package:drift/drift.dart';
import 'nouri_database.dart';

class AthkarDao {
  AthkarDao(this._db);
  final NouriDatabase _db;

  Future<void> upsert({
    required DateTime date,
    required String type,
    required int progress,
    required int target,
  }) async {
    final day = dayOf(date);
    final existing = await (_db.select(_db.athkarLogs)
          ..where((t) => t.date.equals(day) & t.type.equals(type)))
        .getSingleOrNull();

    // completedAt is stamped once, on the first crossing of the target, and
    // never moves again — extra taps past the target must not shift it.
    final completedAt = existing?.completedAt ??
        (progress >= target ? DateTime.now() : null);

    await _db.into(_db.athkarLogs).insertOnConflictUpdate(
          AthkarLogsCompanion.insert(
            date: day,
            type: type,
            targetCount: target,
            progressCount: Value(progress),
            completedAt: Value(completedAt),
          ),
        );
  }
}
```

- [ ] **Step 6: Generate the drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/data/db/nouri_database.g.dart` created with no errors.

- [ ] **Step 7: Run the database test**

Run: `flutter test test/data/db/nouri_database_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 8: Write the no-network guard test**

```dart
// test/guard/no_network_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Slice 1 is entirely offline. This test is the enforcement, not a comment.
void main() {
  const banned = ['http:', 'dio:', 'anthropic', 'web_socket_channel', 'grpc'];

  test('pubspec declares no network dependency', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final dep in banned) {
      expect(pubspec.contains(dep), isFalse,
          reason: 'Slice 1 must stay offline: $dep');
    }
  });

  test('no source file reaches the network', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('package:http/') ||
          src.contains('HttpClient(') ||
          src.contains('api.anthropic.com')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty, reason: 'network access found in: $offenders');
  });
}
```

- [ ] **Step 9: Run it**

Run: `flutter test test/guard/no_network_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: add drift database, DAOs, prayer scoring, and offline guard test"
```

---

## Task 5: Prayer times and Hijri dates

**Files:**
- Create: `lib/core/time/geo_config.dart`, `lib/core/time/prayer_times_service.dart`, `lib/core/time/hijri_date.dart`
- Modify: `pubspec.yaml`
- Test: `test/core/time/prayer_times_service_test.dart`, `test/core/time/hijri_date_test.dart`

**Interfaces:**
- Consumes: settings from Task 4
- Produces: `GeoConfig(latitude, longitude, method, madhab)` with `GeoConfig.kuwaitCity`; `DailyPrayerTimes` with `fajr, sunrise, dhuhr, asr, maghrib, isha`, `List<PrayerSlot> ordered`, `PrayerSlot? next(DateTime)`; `PrayerSlot(name, time)`; `PrayerTimesService.forDate(DateTime, GeoConfig)`; `iqamaFor(PrayerSlot, Map<String,int>)`; `hijriFor(DateTime, {int offsetDays})` returning `HijriDate(day, monthName, year, formatted)`

- [ ] **Step 1: Add dependencies**

```yaml
dependencies:
  adhan: ^2.0.0
  hijri: ^3.0.0
```

Run: `flutter pub get`

- [ ] **Step 2: Write the failing prayer-times test**

Assertions are ranges, not exact minutes — they catch a wrong method, wrong coordinates, wrong timezone or a swapped prayer, without turning a one-minute library refinement into a false failure.

```dart
// test/core/time/prayer_times_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';

/// Kuwait is UTC+3 year-round with no DST. The test machine may be in any
/// zone (this one is Egypt, which is +02:00 in winter and +03:00 in summer),
/// and `adhan` returns times in the *runner's* local zone — so asserting on a
/// raw `.hour` would make these tests pass or fail depending on where they run.
/// Converting to Kuwait wall-clock first makes the assertions absolute.
const _kuwaitOffset = Duration(hours: 3);
DateTime kw(DateTime t) => t.toUtc().add(_kuwaitOffset);

void main() {
  const kuwait = GeoConfig(
      latitude: 29.3759, longitude: 47.9774, method: 'kuwait', madhab: 'shafi');
  final service = PrayerTimesService();

  test('prayers are strictly ordered through the day', () {
    for (final d in [DateTime(2026, 1, 15), DateTime(2026, 6, 21), DateTime(2026, 12, 31)]) {
      final t = service.forDate(d, kuwait);
      expect(t.fajr.isBefore(t.sunrise), isTrue, reason: '$d');
      expect(t.sunrise.isBefore(t.dhuhr), isTrue, reason: '$d');
      expect(t.dhuhr.isBefore(t.asr), isTrue, reason: '$d');
      expect(t.asr.isBefore(t.maghrib), isTrue, reason: '$d');
      expect(t.maghrib.isBefore(t.isha), isTrue, reason: '$d');
    }
  });

  test('every prayer falls on the requested calendar day in Kuwait', () {
    final d = DateTime(2026, 9, 5);
    final t = service.forDate(d, kuwait);
    for (final slot in t.ordered) {
      final local = kw(slot.time);
      expect(local.year, d.year, reason: slot.name);
      expect(local.month, d.month, reason: slot.name);
      expect(local.day, d.day, reason: slot.name);
    }
  });

  test('midsummer Kuwait times land in the expected windows', () {
    final t = service.forDate(DateTime(2026, 6, 21), kuwait);
    expect(kw(t.fajr).hour, inInclusiveRange(2, 4));
    expect(kw(t.dhuhr).hour, inInclusiveRange(11, 12));
    expect(kw(t.maghrib).hour, inInclusiveRange(18, 19));
    expect(kw(t.isha).hour, inInclusiveRange(19, 21));
  });

  test('midwinter Kuwait times shift later in the morning', () {
    final t = service.forDate(DateTime(2026, 12, 21), kuwait);
    expect(kw(t.fajr).hour, inInclusiveRange(4, 6));
    expect(kw(t.maghrib).hour, inInclusiveRange(16, 17));
  });

  test('the same instant is returned regardless of the runner timezone', () {
    // Guards the fix above: the absolute instant must not depend on local zone.
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    expect(t.dhuhr.toUtc().hour, inInclusiveRange(8, 9),
        reason: 'Kuwait dhuhr is around 11:50 local = 08:50 UTC');
  });

  test('next() returns the upcoming prayer, and null after isha', () {
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    expect(t.next(t.asr.subtract(const Duration(minutes: 1)))!.name, 'asr');
    expect(t.next(t.isha.add(const Duration(minutes: 1))), isNull);
  });

  test('ordered excludes sunrise — it is not a prayer to log', () {
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    expect(t.ordered.map((s) => s.name).toList(),
        ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']);
  });

  test('iqama adds the configured offset per prayer', () {
    final t = service.forDate(DateTime(2026, 9, 5), kuwait);
    const offsets = {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 10, 'isha': 15};
    final asr = t.ordered.firstWhere((s) => s.name == 'asr');
    expect(iqamaFor(asr, offsets).difference(asr.time), const Duration(minutes: 15));
    final maghrib = t.ordered.firstWhere((s) => s.name == 'maghrib');
    expect(iqamaFor(maghrib, offsets).difference(maghrib.time), const Duration(minutes: 10));
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/core/time/prayer_times_service_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 4: Implement the service**

```dart
// lib/core/time/geo_config.dart
class GeoConfig {
  const GeoConfig({
    required this.latitude,
    required this.longitude,
    required this.method,
    required this.madhab,
  });
  final double latitude;
  final double longitude;
  final String method;   // kuwait | ummAlQura | muslimWorldLeague | egyptian | qatar | dubai
  final String madhab;   // shafi | hanafi

  /// Used before any location permission is granted. Nouri is never blocked
  /// on a permission — location only improves accuracy.
  static const kuwaitCity = GeoConfig(
      latitude: 29.3759, longitude: 47.9774, method: 'kuwait', madhab: 'shafi');
}
```

```dart
// lib/core/time/prayer_times_service.dart
import 'package:adhan/adhan.dart' as adhan;
import 'geo_config.dart';

class PrayerSlot {
  const PrayerSlot(this.name, this.time);
  final String name;      // fajr | dhuhr | asr | maghrib | isha
  final DateTime time;
}

class DailyPrayerTimes {
  DailyPrayerTimes({
    required this.fajr, required this.sunrise, required this.dhuhr,
    required this.asr, required this.maghrib, required this.isha,
  });
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;

  /// Sunrise is deliberately absent: it is not a prayer the user logs.
  List<PrayerSlot> get ordered => [
        PrayerSlot('fajr', fajr),
        PrayerSlot('dhuhr', dhuhr),
        PrayerSlot('asr', asr),
        PrayerSlot('maghrib', maghrib),
        PrayerSlot('isha', isha),
      ];

  PrayerSlot? next(DateTime now) {
    for (final s in ordered) {
      if (s.time.isAfter(now)) return s;
    }
    return null;
  }
}

class PrayerTimesService {
  DailyPrayerTimes forDate(DateTime date, GeoConfig cfg) {
    final params = _method(cfg.method).getParameters()
      ..madhab = cfg.madhab == 'hanafi' ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    final t = adhan.PrayerTimes(
      adhan.Coordinates(cfg.latitude, cfg.longitude),
      adhan.DateComponents(date.year, date.month, date.day),
      params,
    );
    return DailyPrayerTimes(
      fajr: t.fajr, sunrise: t.sunrise, dhuhr: t.dhuhr,
      asr: t.asr, maghrib: t.maghrib, isha: t.isha,
    );
  }

  adhan.CalculationMethod _method(String key) => switch (key) {
        'ummAlQura' => adhan.CalculationMethod.umm_al_qura,
        'muslimWorldLeague' => adhan.CalculationMethod.muslim_world_league,
        'egyptian' => adhan.CalculationMethod.egyptian,
        'qatar' => adhan.CalculationMethod.qatar,
        'dubai' => adhan.CalculationMethod.dubai,
        _ => adhan.CalculationMethod.kuwait,
      };
}

DateTime iqamaFor(PrayerSlot slot, Map<String, int> offsetsMinutes) =>
    slot.time.add(Duration(minutes: offsetsMinutes[slot.name] ?? 15));
```

- [ ] **Step 5: Run the prayer-times test**

Run: `flutter test test/core/time/prayer_times_service_test.dart`
Expected: PASS (8 tests)

The `kw()` helper is what makes these assertions machine-independent. This development machine runs on Egypt time (UTC+2, +03:00 under DST), so asserting on a raw local `.hour` would pass in summer and fail in December. Never compare a prayer hour without converting to Kuwait wall-clock first.

- [ ] **Step 6: Write the failing Hijri test**

```dart
// test/core/time/hijri_date_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/hijri_date.dart';

void main() {
  test('converts a Gregorian date to Hijri', () {
    final h = hijriFor(DateTime(2026, 9, 5));
    expect(h.year, inInclusiveRange(1447, 1448));
    expect(h.day, inInclusiveRange(1, 30));
    expect(h.monthName, isNotEmpty);
  });

  test('a positive offset moves the Hijri date forward', () {
    final base = hijriFor(DateTime(2026, 9, 5));
    final plus = hijriFor(DateTime(2026, 9, 5), offsetDays: 1);
    expect(plus.day == base.day + 1 || plus.day == 1, isTrue,
        reason: 'either the next day, or the first of the next month');
  });

  test('a negative offset moves it backward', () {
    final base = hijriFor(DateTime(2026, 9, 5));
    final minus = hijriFor(DateTime(2026, 9, 5), offsetDays: -1);
    expect(minus.day == base.day - 1 || minus.day >= 29, isTrue);
  });

  test('formatted string carries Arabic-Indic digits only', () {
    expect(RegExp(r'[0-9]').hasMatch(hijriFor(DateTime(2026, 9, 5)).formatted), isFalse);
  });
}
```

- [ ] **Step 7: Implement the Hijri helper**

```dart
// lib/core/time/hijri_date.dart
import 'package:hijri/hijri_calendar.dart';
import '../format/arabic_numerals.dart';

class HijriDate {
  const HijriDate({
    required this.day, required this.monthName,
    required this.year, required this.formatted,
  });
  final int day;
  final String monthName;
  final int year;
  final String formatted;   // e.g. ١٢ صفر ١٤٤٧ هـ
}

/// The civil Hijri calculation can differ from local moon sighting by a day,
/// so the user can nudge it in Settings.
HijriDate hijriFor(DateTime gregorian, {int offsetDays = 0}) {
  final h = HijriCalendar.fromDate(gregorian.add(Duration(days: offsetDays)));
  return HijriDate(
    day: h.hDay,
    monthName: h.longMonthName,
    year: h.hYear,
    formatted: toArabicDigits('${h.hDay} ${h.longMonthName} ${h.hYear} هـ'),
  );
}
```

- [ ] **Step 8: Run the Hijri test**

Run: `flutter test test/core/time/hijri_date_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add prayer-time computation, iqama offsets, and Hijri dates"
```

---

## Task 6: Notification slots and deterministic IDs

The whole reliability strategy rests on IDs being reproducible: re-arming must be
able to overwrite the exact alarm it wrote yesterday, from a cold start, with no
stored state.

**Files:**
- Create: `lib/core/notifications/notification_slot.dart`, `lib/core/notifications/notification_gateway.dart`
- Test: `test/core/notifications/notification_slot_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `NotificationSlot` enum; `notificationIdFor(DateTime date, NotificationSlot slot)`; `ScheduledNotification(id, slot, when, title, body, channelId, payload)`; the abstract `NotificationGateway` with `cancelAll()`, `schedule(ScheduledNotification)`, `pendingIds()`, `showNow(...)`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/notifications/notification_slot_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_slot.dart';

void main() {
  test('there are fewer slots than the per-day stride', () {
    expect(NotificationSlot.values.length, lessThan(kSlotsPerDay));
  });

  test('IDs are unique across a full year and every slot', () {
    final seen = <int>{};
    var day = DateTime(2026, 1, 1);
    for (var i = 0; i < 365; i++) {
      for (final slot in NotificationSlot.values) {
        final id = notificationIdFor(day, slot);
        expect(seen.add(id), isTrue, reason: 'collision on $day / $slot');
      }
      day = day.add(const Duration(days: 1));
    }
  });

  test('the same date and slot always produce the same ID', () {
    final a = notificationIdFor(DateTime(2026, 9, 5), NotificationSlot.adhanAsr);
    final b = notificationIdFor(DateTime(2026, 9, 5, 23, 59), NotificationSlot.adhanAsr);
    expect(a, b, reason: 'time of day must not affect the ID');
  });

  test('IDs stay inside the 32-bit range Android accepts', () {
    final id = notificationIdFor(DateTime(2035, 12, 31), NotificationSlot.sleepAthkar);
    expect(id, greaterThan(0));
    expect(id, lessThan(2147483647));
  });

  test('every prayer has an adhan, an iqama and a follow-up slot', () {
    for (final p in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      expect(NotificationSlot.values.any((s) => s.name == 'adhan$p'), isTrue);
      expect(NotificationSlot.values.any((s) => s.name == 'iqama$p'), isTrue);
      expect(NotificationSlot.values.any((s) => s.name == 'followUp$p'), isTrue);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/notifications/notification_slot_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement slots and IDs**

```dart
// lib/core/notifications/notification_slot.dart

/// Stride between days in the ID space. Must exceed the slot count so
/// `day * stride + slot` can never collide.
const kSlotsPerDay = 32;

/// The ID epoch. Never change this — it would orphan every alarm already
/// scheduled on the user's device.
final _idEpoch = DateTime.utc(2020, 1, 1);

enum NotificationSlot {
  adhanFajr, iqamaFajr, followUpFajr,
  adhanDhuhr, iqamaDhuhr, followUpDhuhr,
  adhanAsr, iqamaAsr, followUpAsr,
  adhanMaghrib, iqamaMaghrib, followUpMaghrib,
  adhanIsha, iqamaIsha, followUpIsha,
  morningAthkar, eveningAthkar, sleepAthkar,
  quranWird,
}

/// Reproducible from the date alone: re-arming after a reboot lands on exactly
/// the same IDs, so alarms are overwritten rather than duplicated.
int notificationIdFor(DateTime date, NotificationSlot slot) {
  final days = DateTime.utc(date.year, date.month, date.day)
      .difference(_idEpoch)
      .inDays;
  return days * kSlotsPerDay + slot.index;
}

class ScheduledNotification {
  const ScheduledNotification({
    required this.id,
    required this.slot,
    required this.when,
    required this.title,
    required this.body,
    required this.channelId,
    this.payload,
  });
  final int id;
  final NotificationSlot slot;
  final DateTime when;
  final String title;
  final String body;
  final String channelId;
  final String? payload;
}
```

```dart
// lib/core/notifications/notification_gateway.dart
import 'notification_slot.dart';

/// The seam that makes scheduling testable. Production uses
/// LocalNotificationGateway; tests use a fake that records calls.
abstract class NotificationGateway {
  Future<void> cancelAll();
  Future<void> schedule(ScheduledNotification n);
  Future<List<int>> pendingIds();
  Future<void> showNow({required String title, required String body, required String channelId});
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/notifications/notification_slot_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add notification slots with deterministic, reproducible IDs"
```

---

## Task 7: The rolling 7-day window

**Files:**
- Create: `lib/core/notifications/rolling_window_scheduler.dart`
- Test: `test/core/notifications/rolling_window_scheduler_test.dart`, `test/support/fake_notification_gateway.dart`

**Interfaces:**
- Consumes: `NotificationGateway`, `notificationIdFor` (Task 6); `PrayerTimesService`, `iqamaFor`, `GeoConfig` (Task 5)
- Produces: `SchedulingConfig(geo, iqamaOffsets, notifyAdhan, notifyIqama, notifyAthkar, notifyWird, athkarTimes)`; `RollingWindowScheduler(gateway:, prayerTimes:, clock:)` with `Future<void> rearm(SchedulingConfig)`; `const kWindowDays = 7`

- [ ] **Step 1: Write the fake gateway**

```dart
// test/support/fake_notification_gateway.dart
import 'package:nouri/core/notifications/notification_gateway.dart';
import 'package:nouri/core/notifications/notification_slot.dart';

class FakeNotificationGateway implements NotificationGateway {
  final List<ScheduledNotification> scheduled = [];
  int cancelAllCount = 0;
  final List<String> shown = [];

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(ScheduledNotification n) async => scheduled.add(n);

  @override
  Future<List<int>> pendingIds() async => scheduled.map((n) => n.id).toList();

  @override
  Future<void> showNow({
    required String title,
    required String body,
    required String channelId,
  }) async =>
      shown.add(title);

  Iterable<ScheduledNotification> ofSlot(NotificationSlot s) =>
      scheduled.where((n) => n.slot == s);
}
```

- [ ] **Step 2: Write the failing scheduler test**

```dart
// test/core/notifications/rolling_window_scheduler_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/core/notifications/rolling_window_scheduler.dart';
import 'package:nouri/core/time/geo_config.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import '../../support/fake_notification_gateway.dart';

void main() {
  late FakeNotificationGateway gateway;
  late RollingWindowScheduler scheduler;

  // A fixed "now": 2026-09-05, 06:00 local — after fajr, before dhuhr.
  final now = DateTime(2026, 9, 5, 6, 0);

  const config = SchedulingConfig(
    geo: GeoConfig.kuwaitCity,
    iqamaOffsets: {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 10, 'isha': 15},
  );

  setUp(() {
    gateway = FakeNotificationGateway();
    scheduler = RollingWindowScheduler(
      gateway: gateway,
      prayerTimes: PrayerTimesService(),
      clock: () => now,
    );
  });

  test('schedules a full seven-day window', () async {
    await scheduler.rearm(config);
    final days = gateway.scheduled
        .map((n) => DateTime(n.when.year, n.when.month, n.when.day))
        .toSet();
    expect(days.length, kWindowDays);
  });

  test('never schedules anything in the past', () async {
    await scheduler.rearm(config);
    for (final n in gateway.scheduled) {
      expect(n.when.isAfter(now), isTrue,
          reason: '${n.slot} at ${n.when} is behind now');
    }
  });

  test('today already-passed prayers are skipped, not backdated', () async {
    await scheduler.rearm(config);
    final todayFajr = gateway.ofSlot(NotificationSlot.adhanFajr)
        .where((n) => n.when.day == 5 && n.when.month == 9);
    expect(todayFajr, isEmpty, reason: 'fajr passed before 06:00');

    final todayDhuhr = gateway.ofSlot(NotificationSlot.adhanDhuhr)
        .where((n) => n.when.day == 5 && n.when.month == 9);
    expect(todayDhuhr, hasLength(1), reason: 'dhuhr is still ahead');
  });

  test('re-arming is idempotent — the same IDs, never duplicates', () async {
    await scheduler.rearm(config);
    final first = (await gateway.pendingIds())..sort();

    await scheduler.rearm(config);
    final second = (await gateway.pendingIds())..sort();

    expect(second, equals(first));
    expect(second.toSet().length, second.length, reason: 'duplicate IDs');
    expect(gateway.cancelAllCount, 2, reason: 'each rearm clears first');
  });

  test('iqama fires exactly the configured offset after the adhan', () async {
    await scheduler.rearm(config);
    final adhan = gateway.ofSlot(NotificationSlot.adhanAsr).first;
    final iqama = gateway
        .ofSlot(NotificationSlot.iqamaAsr)
        .firstWhere((n) => n.when.day == adhan.when.day);
    expect(iqama.when.difference(adhan.when), const Duration(minutes: 15));
  });

  test('disabling iqama removes only iqama notifications', () async {
    await scheduler.rearm(config.copyWith(notifyIqama: false));
    expect(gateway.ofSlot(NotificationSlot.iqamaAsr), isEmpty);
    expect(gateway.ofSlot(NotificationSlot.adhanAsr), isNotEmpty);
  });

  test('disabling adhan still leaves the athkar and wird reminders', () async {
    await scheduler.rearm(config.copyWith(notifyAdhan: false));
    expect(gateway.ofSlot(NotificationSlot.adhanFajr), isEmpty);
    expect(gateway.ofSlot(NotificationSlot.morningAthkar), isNotEmpty);
    expect(gateway.ofSlot(NotificationSlot.quranWird), isNotEmpty);
  });

  test('changing the iqama offset moves the iqama and nothing else', () async {
    await scheduler.rearm(config);
    final before = gateway.ofSlot(NotificationSlot.iqamaMaghrib).first.when;
    final adhanBefore = gateway.ofSlot(NotificationSlot.adhanMaghrib).first.when;

    await scheduler.rearm(config.copyWith(
        iqamaOffsets: {'fajr': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 25, 'isha': 15}));
    final after = gateway.ofSlot(NotificationSlot.iqamaMaghrib).first.when;
    final adhanAfter = gateway.ofSlot(NotificationSlot.adhanMaghrib).first.when;

    expect(after.difference(before), const Duration(minutes: 15));
    expect(adhanAfter, adhanBefore);
  });

  test('every scheduled notification carries a channel and a title', () async {
    await scheduler.rearm(config);
    for (final n in gateway.scheduled) {
      expect(n.channelId, isNotEmpty);
      expect(n.title, isNotEmpty);
    }
  });

  test('no notification copy contains a punishing word', () async {
    await scheduler.rearm(config);
    const forbidden = ['فاتتك', 'ضيعت', 'فشل', 'missed', 'failed'];
    for (final n in gateway.scheduled) {
      for (final w in forbidden) {
        expect(n.title.contains(w), isFalse, reason: 'title: ${n.title}');
        expect(n.body.contains(w), isFalse, reason: 'body: ${n.body}');
      }
    }
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/core/notifications/rolling_window_scheduler_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 4: Implement the scheduler**

```dart
// lib/core/notifications/rolling_window_scheduler.dart
import '../time/geo_config.dart';
import '../time/prayer_times_service.dart';
import 'notification_gateway.dart';
import 'notification_slot.dart';

const kWindowDays = 7;

class SchedulingConfig {
  const SchedulingConfig({
    required this.geo,
    required this.iqamaOffsets,
    this.notifyAdhan = true,
    this.notifyIqama = true,
    this.notifyAthkar = true,
    this.notifyWird = true,
    this.morningAthkarHour = 7,
    this.sleepAthkarHour = 22,
    this.quranWirdHour = 17,
  });

  final GeoConfig geo;
  final Map<String, int> iqamaOffsets;
  final bool notifyAdhan, notifyIqama, notifyAthkar, notifyWird;
  final int morningAthkarHour, sleepAthkarHour, quranWirdHour;

  SchedulingConfig copyWith({
    GeoConfig? geo,
    Map<String, int>? iqamaOffsets,
    bool? notifyAdhan,
    bool? notifyIqama,
    bool? notifyAthkar,
    bool? notifyWird,
  }) =>
      SchedulingConfig(
        geo: geo ?? this.geo,
        iqamaOffsets: iqamaOffsets ?? this.iqamaOffsets,
        notifyAdhan: notifyAdhan ?? this.notifyAdhan,
        notifyIqama: notifyIqama ?? this.notifyIqama,
        notifyAthkar: notifyAthkar ?? this.notifyAthkar,
        notifyWird: notifyWird ?? this.notifyWird,
      );
}

/// Rebuilds the entire 7-day alarm window from scratch on every call.
/// Cheap (about 100 alarms), and it makes re-arming trivially correct: there is
/// no incremental state to get wrong after a reboot or a settings change.
class RollingWindowScheduler {
  RollingWindowScheduler({
    required this.gateway,
    required this.prayerTimes,
    required this.clock,
  });

  final NotificationGateway gateway;
  final PrayerTimesService prayerTimes;
  final DateTime Function() clock;

  static const _adhanSlots = {
    'fajr': NotificationSlot.adhanFajr,
    'dhuhr': NotificationSlot.adhanDhuhr,
    'asr': NotificationSlot.adhanAsr,
    'maghrib': NotificationSlot.adhanMaghrib,
    'isha': NotificationSlot.adhanIsha,
  };
  static const _iqamaSlots = {
    'fajr': NotificationSlot.iqamaFajr,
    'dhuhr': NotificationSlot.iqamaDhuhr,
    'asr': NotificationSlot.iqamaAsr,
    'maghrib': NotificationSlot.iqamaMaghrib,
    'isha': NotificationSlot.iqamaIsha,
  };
  static const _followUpSlots = {
    'fajr': NotificationSlot.followUpFajr,
    'dhuhr': NotificationSlot.followUpDhuhr,
    'asr': NotificationSlot.followUpAsr,
    'maghrib': NotificationSlot.followUpMaghrib,
    'isha': NotificationSlot.followUpIsha,
  };
  static const _arabicNames = {
    'fajr': 'الفجر', 'dhuhr': 'الظهر', 'asr': 'العصر',
    'maghrib': 'المغرب', 'isha': 'العشاء',
  };

  Future<void> rearm(SchedulingConfig cfg) async {
    await gateway.cancelAll();
    final now = clock();
    final today = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < kWindowDays; i++) {
      final date = today.add(Duration(days: i));
      final times = prayerTimes.forDate(date, cfg.geo);

      for (final slot in times.ordered) {
        final name = _arabicNames[slot.name]!;

        if (cfg.notifyAdhan) {
          await _put(date, _adhanSlots[slot.name]!, slot.time, now,
              title: name, body: 'حان الآن موعد صلاة $name', channel: 'adhan_v1',
              payload: 'prayer:${slot.name}');
        }
        if (cfg.notifyIqama) {
          await _put(date, _iqamaSlots[slot.name]!,
              iqamaFor(slot, cfg.iqamaOffsets), now,
              title: 'الإقامة', body: 'إقامة صلاة $name', channel: 'iqama_v1',
              payload: 'prayer:${slot.name}');
        }
        if (cfg.notifyAdhan) {
          // The gentle follow-up, 25 minutes after the adhan. Colloquial,
          // a question, never an accusation.
          await _put(date, _followUpSlots[slot.name]!,
              slot.time.add(const Duration(minutes: 25)), now,
              title: 'نوري', body: 'صليت $name؟', channel: 'general_v1',
              payload: 'log:${slot.name}');
        }
      }

      if (cfg.notifyAthkar) {
        await _put(date, NotificationSlot.morningAthkar,
            _at(date, cfg.morningAthkarHour), now,
            title: 'أذكار الصباح', body: 'وقت أذكار الصباح — خمس دقايق بس',
            channel: 'athkar_v1', payload: 'athkar:morning');

        // Evening athkar ride on maghrib rather than a fixed clock hour.
        await _put(date, NotificationSlot.eveningAthkar,
            times.maghrib.subtract(const Duration(minutes: 45)), now,
            title: 'أذكار المساء', body: 'قرب المغرب — وقت أذكار المسا',
            channel: 'athkar_v1', payload: 'athkar:evening');

        await _put(date, NotificationSlot.sleepAthkar,
            _at(date, cfg.sleepAthkarHour), now,
            title: 'أذكار النوم', body: 'قبل ما تنام، خد أذكار النوم',
            channel: 'athkar_v1', payload: 'athkar:sleep');
      }

      if (cfg.notifyWird) {
        await _put(date, NotificationSlot.quranWird, _at(date, cfg.quranWirdHour), now,
            title: 'ورد القرآن', body: 'ورد النهاردة — ربع من مصحفك',
            channel: 'wird_v1', payload: 'quran');
      }
    }
  }

  DateTime _at(DateTime date, int hour) =>
      DateTime(date.year, date.month, date.day, hour);

  Future<void> _put(
    DateTime date,
    NotificationSlot slot,
    DateTime when,
    DateTime now, {
    required String title,
    required String body,
    required String channel,
    String? payload,
  }) async {
    if (!when.isAfter(now)) return; // never schedule into the past
    await gateway.schedule(ScheduledNotification(
      id: notificationIdFor(date, slot),
      slot: slot,
      when: when,
      title: title,
      body: body,
      channelId: channel,
      payload: payload,
    ));
  }
}
```

- [ ] **Step 5: Run the scheduler test**

Run: `flutter test test/core/notifications/rolling_window_scheduler_test.dart`
Expected: PASS (10 tests)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add the rolling 7-day notification window with idempotent re-arm"
```

---

## Task 8: Android notifications — channels, permissions, status, fallback

This task turns the tested scheduler into something that actually rings, and
implements the five reliability requirements from the spec.

**Files:**
- Create: `lib/core/notifications/notification_channels.dart`, `lib/core/notifications/local_notification_gateway.dart`, `lib/core/notifications/notification_status.dart`, `lib/core/notifications/rearm_triggers.dart`
- Create: `assets/audio/chime.ogg`
- Modify: `android/app/src/main/AndroidManifest.xml`, `pubspec.yaml`, `lib/main.dart`
- Test: `test/core/notifications/notification_status_test.dart`

**Interfaces:**
- Consumes: `NotificationGateway`, `ScheduledNotification` (Task 6); `RollingWindowScheduler` (Task 7)
- Produces: `LocalNotificationGateway` (implements `NotificationGateway`); `NotificationStatus(notificationsEnabled, exactAlarmsAllowed, batteryOptimised, mode)` and `NotificationMode { exact, inexact }`; `NotificationStatusService.read()`; `RearmTriggers.installAll()`; `sendTestNotification()`

- [ ] **Step 1: Add dependencies**

```yaml
dependencies:
  flutter_local_notifications: ^17.2.3
  timezone: ^0.9.4
  flutter_timezone: ^3.0.1
  permission_handler: ^11.3.1
  workmanager: ^0.5.2
```

Run: `flutter pub get`

- [ ] **Step 2: Create the chime asset**

Generate a short, calm two-tone chime (no speech, no music) as `assets/audio/chime.ogg`, about 2 seconds. Any offline tone generator is fine — this file must not be downloaded from an arbitrary web source. Copy it to `android/app/src/main/res/raw/chime.ogg` as well; Android channel sounds are resolved from `res/raw`, not from Flutter assets.

Record in `docs/setup.md`: dropping a `takbir.mp3` or `adhan.mp3` into `android/app/src/main/res/raw/` and bumping the channel ID to `adhan_v2` is all that is needed to swap the sound later.

- [ ] **Step 3: Declare the manifest permissions**

In `android/app/src/main/AndroidManifest.xml`, above `<application>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>
```

and inside `<application>`, the plugin's boot receiver:

```xml
<receiver android:exported="false"
    android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
  </intent-filter>
</receiver>
```

- [ ] **Step 4: Define the five channels**

```dart
// lib/core/notifications/notification_channels.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Channel IDs are versioned because Android freezes a channel's sound at
/// creation. Swapping the adhan sound means creating `adhan_v2` and deleting
/// `adhan_v1` — never mutating one in place.
const channelAdhan = 'adhan_v1';
const channelIqama = 'iqama_v1';
const channelAthkar = 'athkar_v1';
const channelWird = 'wird_v1';
const channelGeneral = 'general_v1';

const nouriChannels = <AndroidNotificationChannel>[
  AndroidNotificationChannel(
    channelAdhan, 'الأذان',
    description: 'إشعار دخول وقت الصلاة',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('chime'),
    playSound: true,
  ),
  AndroidNotificationChannel(
    channelIqama, 'الإقامة',
    description: 'تنبيه قبل الإقامة',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    channelAthkar, 'الأذكار',
    description: 'تذكير أذكار الصباح والمساء والنوم',
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    channelWird, 'ورد القرآن',
    description: 'تذكير الورد اليومي',
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    channelGeneral, 'نوري',
    description: 'متابعة نوري اليومية',
    importance: Importance.defaultImportance,
  ),
];
```

- [ ] **Step 5: Implement the real gateway with the exact-alarm fallback**

```dart
// lib/core/notifications/local_notification_gateway.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'notification_channels.dart';
import 'notification_gateway.dart';
import 'notification_slot.dart';

enum NotificationMode { exact, inexact }

class LocalNotificationGateway implements NotificationGateway {
  LocalNotificationGateway(this._plugin, {required this.mode});

  final FlutterLocalNotificationsPlugin _plugin;

  /// Falls back to [NotificationMode.inexact] when the platform refuses exact
  /// alarms. The user is told plainly in the status panel — Nouri never claims
  /// a reliability it does not have.
  final NotificationMode mode;

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> schedule(ScheduledNotification n) => _plugin.zonedSchedule(
        n.id,
        n.title,
        n.body,
        tz.TZDateTime.from(n.when, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            n.channelId,
            n.channelId,
            category: n.channelId == channelAdhan
                ? AndroidNotificationCategory.alarm
                : AndroidNotificationCategory.reminder,
            actions: n.payload != null && n.payload!.startsWith('log:')
                ? const [AndroidNotificationAction('logged', 'صليت')]
                : null,
          ),
        ),
        androidScheduleMode: mode == NotificationMode.exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: n.payload,
      );

  @override
  Future<List<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests()).map((r) => r.id).toList();

  @override
  Future<void> showNow({
    required String title,
    required String body,
    required String channelId,
  }) =>
      _plugin.show(0, title, body,
          NotificationDetails(android: AndroidNotificationDetails(channelId, channelId)));
}
```

- [ ] **Step 6: Write the status test**

```dart
// test/core/notifications/notification_status_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_status.dart';

void main() {
  test('everything granted reads as fully reliable', () {
    const s = NotificationStatus(
        notificationsEnabled: true, exactAlarmsAllowed: true, batteryOptimised: false);
    expect(s.mode, NotificationMode.exact);
    expect(s.isFullyReliable, isTrue);
    expect(s.warnings, isEmpty);
  });

  test('no exact alarms degrades the mode and says so', () {
    const s = NotificationStatus(
        notificationsEnabled: true, exactAlarmsAllowed: false, batteryOptimised: false);
    expect(s.mode, NotificationMode.inexact);
    expect(s.isFullyReliable, isFalse);
    expect(s.warnings, contains(NotificationWarning.exactAlarmsUnavailable));
  });

  test('battery optimisation is reported even when everything else is granted', () {
    const s = NotificationStatus(
        notificationsEnabled: true, exactAlarmsAllowed: true, batteryOptimised: true);
    expect(s.warnings, contains(NotificationWarning.batteryOptimised));
    expect(s.isFullyReliable, isFalse);
  });

  test('notifications disabled is the most severe warning and comes first', () {
    const s = NotificationStatus(
        notificationsEnabled: false, exactAlarmsAllowed: false, batteryOptimised: true);
    expect(s.warnings.first, NotificationWarning.notificationsDisabled);
  });
}
```

- [ ] **Step 7: Implement the status model**

```dart
// lib/core/notifications/notification_status.dart
import 'local_notification_gateway.dart' show NotificationMode;
export 'local_notification_gateway.dart' show NotificationMode;

enum NotificationWarning { notificationsDisabled, exactAlarmsUnavailable, batteryOptimised }

class NotificationStatus {
  const NotificationStatus({
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    required this.batteryOptimised,
  });

  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final bool batteryOptimised;

  NotificationMode get mode =>
      exactAlarmsAllowed ? NotificationMode.exact : NotificationMode.inexact;

  bool get isFullyReliable => warnings.isEmpty;

  /// Ordered most to least severe, so the UI can lead with what matters.
  List<NotificationWarning> get warnings => [
        if (!notificationsEnabled) NotificationWarning.notificationsDisabled,
        if (!exactAlarmsAllowed) NotificationWarning.exactAlarmsUnavailable,
        if (batteryOptimised) NotificationWarning.batteryOptimised,
      ];
}
```

- [ ] **Step 8: Run the status test**

Run: `flutter test test/core/notifications/notification_status_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 9: Wire the three re-arm triggers**

```dart
// lib/core/notifications/rearm_triggers.dart — behaviour required:
// 1. App resume  — a WidgetsBindingObserver calling scheduler.rearm on
//                  AppLifecycleState.resumed.
// 2. Device boot — the manifest receiver from Step 3 restores the alarms the
//                  plugin persisted; the next app launch re-arms the full window.
// 3. Daily top-up — Workmanager().registerPeriodicTask with a 24-hour frequency
//                  that opens the DB, reads settings, and calls rearm.
```

In `lib/main.dart`, before `runApp`: initialise timezone (`tz.initializeTimeZones()` then `tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()))`), create the five channels, read the notification status, construct the gateway with the resulting mode, and call `rearm` once.

- [ ] **Step 10: Verify on a real device**

Connect the phone (`adb devices` must list it), then `flutter run`. Confirm: the app launches, five channels appear under Android's app notification settings, and «Send test notification» (added in Task 17) fires. Set a prayer time a few minutes ahead by temporarily changing the device clock, and confirm the adhan notification arrives with the app swiped away.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: add notification channels, exact-alarm fallback, status model, and re-arm triggers"
```

---

## Task 9: App shell, router and the Finance placeholder

**Files:**
- Create: `lib/core/router/app_router.dart`, `lib/features/shell/app_shell.dart`, `lib/features/finance/finance_placeholder.dart`
- Create: stub screens `lib/features/home/home_screen.dart`, `lib/features/athkar/athkar_screen.dart`, `lib/features/reports/reports_screen.dart`, `lib/features/settings/settings_screen.dart`
- Modify: `lib/main.dart`, `pubspec.yaml`
- Test: `test/features/shell/app_shell_test.dart`

**Interfaces:**
- Consumes: `nouriTheme()` (Task 2), `AppLocalizations` (Task 3)
- Produces: `appRouter`, `AppShell`, and the five route paths `/`, `/athkar`, `/reports`, `/finance`, `/settings`

- [ ] **Step 1: Add dependencies**

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  go_router: ^14.2.7
```

Run: `flutter pub get`

- [ ] **Step 2: Write the failing test**

```dart
// test/features/shell/app_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nouri/app.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: NouriApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows five tabs in the approved order', (tester) async {
    await pumpApp(tester);
    expect(find.text('النهاردة'), findsOneWidget);
    expect(find.text('الأذكار'), findsOneWidget);
    expect(find.text('التقارير'), findsOneWidget);
    expect(find.text('المالية'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('renders right-to-left by default', (tester) async {
    await pumpApp(tester);
    expect(Directionality.of(tester.element(find.text('النهاردة'))),
        TextDirection.rtl);
  });

  testWidgets('the finance tab reads as coming soon, never as broken',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('المالية'));
    await tester.pumpAndSettle();
    expect(find.text('قريباً إن شاء الله'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.warning), findsNothing);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/features/shell/app_shell_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 4: Implement the shell**

`AppShell` is a `StatefulShellRoute` scaffold with a `BottomNavigationBar` styled from the tokens: `NouriColors.surface` background, `NouriColors.gold` for the selected item, `NouriColors.muted` for the rest, `showUnselectedLabels: true`, no elevation.

Create `lib/app.dart` exporting `NouriApp` — a `MaterialApp.router` with `theme: nouriTheme()`, `locale: const Locale('ar')`, the localization delegates, and `routerConfig: appRouter`.

- [ ] **Step 5: Implement the Finance placeholder**

```dart
// lib/features/finance/finance_placeholder.dart
import 'package:flutter/material.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/l10n/app_localizations.dart';

/// Not an error state and not an empty state — a calm promise. Same navy card
/// language as the rest of the app, gold avatar, Nouri speaking colloquially.
class FinancePlaceholder extends StatelessWidget {
  const FinancePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: NouriColors.surfaceActive,
                shape: BoxShape.circle,
                border: Border.all(color: NouriColors.gold, width: 1.5),
              ),
              alignment: Alignment.center,
              child: const Text('نوري',
                  style: TextStyle(color: NouriColors.gold,
                      fontWeight: FontWeight.w700, fontSize: 17)),
            ),
            const SizedBox(height: 20),
            Text(l.nouriComingSoon,
                style: const TextStyle(color: NouriColors.text,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(l.nouriFinancePlaceholder,
                textAlign: TextAlign.center,
                style: const TextStyle(color: NouriColors.muted,
                    fontSize: 13, height: 1.8)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the test**

Run: `flutter test test/features/shell/app_shell_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add app shell, five-tab navigation, and the Finance placeholder"
```

---

## Task 10: Home — header, progress ring, next-prayer card

The header, ring and next-prayer card are **fixed contracts**: Phase 2 replaces
only the middle of this screen. Build them as three independent widgets so that
swap is a one-line change.

**Files:**
- Create: `lib/features/home/widgets/home_header.dart`, `lib/features/home/widgets/progress_ring.dart`, `lib/features/home/widgets/next_prayer_card.dart`, `lib/features/home/daily_items.dart`
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/home/progress_ring_test.dart`, `test/features/home/next_prayer_card_test.dart`, `test/features/home/daily_items_test.dart`

**Interfaces:**
- Consumes: `formatCountdown`, `formatClock`, `toArabicDigits` (Task 3); `hijriFor` (Task 5); `DailyPrayerTimes`, `PrayerSlot`, `iqamaFor` (Task 5)
- Produces: `HomeHeader({required HijriDate hijri, required String greeting})`; `ProgressRing({required int done, required int total})`; `NextPrayerCard({required PrayerSlot slot, required DateTime iqama, required Duration remaining})`; `DailyItems.count(...)` returning `(done, total)` and `greetingFor(DateTime)`

- [ ] **Step 1: Write the failing daily-items test**

```dart
// test/features/home/daily_items_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/home/daily_items.dart';

void main() {
  test('there are exactly nine daily religious items', () {
    expect(kDailyItemTotal, 9); // 5 prayers + morning + evening athkar + tasbeeh + wird
  });

  test('counts logged prayers and completed wird items', () {
    final c = DailyItems.count(
      loggedPrayers: 3,
      morningAthkarDone: true,
      eveningAthkarDone: false,
      tasbeehDone: true,
      quranWirdDone: false,
    );
    expect(c.done, 5);
    expect(c.total, 9);
  });

  test('a day with nothing logged is zero, never negative', () {
    final c = DailyItems.count(
      loggedPrayers: 0, morningAthkarDone: false, eveningAthkarDone: false,
      tasbeehDone: false, quranWirdDone: false);
    expect(c.done, 0);
    expect(c.fraction, 0.0);
  });

  test('fraction is clamped to 1.0 even if more is logged', () {
    final c = DailyItems.count(
      loggedPrayers: 5, morningAthkarDone: true, eveningAthkarDone: true,
      tasbeehDone: true, quranWirdDone: true);
    expect(c.fraction, 1.0);
  });

  group('greetingFor', () {
    test('morning, afternoon, evening and night each get their own line', () {
      expect(greetingFor(DateTime(2026, 9, 5, 6)), 'صباح الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 14)), 'مساء الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 20)), 'مساء الخير');
      expect(greetingFor(DateTime(2026, 9, 5, 2)), 'ليلة طيبة');
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/home/daily_items_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement daily items**

```dart
// lib/features/home/daily_items.dart

/// The nine things Nouri tracks each day in this slice. The ring shows a plain
/// count of these — not a percentage, and never a failure state.
const kDailyItemTotal = 9;

class DailyItemCount {
  const DailyItemCount(this.done, this.total);
  final int done;
  final int total;
  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);
}

class DailyItems {
  static DailyItemCount count({
    required int loggedPrayers,
    required bool morningAthkarDone,
    required bool eveningAthkarDone,
    required bool tasbeehDone,
    required bool quranWirdDone,
  }) {
    final done = loggedPrayers +
        (morningAthkarDone ? 1 : 0) +
        (eveningAthkarDone ? 1 : 0) +
        (tasbeehDone ? 1 : 0) +
        (quranWirdDone ? 1 : 0);
    return DailyItemCount(done, kDailyItemTotal);
  }
}

String greetingFor(DateTime now) {
  if (now.hour >= 5 && now.hour < 12) return 'صباح الخير';
  if (now.hour >= 12 && now.hour < 23) return 'مساء الخير';
  return 'ليلة طيبة';
}
```

- [ ] **Step 4: Run it and see it pass**

Run: `flutter test test/features/home/daily_items_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Write the failing widget tests**

```dart
// test/features/home/progress_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/home/widgets/progress_ring.dart';

void main() {
  Future<void> pump(WidgetTester t, Widget w) => t.pumpWidget(
        MaterialApp(home: Directionality(
            textDirection: TextDirection.rtl, child: Scaffold(body: w))),
      );

  testWidgets('shows the count in Arabic-Indic digits', (t) async {
    await pump(t, const ProgressRing(done: 5, total: 9));
    expect(find.text('٥/٩'), findsOneWidget);
  });

  testWidgets('an empty day renders without any error styling', (t) async {
    await pump(t, const ProgressRing(done: 0, total: 9));
    expect(find.text('٠/٩'), findsOneWidget);
    expect(tester_hasRed(t), isFalse);
  });
}

bool tester_hasRed(WidgetTester t) => t
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .any((d) {
      final c = (d.decoration as BoxDecoration).color;
      return c != null && c.red > 200 && c.green < 90 && c.blue < 90;
    });
```

```dart
// test/features/home/next_prayer_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/features/home/widgets/next_prayer_card.dart';

void main() {
  testWidgets('shows prayer name, countdown and iqama in Arabic digits',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: NextPrayerCard(
            slot: PrayerSlot('asr', DateTime(2026, 9, 5, 15, 15)),
            iqama: DateTime(2026, 9, 5, 15, 30),
            remaining: const Duration(hours: 1, minutes: 24, seconds: 10),
          ),
        ),
      ),
    ));
    expect(find.text('العصر'), findsOneWidget);
    expect(find.text('١:٢٤:١٠'), findsOneWidget);
    expect(find.text('٣:٣٠'), findsOneWidget);
  });

  testWidgets('a passed prayer shows zero, never a negative countdown',
      (t) async {
    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: NextPrayerCard(
            slot: PrayerSlot('isha', DateTime(2026, 9, 5, 19, 4)),
            iqama: DateTime(2026, 9, 5, 19, 19),
            remaining: const Duration(minutes: -5),
          ),
        ),
      ),
    ));
    expect(find.text('٠:٠٠:٠٠'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Implement the three widgets**

- `HomeHeader` — RTL row: greeting (`titleLarge`) over `hijri.formatted` (`bodySmall`) on the start side; a 40px gold-bordered circular «نوري» avatar on the end side.
- `ProgressRing` — 74px `CustomPaint` drawing a `NouriColors.surface` track and a `NouriColors.gold` arc sweeping `fraction * 2π` from −π/2, with `toArabicDigits('$done/$total')` centred. **No red at any fraction**, including zero.
- `NextPrayerCard` — `NouriColors.surfaceActive` card, 1px `NouriColors.gold` border, radius 16: label `labelNextPrayer` in gold; prayer name 24px bold; `formatCountdown(remaining)` in gold 27px tabular; footer row divided by a `NouriColors.border` line showing `labelIqama` + `formatClock(iqama)`.

- [ ] **Step 7: Run the widget tests**

Run: `flutter test test/features/home/`
Expected: PASS (all)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add Home header, progress ring, and next-prayer card"
```

---

## Task 11: Prayer rows, logging and scoring

**Files:**
- Create: `lib/features/prayers/prayer_row.dart`, `lib/features/prayers/prayer_log_sheet.dart`, `lib/features/prayers/prayer_scoring.dart`, `lib/features/prayers/prayer_providers.dart`
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/prayers/prayer_row_test.dart`, `test/features/prayers/prayer_log_sheet_test.dart`

**Interfaces:**
- Consumes: `PrayerState` and `PrayerDao` (Task 4); `PrayerSlot` (Task 5)
- Produces: `PrayerRow({required PrayerSlot slot, required PrayerState state, required bool isNext, required VoidCallback onTap})`; `showPrayerLogSheet(BuildContext, PrayerSlot, PrayerState) → Future<PrayerState?>`; `chipColorFor(PrayerState)`, `chipLabelFor(PrayerState, AppLocalizations)`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/prayers/prayer_row_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/theme/nouri_colors.dart';
import 'package:nouri/data/db/tables.dart';
import 'package:nouri/features/prayers/prayer_scoring.dart';

void main() {
  test('each state maps to its approved chip colour', () {
    expect(chipColorFor(PrayerState.mosque), NouriColors.gold);
    expect(chipColorFor(PrayerState.congregation), NouriColors.success);
    expect(chipColorFor(PrayerState.onTime), NouriColors.muted);
    expect(chipColorFor(PrayerState.late_), NouriColors.attention);
    expect(chipColorFor(PrayerState.none), NouriColors.muted);
  });

  test('no state is ever rendered in a failure red', () {
    for (final s in PrayerState.values) {
      final c = chipColorFor(s);
      expect(c.red > 200 && c.green < 90 && c.blue < 90, isFalse);
    }
  });

  test('scores follow the agreed ladder', () {
    expect(PrayerState.mosque.score, 100);
    expect(PrayerState.congregation.score, 85);
    expect(PrayerState.onTime.score, 70);
    expect(PrayerState.late_.score, 40);
    expect(PrayerState.none.score, 0);
  });

  test('an unlogged prayer is excluded from the daily average, not zeroed', () {
    final avg = dailyPrayerAverage([
      PrayerState.mosque,
      PrayerState.congregation,
      PrayerState.none,
    ]);
    expect(avg, closeTo(92.5, 0.01),
        reason: 'unlogged must not drag the average down');
  });

  test('a day with nothing logged has no average rather than zero', () {
    expect(dailyPrayerAverage([PrayerState.none, PrayerState.none]), isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/prayers/prayer_row_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement scoring**

```dart
// lib/features/prayers/prayer_scoring.dart
import 'package:flutter/material.dart';
import '../../core/theme/nouri_colors.dart';
import '../../data/db/tables.dart';

Color chipColorFor(PrayerState s) => switch (s) {
      PrayerState.mosque => NouriColors.gold,
      PrayerState.congregation => NouriColors.success,
      PrayerState.onTime => NouriColors.muted,
      PrayerState.late_ => NouriColors.attention,
      PrayerState.none => NouriColors.muted,
    };

/// Unlogged prayers are *excluded*, never counted as zero. Nouri measures how
/// you prayed, not how many boxes are empty.
double? dailyPrayerAverage(List<PrayerState> states) {
  final logged = states.where((s) => s != PrayerState.none).toList();
  if (logged.isEmpty) return null;
  return logged.map((s) => s.score).reduce((a, b) => a + b) / logged.length;
}
```

- [ ] **Step 4: Write the logging-sheet test**

```dart
// test/features/prayers/prayer_log_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/tables.dart';
import 'package:nouri/features/prayers/prayer_log_sheet.dart';

void main() {
  testWidgets('offers the four states and returns the tapped one', (t) async {
    PrayerState? result;
    await t.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () async =>
                  result = await showPrayerLogSheet(ctx, 'asr', PrayerState.none),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    expect(find.text('في المسجد'), findsOneWidget);
    expect(find.text('جماعة'), findsOneWidget);
    expect(find.text('في الوقت'), findsOneWidget);
    expect(find.text('متأخرة'), findsOneWidget);

    await t.tap(find.text('في المسجد'));
    await t.pumpAndSettle();
    expect(result, PrayerState.mosque);
  });

  testWidgets('the sheet contains no punishing language', (t) async {
    await t.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showPrayerLogSheet(ctx, 'asr', PrayerState.none),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    for (final w in ['فاتتك', 'ضيعت', 'فشل']) {
      expect(find.textContaining(w), findsNothing);
    }
  });
}
```

- [ ] **Step 5: Implement the row and the sheet**

- `PrayerRow` — `NouriColors.surface` card (or `surfaceActive` with a `border` outline when `isNext`), radius 14: a small state dot, the Arabic prayer name, `formatClock(slot.time)` in muted, and a state chip on the end. The whole row is an `InkWell` calling `onTap`.
- `showPrayerLogSheet` — a `showModalBottomSheet` on `NouriColors.surface` listing the four states in descending score order, each a full-width tappable row with its chip colour, plus a «لسه» option to clear. Returns the chosen `PrayerState`, or null if dismissed.

Wire both into `HomeScreen` under the `labelTodayPrayers` heading, persisting through `PrayerDao.upsertLog`.

- [ ] **Step 6: Run the prayer tests**

Run: `flutter test test/features/prayers/`
Expected: PASS (7 tests)

- [ ] **Step 7: Handle the notification action**

In the notification response handler, a payload of `log:<prayer>` with the `logged` action ID writes `PrayerState.onTime` for today via `PrayerDao.upsertLog`; tapping the notification body instead deep-links to Home so the user can choose a higher state.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add prayer rows, state chips, logging sheet, and averaging that never punishes"
```

---

## Task 12: Athkar content, validation and the verification sheet

**Files:**
- Create: `assets/athkar/morning.json`, `assets/athkar/evening.json`, `assets/athkar/sleep.json`, `assets/athkar/tasbeeh.json`
- Create: `lib/data/athkar/athkar_item.dart`, `lib/data/athkar/athkar_repository.dart`, `tool/generate_athkar_verification.dart`
- Test: `test/data/athkar/athkar_item_test.dart`, `test/data/athkar/athkar_assets_test.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `AthkarItem(id, text, count, source, virtue, note)` with `AthkarItem.fromJson`; `AthkarSet(version, category, items)`; `AthkarRepository.load(String category)`

- [ ] **Step 1: Write the failing model test**

```dart
// test/data/athkar/athkar_item_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/athkar/athkar_item.dart';

void main() {
  test('parses a complete entry', () {
    final item = AthkarItem.fromJson({
      'id': 'morning-01',
      'text': 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ',
      'count': 1,
      'source': 'رواه مسلم',
      'virtue': null,
    });
    expect(item.id, 'morning-01');
    expect(item.count, 1);
    expect(item.source, 'رواه مسلم');
    expect(item.virtue, isNull);
    expect(item.hasVirtue, isFalse);
  });

  test('an entry with no source is rejected', () {
    expect(
      () => AthkarItem.fromJson(
          {'id': 'x', 'text': 'نص', 'count': 1, 'source': ''}),
      throwsA(isA<FormatException>()),
    );
  });

  test('a count below one is rejected', () {
    expect(
      () => AthkarItem.fromJson(
          {'id': 'x', 'text': 'نص', 'count': 0, 'source': 'رواه البخاري'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('empty text is rejected', () {
    expect(
      () => AthkarItem.fromJson(
          {'id': 'x', 'text': '', 'count': 1, 'source': 'رواه البخاري'}),
      throwsA(isA<FormatException>()),
    );
  });

  test('hasVirtue is false for an empty string as well as null', () {
    final item = AthkarItem.fromJson({
      'id': 'x', 'text': 'نص', 'count': 1, 'source': 'رواه البخاري', 'virtue': '',
    });
    expect(item.hasVirtue, isFalse);
  });
}
```

- [ ] **Step 2: Write the failing asset test**

```dart
// test/data/athkar/athkar_assets_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/athkar/athkar_item.dart';

void main() {
  const files = {
    'assets/athkar/morning.json': 15,
    'assets/athkar/evening.json': 15,
    'assets/athkar/sleep.json': 10,
    'assets/athkar/tasbeeh.json': 1,
  };

  files.forEach((path, minCount) {
    group(path, () {
      late AthkarSet set;

      setUpAll(() {
        set = AthkarSet.fromJson(
            jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>);
      });

      test('parses and carries the expected number of items', () {
        expect(set.items.length, greaterThanOrEqualTo(minCount));
      });

      test('every item has a non-empty source', () {
        for (final i in set.items) {
          expect(i.source.trim(), isNotEmpty, reason: i.id);
        }
      });

      test('ids are unique', () {
        expect(set.items.map((i) => i.id).toSet().length, set.items.length);
      });

      test('text carries Arabic characters and no western digits', () {
        for (final i in set.items) {
          expect(RegExp(r'[؀-ۿ]').hasMatch(i.text), isTrue, reason: i.id);
          expect(RegExp(r'[0-9]').hasMatch(i.text), isFalse, reason: i.id);
        }
      });
    });
  });
}
```

- [ ] **Step 3: Run both and watch them fail**

Run: `flutter test test/data/athkar/`
Expected: FAIL — URI does not exist

- [ ] **Step 4: Implement the model**

```dart
// lib/data/athkar/athkar_item.dart

/// A single dhikr. `source` is mandatory and always displayed. `virtue` is
/// optional and ships ONLY where the wording is well-established — an
/// unverified virtue is stored as null and the UI hides the reveal entirely.
class AthkarItem {
  const AthkarItem({
    required this.id,
    required this.text,
    required this.count,
    required this.source,
    this.virtue,
    this.note,
  });

  final String id;
  final String text;
  final int count;
  final String source;
  final String? virtue;
  final String? note;

  bool get hasVirtue => virtue != null && virtue!.trim().isNotEmpty;

  factory AthkarItem.fromJson(Map<String, dynamic> j) {
    final id = (j['id'] as String?)?.trim() ?? '';
    final text = (j['text'] as String?)?.trim() ?? '';
    final count = j['count'] as int? ?? 0;
    final source = (j['source'] as String?)?.trim() ?? '';

    if (id.isEmpty) throw const FormatException('athkar entry has no id');
    if (text.isEmpty) throw FormatException('athkar entry $id has no text');
    if (count < 1) throw FormatException('athkar entry $id has count < 1');
    if (source.isEmpty) throw FormatException('athkar entry $id has no source');

    return AthkarItem(
      id: id, text: text, count: count, source: source,
      virtue: (j['virtue'] as String?)?.trim(),
      note: (j['note'] as String?)?.trim(),
    );
  }
}

class AthkarSet {
  const AthkarSet({required this.version, required this.category, required this.items});
  final int version;
  final String category;
  final List<AthkarItem> items;

  factory AthkarSet.fromJson(Map<String, dynamic> j) => AthkarSet(
        version: j['version'] as int,
        category: j['category'] as String,
        items: (j['items'] as List)
            .map((e) => AthkarItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
```

- [ ] **Step 5: Author the athkar content**

Write the four JSON files following the schema. Rules that are not negotiable:

- Arabic text fully vowelled, matching حصن المسلم.
- `source` on every entry (`رواه البخاري`, `رواه مسلم`, `رواه أبو داود والترمذي`, …).
- `virtue` **only** where the wording is well-established. **When unsure, set it to `null`.** A missing virtue is correct; an invented one is a defect.
- Morning and evening sets include آية الكرسي, the three المعوذات, سيد الاستغفار, أصبحنا وأصبح الملك لله / أمسينا وأمسى الملك لله, and the common repeated adhkar with their counts (٣ / ٧ / ١٠ / ١٠٠ as narrated).
- `tasbeeh.json` holds the single wird entry: سبحان الله وبحمده، سبحان الله العظيم, count 100.

- [ ] **Step 6: Write the verification sheet generator**

```dart
// tool/generate_athkar_verification.dart
// Run: dart run tool/generate_athkar_verification.dart
// Writes docs/athkar-verification.md — a plain sheet listing every dhikr with
// its text, count, source and virtue, so a human can check it against a
// physical حصن المسلم before the app is relied on.
```

The generated document must contain, per category, a numbered list where each
entry shows: the id, the full Arabic text, the count, the source, and either the
virtue or the explicit line `الفضل: (غير مذكور)` so an empty field is visibly
deliberate rather than an oversight.

- [ ] **Step 7: Run the generator and the tests**

Run:
```bash
dart run tool/generate_athkar_verification.dart
flutter test test/data/athkar/
```
Expected: `docs/athkar-verification.md` is written; all athkar tests PASS.

- [ ] **Step 8: Flag the sheet for human review**

Add a line at the top of `docs/athkar-verification.md`: this file has not yet been
checked against a printed copy, and the app must not be treated as an authority
until it has. **Tell the user the file is ready for review when this task lands.**

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add athkar content assets with mandatory sources and a verification sheet"
```

---

## Task 13: Athkar screen — tabs, stepper, multi-tap counts, tap-to-reveal virtue

**Files:**
- Create: `lib/features/athkar/widgets/dhikr_card.dart`, `lib/features/athkar/widgets/dhikr_stepper.dart`, `lib/features/athkar/athkar_controller.dart`
- Modify: `lib/features/athkar/athkar_screen.dart`
- Test: `test/features/athkar/athkar_controller_test.dart`, `test/features/athkar/dhikr_card_test.dart`

**Interfaces:**
- Consumes: `AthkarSet`, `AthkarItem` (Task 12); `AthkarDao` (Task 4); `NouriText.dhikr` (Task 2)
- Produces: `AthkarController(items)` with `currentIndex`, `currentRepeats`, `tap()`, `next()`, `previous()`, `isComplete`, `completedItems`; `DhikrCard({required AthkarItem item, required int repeatsDone, required VoidCallback onTap})`

- [ ] **Step 1: Write the failing controller test**

```dart
// test/features/athkar/athkar_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/athkar/athkar_item.dart';
import 'package:nouri/features/athkar/athkar_controller.dart';

AthkarItem item(String id, int count) =>
    AthkarItem(id: id, text: 'نص $id', count: count, source: 'رواه البخاري');

void main() {
  test('a single-repeat dhikr advances on one tap', () {
    final c = AthkarController([item('a', 1), item('b', 1)]);
    expect(c.currentIndex, 0);
    c.tap();
    expect(c.currentIndex, 1);
  });

  test('a three-repeat dhikr needs three taps', () {
    final c = AthkarController([item('a', 3), item('b', 1)]);
    c.tap();
    expect(c.currentIndex, 0, reason: 'still on the first dhikr');
    expect(c.currentRepeats, 1);
    c.tap();
    expect(c.currentIndex, 0);
    expect(c.currentRepeats, 2);
    c.tap();
    expect(c.currentIndex, 1, reason: 'the third tap advances');
  });

  test('repeat count resets when a new dhikr is shown', () {
    final c = AthkarController([item('a', 2), item('b', 3)]);
    c.tap();
    c.tap();
    expect(c.currentIndex, 1);
    expect(c.currentRepeats, 0);
  });

  test('going back restores the previous dhikr as fully counted', () {
    final c = AthkarController([item('a', 2), item('b', 3)]);
    c.tap();
    c.tap();
    c.previous();
    expect(c.currentIndex, 0);
    expect(c.currentRepeats, 2, reason: 'a finished dhikr stays finished');
  });

  test('previous on the first dhikr does nothing', () {
    final c = AthkarController([item('a', 1)]);
    c.previous();
    expect(c.currentIndex, 0);
  });

  test('the set completes after the last repetition of the last dhikr', () {
    final c = AthkarController([item('a', 1), item('b', 2)]);
    c.tap();
    c.tap();
    expect(c.isComplete, isFalse);
    c.tap();
    expect(c.isComplete, isTrue);
    expect(c.completedItems, 2);
  });

  test('tapping past completion never overflows the index', () {
    final c = AthkarController([item('a', 1)]);
    c.tap();
    c.tap();
    c.tap();
    expect(c.currentIndex, 0);
    expect(c.isComplete, isTrue);
  });

  test('skipping forward marks nothing as done', () {
    final c = AthkarController([item('a', 3), item('b', 1)]);
    c.next();
    expect(c.currentIndex, 1);
    expect(c.completedItems, 0, reason: 'skipped, not performed');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/athkar/athkar_controller_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement the controller**

```dart
// lib/features/athkar/athkar_controller.dart
import 'package:flutter/foundation.dart';
import '../../data/athkar/athkar_item.dart';

/// Drives a set of athkar as a lightweight mini-tasbeeh: a dhikr with a target
/// of n requires n taps before it advances. Going back is always allowed, and a
/// dhikr already performed stays performed.
class AthkarController extends ChangeNotifier {
  AthkarController(this.items) : _repeats = List.filled(items.length, 0);

  final List<AthkarItem> items;
  final List<int> _repeats;
  int _index = 0;
  bool _complete = false;

  int get currentIndex => _index;
  int get currentRepeats => _repeats[_index];
  AthkarItem get current => items[_index];
  bool get isComplete => _complete;
  int get completedItems {
    var n = 0;
    for (var i = 0; i < items.length; i++) {
      if (_repeats[i] >= items[i].count) n++;
    }
    return n;
  }

  void tap() {
    if (_complete) return;
    if (_repeats[_index] < items[_index].count) {
      _repeats[_index]++;
    }
    if (_repeats[_index] >= items[_index].count) {
      if (_index < items.length - 1) {
        _index++;
      } else {
        _complete = true;
      }
    }
    notifyListeners();
  }

  /// Skips ahead without counting the current dhikr as performed.
  void next() {
    if (_index < items.length - 1) {
      _index++;
      notifyListeners();
    }
  }

  void previous() {
    if (_index > 0) {
      _index--;
      _complete = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 4: Run the controller test**

Run: `flutter test test/features/athkar/athkar_controller_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Write the failing card test**

```dart
// test/features/athkar/dhikr_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/athkar/athkar_item.dart';
import 'package:nouri/features/athkar/widgets/dhikr_card.dart';

void main() {
  Future<void> pump(WidgetTester t, AthkarItem item, {int done = 0}) =>
      t.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              body: DhikrCard(item: item, repeatsDone: done, onTap: () {})),
        ),
      ));

  testWidgets('renders the dhikr in Amiri and shows the source', (t) async {
    await pump(t, const AthkarItem(
        id: 'a', text: 'سُبْحَانَ اللهِ', count: 3, source: 'رواه مسلم'));
    final text = t.widget<Text>(find.text('سُبْحَانَ اللهِ'));
    expect(text.style?.fontFamily, 'Amiri');
    expect(find.textContaining('رواه مسلم'), findsOneWidget);
  });

  testWidgets('shows the repeat pill in Arabic-Indic digits', (t) async {
    await pump(t, const AthkarItem(
        id: 'a', text: 'نص', count: 3, source: 'رواه مسلم'), done: 1);
    expect(find.text('١ / ٣'), findsOneWidget);
  });

  testWidgets('the virtue is hidden until tapped', (t) async {
    await pump(t, const AthkarItem(
        id: 'a', text: 'نص', count: 1, source: 'رواه مسلم',
        virtue: 'فضل الذكر'));
    expect(find.text('فضل الذكر'), findsNothing);
    await t.tap(find.text('الفضل'));
    await t.pumpAndSettle();
    expect(find.text('فضل الذكر'), findsOneWidget);
  });

  testWidgets('no virtue means no reveal control at all', (t) async {
    await pump(t, const AthkarItem(
        id: 'a', text: 'نص', count: 1, source: 'رواه مسلم', virtue: null));
    expect(find.text('الفضل'), findsNothing);
  });
}
```

- [ ] **Step 6: Implement the card and the screen**

- `DhikrCard` — `NouriColors.surface`, radius 16, centred: the dhikr in `NouriText.dhikr` (Amiri, height 2.0), the source in muted 11px, and a repeat pill showing `toArabicDigits('$repeatsDone / ${item.count}')` on `surfaceActive` with a `border` outline. When `item.hasVirtue`, an `ExpansionTile`-style «الفضل» control that reveals the text on tap. When it does not, the control is absent — not disabled, absent.
- `AthkarScreen` — four tabs (`التسبيح` · `الصباح` · `المساء` · `النوم`) as a segmented control on `NouriColors.surface` with the active tab filled gold. Below: the step dots (done = success, current = gold, pending = surfaceActive), the `DhikrCard`, a progress bar, a full-width gold «تمّ» button that calls `tap()`, and a back control. Progress persists through `AthkarDao.upsert` on every tap so a kill mid-set loses nothing.

- [ ] **Step 7: Run the card tests**

Run: `flutter test test/features/athkar/`
Expected: PASS (12 tests)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add athkar tabs, dhikr stepper with multi-tap counts, tap-to-reveal virtue"
```

---

## Task 14: The circular tasbeeh

**Files:**
- Create: `lib/features/athkar/widgets/tasbeeh_ring.dart`, `lib/features/athkar/tasbeeh_controller.dart`
- Test: `test/features/athkar/tasbeeh_controller_test.dart`, `test/features/athkar/tasbeeh_ring_test.dart`

**Interfaces:**
- Consumes: `AthkarDao` (Task 4); `toArabicDigits` (Task 3)
- Produces: `TasbeehController(target:, initial:)` with `count`, `target`, `fraction`, `increment()`, `reset()`, `setTarget(int)`, `justCompleted`; `TasbeehRing({required int count, required int target, required VoidCallback onTap})`

- [ ] **Step 1: Write the failing controller test**

```dart
// test/features/athkar/tasbeeh_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/athkar/tasbeeh_controller.dart';

void main() {
  test('starts at zero against the default target of 100', () {
    final c = TasbeehController();
    expect(c.count, 0);
    expect(c.target, 100);
    expect(c.fraction, 0.0);
  });

  test('increments and reports a fraction', () {
    final c = TasbeehController()..increment();
    expect(c.count, 1);
    expect(c.fraction, closeTo(0.01, 0.0001));
  });

  test('counting past the target is allowed and the fraction clamps', () {
    final c = TasbeehController(target: 3);
    for (var i = 0; i < 5; i++) {
      c.increment();
    }
    expect(c.count, 5, reason: 'extra dhikr is never refused');
    expect(c.fraction, 1.0);
  });

  test('justCompleted fires once, on the crossing only', () {
    final c = TasbeehController(target: 2);
    c.increment();
    expect(c.justCompleted, isFalse);
    c.increment();
    expect(c.justCompleted, isTrue);
    c.increment();
    expect(c.justCompleted, isFalse, reason: 'it is a one-shot signal');
  });

  test('reset returns to zero without touching the target', () {
    final c = TasbeehController(target: 33)..increment()..increment();
    c.reset();
    expect(c.count, 0);
    expect(c.target, 33);
  });

  test('the target can be raised and the count is kept', () {
    final c = TasbeehController(target: 100, initial: 40);
    c.setTarget(300);
    expect(c.target, 300);
    expect(c.count, 40);
  });

  test('the target can never be set below one', () {
    final c = TasbeehController();
    c.setTarget(0);
    expect(c.target, greaterThanOrEqualTo(1));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/athkar/tasbeeh_controller_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement the controller**

```dart
// lib/features/athkar/tasbeeh_controller.dart
import 'package:flutter/foundation.dart';

class TasbeehController extends ChangeNotifier {
  TasbeehController({int target = 100, int initial = 0})
      : _target = target < 1 ? 1 : target,
        _count = initial;

  int _count;
  int _target;
  bool _justCompleted = false;

  int get count => _count;
  int get target => _target;
  double get fraction => (_count / _target).clamp(0.0, 1.0);

  /// True only on the tap that crossed the target — the UI uses it for a single
  /// soft confirmation, never a recurring celebration.
  bool get justCompleted => _justCompleted;

  void increment() {
    final was = _count;
    _count++;
    _justCompleted = was < _target && _count >= _target;
    notifyListeners();
  }

  void reset() {
    _count = 0;
    _justCompleted = false;
    notifyListeners();
  }

  void setTarget(int t) {
    _target = t < 1 ? 1 : t;
    _justCompleted = false;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run it and see it pass**

Run: `flutter test test/features/athkar/tasbeeh_controller_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Write the failing ring test**

```dart
// test/features/athkar/tasbeeh_ring_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/athkar/widgets/tasbeeh_ring.dart';

void main() {
  testWidgets('shows the count and target in Arabic-Indic digits', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            body: TasbeehRing(count: 33, target: 100, onTap: () {})),
      ),
    ));
    expect(find.text('٣٣'), findsOneWidget);
    expect(find.text('من ١٠٠'), findsOneWidget);
  });

  testWidgets('tapping the ring increments', (t) async {
    var taps = 0;
    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
            body: TasbeehRing(count: 0, target: 100, onTap: () => taps++)),
      ),
    ));
    await t.tap(find.byType(TasbeehRing));
    expect(taps, 1);
  });
}
```

- [ ] **Step 6: Implement the ring**

`TasbeehRing` is a 236px `GestureDetector` wrapping a `CustomPaint`:

- Draw `target` beads evenly around a circle of radius 110 at angle `i / target * 2π − π/2`.
- Beads below `count` are `NouriColors.gold` and 10px across; the rest are `NouriColors.surfaceActive` and 8px. Above ~150 beads, switch to a continuous gold arc so the ring stays legible.
- Centre: `toArabicDigits('$count')` in `NouriText.counter` over `toArabicDigits('من $target')` in muted 13px.
- The whole ring is tappable, and the «سبّح» button calls the same callback.

Persist every increment through `AthkarDao.upsert(type: 'tasbeeh', progress: count, target: target)` so the day survives an app kill. Reset clears the count for today only.

- [ ] **Step 7: Run the ring tests**

Run: `flutter test test/features/athkar/tasbeeh_ring_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add the circular tasbeeh with adjustable target and persistence"
```

---

## Task 15: Qur'an wird, the wird grid, and the Home ring wiring

**Files:**
- Create: `lib/features/quran/quran_wird_card.dart`, `lib/features/quran/khatma.dart`, `lib/features/home/widgets/wird_grid.dart`
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/quran/khatma_test.dart`, `test/features/home/wird_grid_test.dart`

**Interfaces:**
- Consumes: `QuranDao`, `AthkarDao` (Task 4); `DailyItems` (Task 10)
- Produces: `KhatmaProgress(pagesRead, totalPages)` with `fraction`, `percentLabel`, `isComplete`; `WirdGrid({required WirdState morning, tasbeeh, evening, quran})`; `WirdState(label, subtitle, fraction, done)`

- [ ] **Step 1: Write the failing khatma test**

```dart
// test/features/quran/khatma_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/quran/khatma.dart';

void main() {
  test('reports a fraction of the full mushaf', () {
    const k = KhatmaProgress(pagesRead: 302, totalPages: 604);
    expect(k.fraction, closeTo(0.5, 0.001));
    expect(k.percentLabel, '٥٠٪');
  });

  test('a fresh khatma is zero, not an error', () {
    const k = KhatmaProgress(pagesRead: 0, totalPages: 604);
    expect(k.fraction, 0.0);
    expect(k.percentLabel, '٠٪');
    expect(k.isComplete, isFalse);
  });

  test('reading beyond a full khatma clamps and reports completion', () {
    const k = KhatmaProgress(pagesRead: 700, totalPages: 604);
    expect(k.fraction, 1.0);
    expect(k.isComplete, isTrue);
  });

  test('a rubʿ is three pages by default', () {
    expect(kDailyWirdPages, 3);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/quran/khatma_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement khatma progress**

```dart
// lib/features/quran/khatma.dart
import '../../core/format/arabic_numerals.dart';

/// A rubʿ — roughly three pages of a standard mushaf.
const kDailyWirdPages = 3;

class KhatmaProgress {
  const KhatmaProgress({required this.pagesRead, required this.totalPages});
  final int pagesRead;
  final int totalPages;

  double get fraction =>
      totalPages == 0 ? 0 : (pagesRead / totalPages).clamp(0.0, 1.0);
  bool get isComplete => pagesRead >= totalPages;
  String get percentLabel => toArabicDigits('${(fraction * 100).round()}٪');
}
```

- [ ] **Step 4: Run it and see it pass**

Run: `flutter test test/features/quran/khatma_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Write the failing grid test**

```dart
// test/features/home/wird_grid_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/home/widgets/wird_grid.dart';

void main() {
  testWidgets('renders the four cards in the approved order', (t) async {
    await t.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: WirdGrid(
            morning: WirdState(label: 'أذكار الصباح', subtitle: 'اتقفلت ٦:٤٠ ص',
                fraction: 1, done: true),
            tasbeeh: WirdState(label: 'التسبيح', subtitle: '٣٣ من ١٠٠',
                fraction: .33, done: false),
            evening: WirdState(label: 'أذكار المساء', subtitle: 'بعد المغرب',
                fraction: 0, done: false),
            quran: WirdState(label: 'ورد القرآن', subtitle: 'الختمة ٤٢٪',
                fraction: .42, done: false),
          ),
        ),
      ),
    ));

    final labels = t.widgetList<Text>(find.byType(Text))
        .map((w) => w.data)
        .where((s) => s != null && s.startsWith(RegExp('أذكار|التسبيح|ورد')))
        .toList();
    expect(labels, ['أذكار الصباح', 'التسبيح', 'أذكار المساء', 'ورد القرآن']);
  });

  testWidgets('a completed card is dimmed and softly checked, never marked failed',
      (t) async {
    await t.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: WirdGrid(
            morning: WirdState(label: 'أذكار الصباح', subtitle: 'تمّت',
                fraction: 1, done: true),
            tasbeeh: WirdState(label: 'التسبيح', subtitle: '٠ من ١٠٠',
                fraction: 0, done: false),
            evening: WirdState(label: 'أذكار المساء', subtitle: 'بعد المغرب',
                fraction: 0, done: false),
            quran: WirdState(label: 'ورد القرآن', subtitle: 'لسه',
                fraction: 0, done: false),
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
```

- [ ] **Step 6: Implement the grid and wire the ring**

`WirdGrid` is a 2×2 `GridView` of `NouriColors.surface` cards, radius 14, in the
order **أذكار الصباح · التسبيح · أذكار المساء · ورد القرآن**. Each card carries a
label, a muted subtitle, and a 4px progress bar (gold; `NouriColors.success` when
done). A done card is wrapped in `Opacity(0.55)` with a small `success` check.
There is no failed state and no red.

`QuranWirdCard` logs `kDailyWirdPages` through `QuranDao.upsert` on tap and shows
`KhatmaProgress.percentLabel`.

In `HomeScreen`, feed `ProgressRing` from `DailyItems.count(...)` using today's
logged prayers and the four wird completions.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/home/ test/features/quran/`
Expected: PASS (all)

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: add Qur'an wird, khatma progress, and the daily wird grid"
```

---

## Task 16: Reports — the deterministic 7-day summary

No AI, no network. Pure computation over DAO rows.

**Files:**
- Create: `lib/features/reports/weekly_summary.dart`
- Modify: `lib/features/reports/reports_screen.dart`
- Test: `test/features/reports/weekly_summary_test.dart`

**Interfaces:**
- Consumes: `PrayerDao.logsBetween`, `AthkarDao`, `QuranDao` (Task 4); `dailyPrayerAverage` (Task 11)
- Produces: `WeeklySummary.build({required List<DaySnapshot> days})` returning `WeeklySummary(days, prayerAverage, prayersLogged, wirdStreak, tasbeehTotal, quranPages)`; `DaySnapshot(date, prayerStates, morningDone, eveningDone, tasbeehCount, quranPages)`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/reports/weekly_summary_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/tables.dart';
import 'package:nouri/features/reports/weekly_summary.dart';

DaySnapshot day(int d, {
  List<PrayerState> states = const [],
  bool morning = false,
  bool evening = false,
  int tasbeeh = 0,
  int pages = 0,
}) =>
    DaySnapshot(
      date: DateTime(2026, 9, d),
      prayerStates: states,
      morningDone: morning,
      eveningDone: evening,
      tasbeehCount: tasbeeh,
      quranPages: pages,
    );

void main() {
  test('covers exactly seven days', () {
    final s = WeeklySummary.build(
        days: List.generate(7, (i) => day(i + 1)));
    expect(s.days.length, 7);
  });

  test('averages only the prayers that were logged', () {
    final s = WeeklySummary.build(days: [
      day(1, states: [PrayerState.mosque, PrayerState.none]),
      day(2, states: [PrayerState.onTime]),
    ]);
    expect(s.prayerAverage, closeTo(85.0, 0.01)); // (100 + 70) / 2
    expect(s.prayersLogged, 2);
  });

  test('a week with nothing logged has a null average, never zero', () {
    final s = WeeklySummary.build(days: [day(1), day(2)]);
    expect(s.prayerAverage, isNull);
    expect(s.prayersLogged, 0);
  });

  test('the wird streak counts consecutive days ending today', () {
    final s = WeeklySummary.build(days: [
      day(1, pages: 3), day(2, pages: 0), day(3, pages: 3),
      day(4, pages: 3), day(5, pages: 3),
    ]);
    expect(s.wirdStreak, 3, reason: 'days 3, 4, 5 — the break on day 2 ends it');
  });

  test('a streak broken today is zero, not the older run', () {
    final s = WeeklySummary.build(days: [
      day(1, pages: 3), day(2, pages: 3), day(3, pages: 0),
    ]);
    expect(s.wirdStreak, 0);
  });

  test('tasbeeh and pages accumulate across the week', () {
    final s = WeeklySummary.build(days: [
      day(1, tasbeeh: 100, pages: 3),
      day(2, tasbeeh: 33, pages: 6),
    ]);
    expect(s.tasbeehTotal, 133);
    expect(s.quranPages, 9);
  });

  test('an empty week produces a valid, empty summary rather than throwing', () {
    final s = WeeklySummary.build(days: const []);
    expect(s.days, isEmpty);
    expect(s.prayerAverage, isNull);
    expect(s.wirdStreak, 0);
    expect(s.tasbeehTotal, 0);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/reports/weekly_summary_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement the summary**

```dart
// lib/features/reports/weekly_summary.dart
import '../../data/db/tables.dart';
import '../prayers/prayer_scoring.dart';

class DaySnapshot {
  const DaySnapshot({
    required this.date,
    required this.prayerStates,
    required this.morningDone,
    required this.eveningDone,
    required this.tasbeehCount,
    required this.quranPages,
  });
  final DateTime date;
  final List<PrayerState> prayerStates;
  final bool morningDone, eveningDone;
  final int tasbeehCount, quranPages;
}

class WeeklySummary {
  const WeeklySummary({
    required this.days,
    required this.prayerAverage,
    required this.prayersLogged,
    required this.wirdStreak,
    required this.tasbeehTotal,
    required this.quranPages,
  });

  final List<DaySnapshot> days;

  /// Null when nothing was logged — an empty week has no score, it is not a zero.
  final double? prayerAverage;
  final int prayersLogged, wirdStreak, tasbeehTotal, quranPages;

  static WeeklySummary build({required List<DaySnapshot> days}) {
    final allStates = days.expand((d) => d.prayerStates).toList();
    final logged = allStates.where((s) => s != PrayerState.none).length;

    // Streak runs backwards from the most recent day and stops at the first gap.
    var streak = 0;
    for (final d in days.reversed) {
      if (d.quranPages > 0) {
        streak++;
      } else {
        break;
      }
    }

    return WeeklySummary(
      days: days,
      prayerAverage: dailyPrayerAverage(allStates),
      prayersLogged: logged,
      wirdStreak: streak,
      tasbeehTotal: days.fold(0, (a, d) => a + d.tasbeehCount),
      quranPages: days.fold(0, (a, d) => a + d.quranPages),
    );
  }
}
```

- [ ] **Step 4: Run it and see it pass**

Run: `flutter test test/features/reports/weekly_summary_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Build the screen**

`ReportsScreen` in the approved report language: two top cards (prayer average,
prayers logged), a seven-column day strip where each column shows the day's five
prayer chips as small coloured dots, then rows for the wird streak, tasbeeh total
and pages read. Under the header, a muted line stating plainly that this is a
local religious summary and that the full six-pillar report arrives later.

A day with nothing logged renders as empty dots — never red, never an ✗.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add the deterministic 7-day religious summary"
```

---

## Task 17: Settings, notification status panel and test notification

**Files:**
- Create: `lib/features/settings/notification_status_panel.dart`, `lib/features/settings/settings_controller.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Test: `test/features/settings/settings_controller_test.dart`

**Interfaces:**
- Consumes: `SettingsDao` (Task 4); `NotificationStatus`, `NotificationWarning` (Task 8); `RollingWindowScheduler` (Task 7)
- Produces: `SettingsController` with `updateLocation`, `updateMethod`, `updateMadhab`, `updateHijriOffset`, `updateIqamaOffset`, `updateTasbeehTarget`, `toggleChannel`, `sendTestNotification`, each returning after the window has been rebuilt

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/settings_controller_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/settings/settings_controller.dart';
import '../../support/fake_notification_gateway.dart';
import '../../support/recording_scheduler.dart';

void main() {
  late NouriDatabase db;
  late RecordingScheduler scheduler;
  late SettingsController controller;

  setUp(() {
    db = NouriDatabase.forTesting(NativeDatabase.memory());
    scheduler = RecordingScheduler();
    controller = SettingsController(db: db, scheduler: scheduler);
  });
  tearDown(() async => db.close());

  test('changing the calculation method reschedules the window', () async {
    await controller.updateMethod('ummAlQura');
    expect(scheduler.rearmCount, 1);
    expect((await db.settingsDao.get()).calculationMethod, 'ummAlQura');
  });

  test('changing an iqama offset reschedules the window', () async {
    await controller.updateIqamaOffset('maghrib', 25);
    expect(scheduler.rearmCount, 1);
    final offsets = (await db.settingsDao.get()).iqamaOffsets;
    expect(offsets['maghrib'], 25);
  });

  test('changing location reschedules the window', () async {
    await controller.updateLocation(latitude: 25.2048, longitude: 55.2708,
        cityLabel: 'دبي');
    expect(scheduler.rearmCount, 1);
  });

  test('toggling a notification channel reschedules the window', () async {
    await controller.toggleChannel('iqama', false);
    expect(scheduler.rearmCount, 1);
    expect((await db.settingsDao.get()).notifyIqama, isFalse);
  });

  test('changing the tasbeeh target does NOT reschedule', () async {
    await controller.updateTasbeehTarget(300);
    expect(scheduler.rearmCount, 0,
        reason: 'the tasbeeh target has no bearing on alarms');
    expect((await db.settingsDao.get()).tasbeehTarget, 300);
  });

  test('the Hijri offset is clamped to plus or minus one day', () async {
    await controller.updateHijriOffset(5);
    expect((await db.settingsDao.get()).hijriOffsetDays, 1);
    await controller.updateHijriOffset(-9);
    expect((await db.settingsDao.get()).hijriOffsetDays, -1);
  });
}
```

Create `test/support/recording_scheduler.dart` — a stub exposing `rearmCount`
that implements the same `rearm(SchedulingConfig)` signature.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/settings/settings_controller_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement the controller**

Every mutator writes through `SettingsDao`, then calls `scheduler.rearm` — except
`updateTasbeehTarget`, which does not affect alarms. The Hijri offset clamps to
`[-1, 1]`. This satisfies the spec's requirement that any change to location,
method, timezone, offsets or notification preferences rebuilds the window.

- [ ] **Step 4: Build the settings screen**

Sections, all MSA labels: **الموقع** (city, detect-location button, method,
madhab) · **الصلاة** (five iqama offsets, Hijri offset) · **الإشعارات** (four
channel toggles, adhan sound mode) · **التسبيح** (target) · **القرآن** (khatma
length) · **اللغة** (ar/en).

- [ ] **Step 5: Build the notification status panel**

At the top of الإشعارات, a card showing three plain rows — الإشعارات مفعّلة /
التنبيهات الدقيقة مسموحة / نوري مستثنى من توفير البطارية — each with a
`success` tick or an `attention` dot and a button that opens the relevant system
settings page. Below them:

- When `status.mode == NotificationMode.inexact`, a plainly-worded line stating
  that exact alarms are unavailable on this device and the adhan may arrive a few
  minutes late. It states the limitation; it does not apologise or alarm.
- A **«إرسال إشعار تجريبي»** button calling `sendTestNotification()`, which fires
  immediately on the `general_v1` channel.
- A short battery-optimisation guide: open system settings → Battery → unrestricted,
  with a note that some manufacturers hide this under a separate power manager.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/settings/`
Expected: PASS (6 tests)

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add settings, notification status panel, and test notification"
```

---

## Task 18: First-launch permission flow

**Files:**
- Create: `lib/features/onboarding/permission_flow.dart`
- Modify: `lib/app.dart`, `lib/features/settings/settings_screen.dart`
- Test: `test/features/onboarding/permission_flow_test.dart`

**Interfaces:**
- Consumes: `SettingsDao.onboardingComplete` (Task 4); `NotificationStatus` (Task 8)
- Produces: `PermissionFlow` — three skippable steps, marking `onboardingComplete` when finished or skipped

- [ ] **Step 1: Write the failing test**

```dart
// test/features/onboarding/permission_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/onboarding/permission_flow.dart';

void main() {
  Future<void> pump(WidgetTester t) => t.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: PermissionFlow(onDone: () {}),
        ),
      ));

  testWidgets('every step can be skipped', (t) async {
    await pump(t);
    expect(find.text('تخطّي'), findsOneWidget);
  });

  testWidgets('each step explains why in one plain sentence', (t) async {
    await pump(t);
    expect(find.textContaining('عشان'), findsWidgets);
  });

  testWidgets('no step blocks progress or shows an error state', (t) async {
    await pump(t);
    expect(find.byIcon(Icons.error), findsNothing);
    expect(find.byIcon(Icons.block), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/onboarding/permission_flow_test.dart`
Expected: FAIL — URI does not exist

- [ ] **Step 3: Implement the flow**

Three pages in order — **notifications** (Android 13+ runtime permission),
**battery optimisation exemption**, **location** — each with the gold نوري
avatar, one colloquial sentence of *why*, a primary button and a «تخطّي» link.
Skipping is always allowed: without location Nouri uses Kuwait, without
notifications it still tracks everything in-app. The app degrades; it never
blocks. Shown only when `onboardingComplete` is false, and re-runnable from
Settings.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/onboarding/permission_flow_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: add the first-launch permission flow"
```

---

## Task 19: Build, install and verify on the phone

The slice is not done when the tests pass. It is done when the adhan fires on the
user's phone with the app closed.

**Files:**
- Create: `docs/install.md`
- Modify: `android/app/build.gradle.kts` (release signing)

**Interfaces:**
- Consumes: everything
- Produces: a release APK and a written on-device verification record

- [ ] **Step 1: Run the whole suite**

Run: `flutter test`
Expected: PASS, every test, zero skips. Do not proceed past a failure.

- [ ] **Step 2: Analyse**

Run: `flutter analyze`
Expected: no issues. Fix anything reported before building.

- [ ] **Step 3: Build the release APK**

```bash
flutter build apk --release
```
Expected: `build/app/outputs/flutter-apk/app-release.apk` exists.

- [ ] **Step 4: Install on the device**

```bash
adb devices              # the phone must be listed
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 5: Grant permissions on the device**

Notifications allowed · Alarms & reminders allowed · Battery set to Unrestricted.
Confirm the Settings status panel shows three ticks.

- [ ] **Step 6: Verify end to end — the real acceptance test**

Work through this list on the phone and record the result of each in
`docs/install.md`:

- [ ] Prayer times match the local Kuwait timetable for today (within a minute or two)
- [ ] «إرسال إشعار تجريبي» fires immediately
- [ ] The adhan notification fires at the next prayer **with the app swiped away**
- [ ] The iqama notification follows at the configured offset
- [ ] The «صليت» action on the follow-up logs the prayer without opening the app
- [ ] Tapping a prayer row opens the sheet and logging updates the Home ring
- [ ] The tasbeeh counts, persists across an app kill, and resets cleanly
- [ ] Athkar progress survives leaving the screen mid-set
- [ ] The Qur'an wird logs and the khatma percentage advances
- [ ] The Reports tab shows the last seven days
- [ ] The Finance tab reads as a calm promise, not a broken screen
- [ ] Rebooting the phone and waiting for the next prayer still fires the adhan
- [ ] Airplane mode changes nothing — the whole app works offline

- [ ] **Step 7: Write the install document**

`docs/install.md` records: the build command, the adb install command, the three
permissions and where they live on this phone, the battery-optimisation steps, and
the completed verification list with dates.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "docs: add build, install, and on-device verification record"
```

---

## Plan Self-Review

Checked after writing, against the spec.

**Spec coverage**

| Spec section | Task |
|---|---|
| §3 Architecture, folders, stack | 1, 2, 3, 9 |
| §4 Data model, athkar asset schema, verification sheet | 4, 12 |
| §5 Prayer engine, Kuwait fallback, Hijri offset, iqama offsets | 5 |
| §6 Channels, rolling window, deterministic IDs, three re-arm triggers | 6, 7, 8 |
| §6 Status screen · test notification · battery guidance · exact-alarm fallback · reschedule on change | 8, 17 |
| §6 Prayer follow-up «صليت» action | 7 (copy), 8 (action), 11 (handler) |
| §6 First-launch permission flow | 18 |
| §7 Scoring ladder, ring as a count of nine, never red | 4, 10, 11 |
| §8 Home | 10, 11, 15 |
| §8 Athkar & tasbeeh | 13, 14 |
| §8 Reports (deterministic) | 16 |
| §8 Finance placeholder | 9 |
| §8 Settings | 17 |
| §9 Testing strategy | every task; the guard test in 4 |
| §10 Build, permissions, install | 1, 8, 19 |

No spec requirement is unassigned.

**Type consistency**

`PrayerState` (Task 4) is the single state type used in Tasks 11, 16.
`PrayerSlot` / `DailyPrayerTimes` (Task 5) are consumed unchanged in Tasks 7, 10.
`NotificationSlot` and `notificationIdFor` (Task 6) are used only in Task 7.
`NotificationGateway` (Task 6) has exactly one production implementation (Task 8)
and one fake (Task 7), with matching signatures.
`dailyPrayerAverage` (Task 11) is reused by `WeeklySummary` (Task 16).
`DailyItems.count` (Task 10) is fed by Task 15.
`SchedulingConfig` (Task 7) is what `SettingsController` rebuilds (Task 17).

**Placeholder scan**

No TBD, no "handle edge cases", no "similar to Task N". Where a step describes a
widget rather than showing its code, the exact tokens, sizes, order and colour
roles are given, and the widget's behaviour is pinned by a test whose code is
written out in full.

---

## Execution Handoff

Plan complete. Two execution options:

**1. Subagent-Driven (recommended)** — a fresh subagent per task, reviewed between tasks, fast iteration.

**2. Inline Execution** — tasks executed in this session with batch checkpoints.
