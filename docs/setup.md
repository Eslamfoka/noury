# Nouri — development environment

Everything below reflects the machine this project was set up on, verified on
2026-09-05. If you are reproducing on a new machine, follow the same shape.

## Toolchain (already present on this machine)

| Component | Location | Version |
|---|---|---|
| Flutter SDK | `D:\dev-tools\flutter` | 3.44.6, channel stable |
| Dart | bundled with Flutter | 3.12.2 |
| Android SDK | `D:\dev-tools\android-sdk` | platforms 34 / 35 / 36, build-tools 36.0.0, NDK, emulator |
| JDK | system | 17.0.19 (Microsoft) |
| adb | `D:\dev-tools\android-sdk\platform-tools\adb.exe` | 1.0.41 |
| Git Credential Manager | `C:\Program Files\Git\mingw64\bin` | configured system-wide |

`ANDROID_HOME` is already set to `D:\dev-tools\android-sdk`.

**Flutter is not on the system PATH.** Either add it once:

```powershell
[Environment]::SetEnvironmentVariable('Path', $env:Path + ';D:\dev-tools\flutter\bin', 'User')
```

or prefix each shell session:

```powershell
$env:PATH = 'D:\dev-tools\flutter\bin;' + $env:PATH
```

Every command in this file assumes one of the two has been done.

## One-time configuration

```powershell
flutter config --android-sdk D:\dev-tools\android-sdk
flutter doctor
```

`flutter doctor` must report **No issues found!** before you build. If it asks
for Android licences, run `flutter doctor --android-licenses` and accept them.

## Daily commands

```powershell
flutter test                 # the whole suite
flutter test test/path/to/file_test.dart
flutter analyze              # must be clean before any commit that ships code
flutter run                  # debug build on the connected device
flutter build apk --release  # release APK
```

Generated code (drift, localizations) is rebuilt with:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

## Project facts worth knowing

- **Application ID:** `com.nouri.nouri`
- **minSdk 26 / targetSdk 35 / compileSdk 37**, set explicitly in
  `android/app/build.gradle.kts` — not inherited from the Flutter defaults.
- **`pubspec.lock` is committed.** Nouri is an application, not a library; the
  lockfile keeps builds reproducible.
- **Slice 1 makes no network requests.** `test/guard/no_network_test.dart` fails
  the build if a network package or an HTTP call appears in `lib/`.

## Fonts

Bundled under `assets/fonts/`, both SIL Open Font License (licence texts are
committed alongside them):

- `Cairo-Variable.ttf` — all interface text. Cairo ships from Google Fonts as a
  **variable font only** (`wght` and `slnt` axes); there are no static weights.
  Declaring the same file under several `weight:` keys in `pubspec.yaml` does not
  work — Flutter would select the file but render its default instance, so bold
  would come out regular. Weight is therefore applied through an explicit
  `FontVariation('wght', …)`, via the `cairo()` helper in
  `lib/core/theme/nouri_theme.dart`. **Never build a Cairo `TextStyle` by hand.**
- `Amiri-Regular.ttf`, `Amiri-Bold.ttf` — athkar and Qur'an text only. Static
  weights, so no axis handling needed.

## Adhan sound

The app ships a short, calm chime. To use a real adhan or takbir recording
instead:

1. Put the file at `android/app/src/main/res/raw/adhan.mp3` (Android resolves
   channel sounds from `res/raw`, not from Flutter assets — lowercase name, no
   dashes).
2. Bump the adhan channel ID from `adhan_v1` to `adhan_v2` in
   `lib/core/notifications/notification_channels.dart` and point it at the new
   resource.

The version bump is required, not optional: Android freezes a channel's sound at
creation time and ignores later changes to the same channel ID.

## Device testing

```powershell
adb devices                  # the phone must appear here first
flutter run                  # debug, hot reload
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

On the phone, three permissions must be granted for prayer notifications to be
reliable — Notifications, Alarms & reminders, and Battery set to Unrestricted.
The app's Settings screen shows the live state of all three and can send a test
notification. See `docs/install.md` for the full on-device checklist.

## Timezone handling (important)

Notifications are scheduled in **UTC**, deliberately — see `_asUtc` in
`lib/core/notifications/local_notification_gateway.dart`.

`flutter_local_notifications` serialises a schedule as a wall-clock string plus
a zone name, and the Android side rebuilds the instant using **its own** tz
database. That round trip is only safe when both databases agree on that zone's
rules for that date, and they frequently do not: OEM images ship stale tzdata
and the Dart `timezone` package updates on its own cadence.

This was observed concretely during development. With the device on
Africa/Cairo, the app displayed Fajr at 03:07 while `dumpsys alarm` showed the
alarm armed for **04:07** — the Dart package knew Egypt observes DST in
September 2026, the Android image did not.

UTC has no transitions for the two sides to disagree about, so the instant
survives intact. This is safe only because every notification is scheduled
individually; `matchDateTimeComponents` (repeating schedules) would need a real
local zone and must not be introduced without revisiting this.

To verify on a device:

```powershell
adb shell dumpsys alarm | Select-String "com.nouri.nouri" -Context 0,2
```

The `origWhen=` values should match the prayer times the app displays, rendered
in the device's local timezone.

## Why there is no background top-up task

The approved spec called for three independent re-arm triggers: app resume,
device boot, and a **daily background top-up** via `workmanager`. Two are
implemented. The third was deliberately **not** added, and the alarm window was
widened from 7 days to 14 instead.

The reasoning, so this can be overruled knowingly rather than rediscovered:

- The top-up exists to stop the alarm window running dry while the app goes
  unopened. Exact alarms live in Android's `AlarmManager` and fire **without the
  app running at all**, so simply arming more of them achieves the same end.
- A `workmanager` periodic task is exactly the kind of background execution that
  aggressive OEM power managers kill first. HONOR/MagicOS — the target device —
  is among the worst for this. A top-up that silently stops running is worse
  than no top-up, because it produces false confidence.
- A day costs **19 alarms** (five prayers × adhan/iqama/follow-up, plus three
  athkar and the wird), measured on-device via `dumpsys alarm`. Fourteen days is
  about 260, comfortably inside Android's ~500 pending-alarm cap.
  `rolling_window_scheduler_test.dart` pins that budget, so widening the window
  further fails a test rather than silently exceeding the cap.
- The background isolate a top-up requires needs its own plugin registration and
  database handle, and is the hardest part of Flutter to debug — real cost for a
  redundancy that the OS may refuse to run.

**Net effect:** the app can go a fortnight unopened without the adhan going
quiet, versus a week before. If Nouri is opened even once a fortnight — and it
is a daily companion — the window never depletes.

Add `workmanager` if a fortnight proves insufficient in practice. It is a
supplement to this, not a replacement for it.
