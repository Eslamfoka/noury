# The night the alarms stopped vanishing · 10 September 2026

Follows `2026-09-10-the-phone-takes-the-night-work.md`. You said to keep going
on whatever did not need you, to use the emulator, and to do as much as I
could rather than one thing. This is what happened.

**1199 tests passing**, `flutter analyze` clean, schema **v13** (unchanged —
nothing tonight needed a migration). Branch `slice1-religious-core`, two
commits, still **not merged to `master`**.

**Your phone was not touched.** Everything below is the emulator
(`nourdm-api35`, Android 15).

Four things I deliberately did **not** do, because they are yours:
`INTERNET`, listening to the adhans and the tones, granting
`ACTIVITY_RECOGNITION`, and the two religious-content reviews.

---

## The headline: every time you opened Nouri, your alarms nearly all disappeared

This was not on any list. It came out of measuring the thing STATUS called
"worth an hour sometime".

The app is armed with a fortnight of alarms. It is not running. You open it.
Sampling the number of alarms AlarmManager actually holds, once a second:

```
before launch:  290 alarms armed
t=1s   286  280  273  267  260
t=2s   253  245  238  232  224
t=3s   216  209  202  193  185  177
t=4s   169  160  151  141  131
t=5s   120  106   92   77   64   43
t=6s    20   13          ← lowest point
t=14s  290
```

**For about ten seconds of every single launch, between 82% and 99% of your
adhan alarms did not exist.** An earlier run bottomed out at 4. Anything that
killed the process in that window — an OEM power manager, memory pressure, a
reboot at the wrong moment — would have left you with almost nothing armed
until the next time you opened the app, and nothing anywhere would have said
so.

`docs/install.md` names HONOR as among the most aggressive Android skins at
killing background apps. That is the device this happens on.

### Why it was doing that

`rearm` cleared its whole ID range and then wrote all of it back: ~265 cancels
followed by ~265 schedules, most of them of the same IDs.

**Half of that was never needed.** Scheduling an ID that is already pending
*is* a cancel — `AlarmManager.setExactAndAllowWhileIdle` cancels whatever alarm
is held under an equal PendingIntent before setting the new one, and the plugin
builds that PendingIntent from the notification ID as its request code with
`FLAG_UPDATE_CURRENT`. I read that in the plugin's source rather than assuming
it.

So the pass now computes the window it wants first, cancels only the IDs that
window does *not* contain, and writes the rest over the top.

```
before launch:  290 alarms armed
t=0s   290  290  290
t=1s   290  290  290  290
...
t=6s   290  290  290        ← flat, thirty samples, never dips
```

**Same window, exactly.** All 290 alarms, the same times to the second, the
same `window=0 exactAllowReason=policy_permission`. `diff` of the two lists is
empty.

**And recovery is unchanged**, which was the thing to be careful about. Every
wanted alarm is still written unconditionally on every call, so a force-stop
still heals on the next launch — measured on the new build: `0 → 71 → 121 →
176 → 224 → 281 → 290`.

### What it is *not*, which I got wrong first

I wrote in the commit message that this also explains why the pass is slow, and
pointed at the 42s cold-emulator / 11.7s HONOR figures. **That is wrong, and
measuring it is what showed me.**

Debug builds of both, `NOURI_STARTUP armWindow`, four quiet runs each on the
same emulator:

```
baseline   24855   24381   24536   23759 ms
fixed      26358   24411   23303   23134 ms
```

No difference worth the word. The ~265 cancels cost almost nothing in wall
clock; the ~287 *schedules* are the whole of the time, and this change does not
touch them. The plugin really does rewrite its entire boot cache per operation,
so the pass really is quadratic — but at this window size the constant is small
enough that halving the operation count buys nothing measurable.

So: **this is a robustness fix, not a performance one.** The value is that the
alarms are never absent, not that the pass got shorter. The `perf:` prefix on
the commit is the wrong label; the commit body's timing claim is wrong. I am
leaving the commit alone rather than rewriting a pushed branch, and correcting
it here, which is where the next person looks.

One thing measuring the dip taught me about measuring the dip: `dumpsys alarm`
takes a lock the cancel loop is contending for, so sampling it hard makes the
decline *look* longer than it is. Under heavy sampling the baseline's decline
spanned ~14s of a 32s `armWindow`; quiet, the same pass is 24s. The depth of
the hole is solid — 290 → 13 in release, 289 → 7 in debug, reproduced on both
builds — but **do not trust any duration I could only see by observing it.**

Two smaller things on the same path, in the same commit:

