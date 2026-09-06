# Nouri — build, install, and on-device verification

> ## ⚠ Build before you install
>
> The APK currently sitting in `build/app/outputs/flutter-apk/` was built at
> **01:23 on 6 Sep** and is **four commits stale**. It does *not* contain the
> device-location wiring or the 14-day alarm window, both of which landed at
> ~05:20. There is **no release APK at all** — that build was interrupted.
>
> **Run `flutter build apk --debug` (or `--release`) before installing**, or you
> will be testing older code and wondering why Settings → المدينة → حدّد does
> nothing.
>
> Nothing is wrong with the build; it was simply stopped part-way.

## Building

```powershell
$env:PATH = 'D:\dev-tools\flutter\bin;' + $env:PATH
cd E:\cloud\noury

flutter build apk --debug      # build\app\outputs\flutter-apk\app-debug.apk
flutter build apk --release    # build\app\outputs\flutter-apk\app-release.apk
```

The debug APK is large (~175 MB) because debug builds bundle every ABI and skip
minification. It is fully functional — use it if the release build gives
trouble.

**The release build signs with debug keys**, the Flutter template default
(`signingConfig = signingConfigs.getByName("debug")` in
`android/app/build.gradle.kts`). Fine for sideloading onto your own phone. Worth
knowing: an app installed with debug keys cannot later be upgraded in place by
one signed with release keys — you would have to uninstall first, which erases
the database.

## Installing

```powershell
adb devices                    # the phone must be listed before anything else
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

`-r` reinstalls while keeping app data. Drop it (or `adb uninstall com.nouri.nouri`
first) only when you deliberately want a clean slate — it erases every logged
prayer, athkar count and wird.

## Permissions the app needs

| Permission | Why | Android 12 (your HONOR) |
|---|---|---|
| Notifications | to show anything at all | granted at install; runtime prompt only on Android 13+ |
| Alarms & reminders | to fire the adhan at the exact minute | granted at install via `USE_EXACT_ALARM` |
| Battery: unrestricted | to survive Doze and OEM power management | **must be set by hand** |

Settings → الإعدادات → حالة التنبيهات shows the live state of all three and
offers a one-tap route to each. It also sends a test notification.

## HONOR/MagicOS specifics

HONOR is among the most aggressive Android skins at killing background apps, and
standard battery-optimisation exemption alone is often **not** enough.

1. **Settings → Battery → App launch** → find نوري → switch from *Manage
   automatically* to **Manage manually** → enable all three:
   Auto-launch, Secondary launch, Run in background.
   *This is the step that most often decides whether the adhan is still working
   two days later.*
2. **Settings → Apps → نوري → Battery → No restrictions.**
3. **Settings → Apps → نوري → Alarms & reminders** → allowed.
   (If not visible: Apps → ⋮ → Special access → Alarms & reminders.)

## Verification checklist

Record the outcome next to each item as you go.

### Verified on the emulator (API 31, matching the phone's Android version)

| # | Check | Result |
|---|---|---|
| 1 | App installs and launches | ✅ |
| 2 | Permission flow appears on first launch, all steps skippable | ✅ |
| 3 | Arabic renders in Cairo; athkar in Amiri with full tashkeel | ✅ |
| 4 | RTL throughout — nav starts at the right | ✅ |
| 5 | Navy/gold theme; no red anywhere | ✅ |
| 6 | Hijri date in the header | ✅ |
| 7 | Progress ring in Arabic-Indic digits | ✅ `٠/٩` → `١/٩` |
| 8 | Five prayers listed with times | ✅ |
| 9 | Tapping a prayer opens the logging sheet | ✅ |
| 10 | Chips gold / green / muted / orange | ✅ |
| 11 | Logging updates the ring immediately | ✅ |
| 12 | **A logged prayer survives force-stop + relaunch** | ✅ |
| 13 | Tasbeeh counts and fills the bead ring | ✅ |
| 14 | Settings shows live permission state | ✅ correctly flagged battery optimisation |
| 15 | «إرسال إشعار تجريبي» posts a notification | ✅ |
| 16 | All five notification channels created | ✅ |
| 17 | **Alarm window actually armed** | ✅ 130 exact alarms (7-day window at the time), `window=0`, `exactAllowReason=permission` |
| 18 | Scheduled times match displayed prayer times | ✅ after the UTC fix — see `docs/setup.md` |
| 19 | Reports shows «—» not a zero for an empty week | ✅ |
| 20 | No crashes in logcat | ✅ |

### Still to do on the HONOR VNE-N41

None of these are verifiable on an emulator. **Nothing below has been tested.**

| # | Check | Result |
|---|---|---|
| 21 | Prayer times match your local Kuwait timetable (±1–2 min) | ☐ |
| 22 | Test notification arrives | ☐ |
| 23 | **The adhan fires at the right minute with the app swiped away** | ☐ |
| 24 | The chime plays (not silent) | ☐ |
| 25 | The iqama notification follows at the configured offset | ☐ |
| 26 | «صليت» on the follow-up logs the prayer without opening the app | ☐ |
| 27 | **After a reboot**, the next adhan still fires without opening the app | ☐ |
| 28 | **After a full day untouched**, notifications are still arriving | ☐ |
| 29 | **After several days untouched** — catches OEM battery-kill | ☐ |
| 30 | Airplane mode changes nothing (the app makes no network calls) | ☐ |
| 31 | Location detection in Settings → المدينة → حدّد | ☐ |

If 21 is off by more than a minute or two, change the calculation method in
Settings → مواقيت الصلاة → طريقة الحساب.

If 23 or 27 fail, the cause is almost always the HONOR App launch setting above,
not the app.

## Useful commands

```powershell
# what is actually armed
adb shell dumpsys alarm | Select-String "com.nouri.nouri" -Context 0,2

# notifications currently posted
adb shell cmd notification list

# live app logs
adb logcat -s flutter:V AndroidRuntime:E
```

The `origWhen=` values in the first command should match the prayer times the
app displays, rendered in the device's local timezone. A mismatch there is the
bug described under "Timezone handling" in `docs/setup.md`.
