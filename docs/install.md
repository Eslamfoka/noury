# Nouri — build, install, and on-device verification

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

### Verified on the HONOR VNE-N41 (Android 12, Asia/Kuwait)

| # | Check | Result |
|---|---|---|
| 21 | Installed and launches | ✅ |
| 22 | Notifications + exact alarms granted at install | ✅ `SCHEDULE_EXACT_ALARM granted=true` |
| 23 | HONOR App launch set to manual, all three toggles on | ✅ (set by hand; not adb-readable) |
| 24 | Exempt from battery optimisation | ✅ in `deviceidle whitelist`, not background-restricted |
| 25 | 14-day window armed on the real device | ✅ **262 alarms**, all `window=0`, `exactAllowReason=permission` |
| 26 | Alarm times match Kuwait prayer times | ✅ 11:46 / 15:18 / 18:04 / 19:23 + correct iqama offsets |
| 27 | Instant test notification | ✅ |
| 28 | Adhan channel carries the chime at alarm volume | ✅ audibly louder and longer than a normal beep |
| 29 | **Scheduled adhan fires with the app swiped away and screen locked** | ✅ **posted at 08:49:43 for 08:49:43** |
| 30 | Swiping from Recents does **not** cancel alarms | ✅ 262 → 262, `stopped=false` |

**Note:** `Settings → Force stop` *does* cancel every alarm (`262 → 0`) and puts the
app in `stopped=true`, where it receives no broadcasts at all. That is standard
Android behaviour, not specific to Nouri. Swiping from Recents is safe; force-stopping
is not. After a force-stop, opening Nouri once re-arms everything.

### Still to do on the HONOR VNE-N41

**Nothing below has been tested** — each needs real elapsed time.

| # | Check | Result |
|---|---|---|
| 31 | Prayer times match your printed Kuwait timetable (±1–2 min) | ☐ |
| 32 | A **real** adhan fires at dhuhr/asr/maghrib/isha | ☐ |
| 33 | The iqama notification follows at the configured offset | ☐ |
| 34 | «صليت» on the follow-up opens the log sheet for that prayer | ☐ |
| 35 | **After a reboot**, the next adhan still fires without opening the app | ☐ |
| 36 | **After a full day untouched**, notifications still arrive | ☐ |
| 37 | **After several days untouched** — catches OEM battery-kill | ☐ |
| 38 | Airplane mode changes nothing (the app makes no network calls) | ☐ |
| 39 | Location detection in Settings → المدينة → حدّد | ☐ |

### After the adhan_v2 change (test these first)

The adhan channel was recreated as `adhan_v2`. The old `adhan_v1` on this phone
had its importance locked to DEFAULT by MagicOS, which no API can undo — see
`docs/setup.md`. These confirm the new channel came up clean.

| # | Check | ✅ |
|---|-------|----|
| 40 | Settings → Apps → Nouri → Notifications lists **الأذان** (not `adhan_v1`) | ☐ |
| 41 | Only **one** الأذان row — the old channel was deleted, not left behind | ☐ |
| 42 | Its importance is not reduced; it may show as «عاجل» / heads-up | ☐ |
| 43 | «جرّب الأذان بعد دقيقتين» still plays the chime at alarm volume | ☐ |
| 44 | With the screen **locked**, the test adhan lights the screen | ☐ |
| 45 | Tapping a follow-up opens the log sheet for that prayer | ☐ |
| 46 | The 22:00 summary opens the review sheet listing unlogged prayers | ☐ |
| 47 | Home shows «… لسه متسجلتش» when a past prayer is unlogged | ☐ |

Check 44 is the point of the change: on `adhan_v1` the locked importance meant
the adhan could only wait silently in the shade.

**Verified on the HONOR VNE-N41, 6 September 2026.** MagicOS re-locked the new
channel within seconds of creation — `mImportance=4 mOriginalImp=5
mUserLockedFields=4` — so a version bump resets the lock but does not defeat it,
and `adhan_v2` sits at HIGH rather than MAX. HIGH is the threshold that matters:
Android only fires a full-screen intent at HIGH or above, and the device honoured
it (`sending fullScreenIntent, entry.importance=4`). The screen lit, the adhan
sounded, the notification appeared **on the lock screen**, and the app itself
opened only after unlocking.

Expect a future channel bump to land at HIGH again. That is a device policy, not
a bug, and HIGH is sufficient.

To confirm the channel state from a computer:

```powershell
adb shell dumpsys notification | Select-String "adhan_v"
```

Expect `mId='adhan_v2'` with `mImportance=5` and `mUserLockedFields=0`, and
`adhan_v1` either absent or `mDeleted=true`. If `adhan_v2` shows a lower
importance with `mUserLockedFields` set, MagicOS has downgraded it again —
that is worth knowing, and it is a device-policy problem rather than a bug.

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