- Startup asked `readStatus`, which answers four questions across four platform
  round-trips. Three of them exist for the settings panel — whether
  notifications are on, whether the battery optimiser still holds Nouri, how
  the adhan channels stand against DND — and none changes what gets scheduled.
  `readMode` is the one question that does. Measured: `readStatus` 1532–2686ms
  became `readMode` 1265–1426ms. Real, and much smaller than the 5.5s the last
  handoff saw — that number was from a *cold-booted* emulator and I did not
  reproduce it on a warm one.
- `init` deleted all 33 retired channel IDs and created all ~30 current ones on
  every launch, **before the first frame**, and from the second launch onward
  every one of those was a no-op. One read of what the device already holds
  replaces them. `pluginInit` 1164–1668ms became 1115–1150ms — again real and
  again small. Both of these are worth having on their own terms; neither is
  the reason the app takes a moment to settle.

---

## Reboot survival, which had never been tested

Check 35 in `docs/install.md`, open since the first install. It works.

289 alarms armed. Reboot. **The app was never opened.** Ninety seconds after
`BOOT_COMPLETED`:

```
before: 289 alarms     after: 289 alarms
diff of every single origWhen: identical
exactness: 289 × window=0 exactAllowReason=policy_permission, before and after
```

Not "the right number" — the *same alarms*, at the same seconds, still exact.

It also survived something stronger than the plain case. I force-stopped the
app before rebooting, which normally means it receives no broadcasts at all.
After the reboot the package was out of the stopped state and everything came
back anyway.

### And one of those restored alarms actually fired

The part every previous handoff had to leave open. With the app still never
opened, I moved the clock to a minute before the next prayer and watched:

```
11:45:00.006  id=156419  channel=adhan_dhuhr_v3d  importance=5
              flags=INSISTENT|AUTO_CANCEL|HIGH_PRIORITY  category=alarm
```

Reboot → restored by the boot receiver → fired at its exact second → posted on
the bypassing channel, at alarm importance, looping. The whole chain, with
nobody having opened Nouri since the reboot.

---

## Doze, also never tested

`setExactAndAllowWhileIdle` is supposed to survive Doze. Nobody had watched it.

Deep idle (`mState=IDLE`), screen off, battery unplugged, and Nouri
**not** on the deviceidle whitelist — the harder case, the one that applies to
a user who never granted the battery exemption:

```
12:00  id=156484  channel=alert_iqama_v3  importance=4  category=reminder
```

The iqama arrived, in Doze, on its own tone.

---

## The day turning over

You work nights, so this one matters more here than it would elsewhere. Clock
forward to the next day, open the app:

```
window before:  09-10 11:45  →  09-24 01:32
window after:   09-11 11:45  →  09-25 01:32
290 alarms, and not one 09-10 alarm left behind
```

Fourteen days, correctly re-anchored, nothing orphaned. The far end is 01:32 on
the fifteenth date because قيام belongs to the night that *starts* on the
fourteenth — which is the design, not a fencepost error.

---

## الصورة الشخصية

The one thing on الملف الشخصي that was still answering with a promise —
«لسه مش متفعّلة». It picks now.

- The **system photo picker**, so **no permission is requested and none is
  declared**. It hands back exactly the one image you chose and gives Nouri
  access to nothing else. `READ_MEDIA_IMAGES` would buy nothing, and "let me
  read all your photos" for a 64-pixel thumbnail is not a trade this app should
  offer you.
- Stored beside the database, not in it, and resized to 512px on the way in.
- It replaces rather than accumulates, the filename carries a timestamp so a
  new photo actually appears instead of the old one persisting out of Flutter's
  image cache, and it never deletes a file it did not write — that directory
  also holds `nouri.db` and `snoozes.json`.
- A row pointing at a file that is gone draws the empty circle, not a broken
  box.
- It can be taken back off, which is the rule the birth date had to learn the
  hard way.

**Its explanation says it changes nothing**, because that is true. Every other
row on that screen tells you what the answer does to your plan. This one says
«مش بتروح لحد ومش بتغيّر الخطة — دي ليك انت». It is not in `PlanRequest` and a
test asserts it never appears in the payload.

Driven end to end on the emulator rather than only in tests: tapping the circle
opened `PhotoPickerGetContentActivity`, which announced itself with *"This app
can only access the photos you select"*; the image came back, was stored as
`files/profile-1789118002926.png` (27 KB), and drew in the circle; the × removed
both the row and the file and left `snoozes.json` sitting beside it untouched.

The release APK's permission list is unchanged by all of this — no `INTERNET`,
no `READ_MEDIA_IMAGES`, nothing new at all. Read off the built APK with
`aapt2 dump permissions`, not off the source manifest.

---

## One thing worth knowing

`flutter test` crashed once, not on a test:

```
FileSystemException: Cannot open file, OS Error: Data error
(cyclic redundancy check), errno = 23
```

