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
| 35 | **After a reboot**, the next adhan still fires without opening the app | ☐ on the phone — ✅ on the emulator, see check 57 |
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

---

### Slice 1b — the five features added on 7 September 2026

None of these has ever run on this phone. Checks 51 and 52 are the ones that
can only be answered here: the emulator has no step-counter hardware at all.

| # | Check | ✅ |
|---|-------|----|
| 48 | The calendar icon in the Home header opens التقويم, Saturday-first | ☐ |
| 49 | A reminder saved for two minutes out **fires with the screen locked** | ☐ |
| 50 | After changing any setting, the reminder is **still** armed — see below | ☐ |
| 51 | البدن → «امشي» offers a start button rather than «مافيهوش حسّاس خطوات» | ☐ |
| 52 | A real walk counts steps, and the distance is believable against a map | ☐ |
| 53 | البدن → «تمارين البيت» animates the figure, and rest names what is next | ☐ |
| 54 | Finishing a workout early still records «٥ من ٢٠» | ☐ |
| 55 | التقارير → التحديات joins a challenge and counts today once it qualifies | ☐ |
| 56 | الأذكار → الصباح shows آية الكرسي and الإخلاص as mushaf pages | ☐ |

**Check 50 is the important one.** Re-arming the window used to call
`cancelAll()`, which would have deleted every reminder on the device. Add a
reminder, then toggle any switch under الإشعارات, then confirm the reminder
alarm is still there:

```powershell
adb shell dumpsys alarm | Select-String "com.nouri.nouri" -Context 0,2
```

A reminder's alarm is an `RTC_WAKEUP` whose `origWhen=` is the reminder's own
date and time. It must survive the toggle. Verified on the emulator; not here.

---

### Verified on the emulator, 10 September 2026 (nourdm-api35, Android 15)

The four things every previous version of this file had to leave open. All on
the emulator; **none of it has been repeated on the HONOR**, where MagicOS's
own power management is the variable an emulator cannot speak for.

| # | Check | Result |
|---|-------|--------|
| 57 | **After a reboot, the alarms are still armed** — app never opened | ✅ 289 in, 289 out, `diff` of every `origWhen` empty, all still `window=0 exactAllowReason=policy_permission`. Restored within ~90s of `BOOT_COMPLETED`. Repeated on the 10 Sep build: 287 → 287, identical. |
| 58 | **A restored alarm actually fires** — app still never opened | ✅ `11:45:00.006 id=156419 channel=adhan_dhuhr_v3d importance=5 flags=INSISTENT|AUTO_CANCEL|HIGH_PRIORITY category=alarm` |
| 59 | **An alarm arrives in deep Doze**, with Nouri *not* on the deviceidle whitelist | ✅ `mState=IDLE`, screen off, battery unplugged → `12:00 id=156484 channel=alert_iqama_v3` |
| 60 | **The day turning over** re-anchors the window and orphans nothing | ✅ `09-10 11:45 → 09-24 01:32` became `09-11 11:45 → 09-25 01:32`, 290 alarms, no 09-10 alarm left behind |
| 61 | **Force-stop still heals on the next launch**, after the re-arm change | ✅ 0 → 71 → 121 → 176 → 224 → 281 → 290 |
| 62 | **A launch no longer empties the alarm list first** | ✅ was 290 → 13 over ~10s; now flat at 290 across thirty samples, producing an identical window |
| 63 | **28 channels live, 35 retired ones deleted** after the `channelWorkFor` change | ✅ 5 adhan `_v3d` + 19 task tones + `athkar_v1`, `wird_v1`, `general_v1` |
| 64 | **الملف الشخصي → the photo picks, stores, renders and clears** | ✅ `PhotoPickerGetContentActivity` opens saying "This app can only access the photos you select"; stored as `files/profile-<ms>.png` (27 KB); × removed it and left `snoozes.json` untouched |

To reproduce 57 and 58, note the two traps that make a false negative easy:

- **Do not `force-stop` and then conclude anything from the first dump.** The
  restore runs a little after `BOOT_COMPLETED`; at +5s the count was 0 and at
  +90s it was 289.
- **`adb shell date -s` wants `MMDDhhmm[[CC]YY][.ss]`.** `date -s "2026-09-10
  11:44:30"` is rejected as "two dates at once", and `date -s 20260910.114430`
  silently lands in 2010.

**Check 51 decides the shape of the feature.** If the HONOR reports no step
sensor, the walk screen is honest about it and the feature needs the
foreground-service design instead — do not treat the message as a bug.

Steps are read only while the walk screen is open. Android keeps counting in
the OS, so backgrounding the app and coming back reconciles correctly, but
killing the app loses the session. That is a known limit, not check 52 failing.