That is the disk reporting a bad read, inside the Flutter tool's own hook
cache. It did not recur across five later full runs, and nothing in the project
was affected. Writing it down because a CRC error is the kind of thing that is
either noise or the first sign of a failing drive, and one occurrence cannot
tell you which. If you see it again, that is the answer.

---

## The morning: your phone, and what it proved

You said to install it. Before I did, I read what was armed — and your phone
was already broken.

```
2026-09-10 (today) … 2026-09-13    ZERO alarms
2026-09-14                          6      ← a partial day
2026-09-15 … 09-23                 14-15 each
                                   137 total, against the 265 STATUS recorded
```

**You had no adhan and no iqama from that moment until 14 September**, and
nothing anywhere would have told you. A *partially* cancelled day is the
signature: only an interrupted per-alarm pass can leave six of a day's
fourteen. The old `rearm` cancelled in ascending date order, something ended
the process about five days in, and the schedule pass that would have put them
all back never ran.

No crash was recorded, the app was not force-stopped, it sits at standby bucket
**5 (EXEMPTED)** and is on the Doze whitelist. So nothing was starving it. The
process simply ended.

### Which turned out to be the most ordinary thing a person does

Reproduced on the emulator. Open Nouri, look at it, swipe it away:

| Swiped away after | old build | new build |
|---|---|---|
| 3 seconds | 285 → **8 alarms** | 285 → **285** |
| 6 seconds | 285 → **212 alarms** | 285 → **285** |

Both failure shapes are there depending on when the swipe lands. Kill it early
and the cancel pass has run but the schedule pass has not — the near days go
and the far ones survive, **which is exactly the shape your phone was in**.
Kill it later and the far end is missing instead.

Eight alarms out of 285, for glancing at the app and swiping it away three
seconds later. On the new build the window does not move at all, at either
timing, all fourteen days intact.

That is what the change is worth, and it is a much plainer statement than
anything I measured last night: **the old build turned "open Nouri and close
it" into "lose your prayer alarms".**

### The install itself

`adb install -r`, data kept, schema v13 → v13 with no migration. Watched the
window rebuild live:

```
137 137 137 138 144 152 163 174 … 269 275
lowest point during the re-arm: 137
```

It only ever went up. Now **273 alarms, today through 23 September, no gap**,
all `window=0 exactAllowReason=permission`, next one due 13:20. Your two
October calendar reminders were untouched — they live above the window's id
range precisely so a re-arm cannot reach them.

All five adhan channels still `mBypassDnd=true`, all four rows green in
الإعدادات, no crash, and your data came through — آخر وزن ٨٧٫٠ كجم is where you
left it.

### And the gap it left in Nouri itself

Fixing the cause is only half of it. The other half is that **your phone was
broken for days and the app looked perfectly fine** — four green ticks in
حالة التنبيهات, every permission granted, and no adhan armed for four days.
Every row on that panel answered "is Nouri allowed to do this". None answered
"did it actually happen".

There is a fifth row now, and it reads the device back rather than trusting
what the scheduler believes it armed:

```
التنبيهات المتظبّطة    ✓    ٢٤٠ — لحد ٢٣ سبتمبر
```

**Reach is deliberately not the measure.** Yours still ran to the 23rd — the
hole was at the near end, because that is where an interrupted cancel pass
leaves one. So the question asked is whether any day between here and there
holds nothing, and the answer names the first:

```
فيه ٣ أيام قدّامك من غير أذان — أول واحد ٧ سبتمبر. ده بيحصل لو نوري
اتقفل وهو لسه بيظبط التنبيهات. دوس «صلّح» ويرجع تاني.
```

Four judgements, each with a test behind it. **Today is never a gap** — its
alarms are consumed as the day passes, so by evening it legitimately holds
none, and calling that a fault would warn every user every night. **Gaps stop
at what is armed** — a window reaching a week ahead has no gap on day eight, it
simply does not reach. **Nothing armed is not a gap** — turning every
notification off is allowed. And **the count shows even when healthy**, because
it is the one fact on that panel you can check for yourself.

Driven end to end on the emulator: the healthy reading matches `dumpsys` to the
alarm, a manufactured gap produced the warning, and «صلّح» repaired it and
turned the row green.

**This is not on your phone yet** — you unplugged before I could install it.
The build on your phone has the re-arm fix, which is the part that matters; it
does not have this. `adb install -r build/app/outputs/flutter-apk/app-release.apk`
next time it is connected.

### What I got wrong, again, and it was worse this time

While tapping through the app to check your data, Nouri went to the background
and **my next tap landed in WhatsApp** — in a conversation, on the keyboard,
almost certainly adding a stray character to a draft you were composing. I saw
two screenshots of your private messages doing it. Nothing was sent, and I did
not try to undo it: the send button sits a few hundred pixels from backspace,
and I had just proved my coordinate assumptions were unreliable.

Last time the rule learned was *read the screen between gestures*. I did. The
app switched away in the gap **between the screenshot and the tap**, which the
rule does not cover, and cannot.

The rule that actually holds: **never drive the user's real phone by
coordinates.** `am start`, `input keyevent` and `dumpsys` do everything
verification needs and cannot land somewhere else. Coordinate taps are for the
emulator, where the worst case is a wasted minute.

---

## Three more things, after the install

**The new row was reporting a half-written window.** Opening الإعدادات ~6s
after launch read «١٣٤ — لحد ١٩ سبتمبر» for a device that finished the same
minute at 232 through the 23rd — and read a moment earlier still, the count is
low enough that the gap check fires. Nouri raising a false alarm against
itself, about the one thing that row exists to be trusted about, while it was
busy doing the right thing. `readArmedWindow` now waits on the same warm-up
every scheduling path already waits on. Mid-arm it says «بيتحقق…»; once armed
it says the number. Caught by looking at it on a device, not by a test.

**قيام الليل, watched firing** — the last "never watched" line in STATUS. At
01:32:40, and the interesting part is the contrast with the isha adhan that
fired in the same run:

```
قيام    alert_qiyam_v2   imp=4  AUTO_CANCEL                         category=reminder
الأذان  adhan_isha_v3d   imp=5  INSISTENT|AUTO_CANCEL|HIGH_PRIORITY category=alarm
```

قيام arrives once, on its own tone, no full-screen intent, «الثلث الأخير — لو
قدرت». The adhan loops until dealt with and lights the screen. An invitation
and a summons, and Android treats them differently — which was always the
design and is now measured.

**Nineteen tones, nineteen files, read off Android.** 27 live channels: five
adhan recitations, nineteen task tones each with its own `res/raw` file and
none shared, and `athkar_v1`/`wird_v1`/`general_v1` on the system default —
the documented generic-tone fallback for the safety-net path past day three.
`alert_sound_character_test` reads the PCM on the build machine; this is the
same claim read off the device.

---

## Still yours

Unchanged, and every one of them needs a person:

1. **الإعدادات → الأصوات: listen to the five adhans**, and say whether the fajr
   one carries «الصلاة خير من النوم».
2. **Listen to the nineteen tones** and say which do not read.
3. **Say yes or no to `INTERNET` returning**, so «ابني خطتي» can call anything.
   Still the only item blocking work.
4. **Grant `ACTIVITY_RECOGNITION`** — البدن → امشي → «اسمح لنوري». A real step
   has still never been counted.
5. `docs/athkar-verification.md` and `docs/fasting-verification.md`.

---

## Start here next time

Branch `slice1-religious-core`, head **`0a3a7f1`**, pushed, tree clean. 1219
tests, analyze clean, schema v13.

**Your phone is on the 10 Sep 12:43 build** — it has the re-arm fix and the
photo, and not the armed-window row. Install the current build when it is next
plugged in.

All seven tabs were tapped through on the final release build afterwards —
no exception in logcat, 289 alarms armed, no crash.

**Your phone is on the 9 September build** and has none of tonight's work. The
emulator has it and is powered off. Installing the new build on the HONOR is
worth doing for the re-arm fix alone — that is the device the ten-second hole
mattered on.

Channels came out right on the new `init` path too: **28 live** — five adhan
`_v3d`, the nineteen task tones, and `athkar_v1`/`wird_v1`/`general_v1` — with
all **35 retired ids `mDeleted=true`**. And reboot survival was re-run on this
build: 287 in, 287 out, identical.

### Rules this project keeps re-learning

- **Read the device, not the tests.** Sixth time. 1185 tests were passing over
  a launch that deleted 95% of the user's alarms for ten seconds; no test could
  have seen it, because every test asserts the *end* state and the hole is in
  the middle.
- **Measure the thing you are about to speed up, then measure it again.** The
  before/after here were run in the same emulator session with the same script,
  because a number from a different session proves nothing.
- **A fake that is kinder than the platform hides bugs.** The fake gateway
  appended on `schedule`; Android replaces by ID. Left as it was, this change
  would have looked correct in tests and been wrong on the phone.
- **Never build while the emulator runs.** 15.9 GB, and it was down to 4.3 GB
  free tonight with the emulator alone.
- **Check the artefact before believing the measurement.** `flutter build apk
  --debug` handed back a kernel built from different source after the source
  was reverted, so the first before/after comparison was two copies of the same
  build. It looked plausible. `rm -rf .dart_tool/flutter_build`, then grep the
  kernel for a symbol only one side has.
- **Say which of your numbers are measured and which are cited.** The 42s I
  repeated from STATUS was neither wrong nor mine, and using it to explain a
  change I had not timed produced a claim that had to be withdrawn a few hours
  later.
