# Handoff — 6 September 2026 (overnight)

Branch `slice1-religious-core`, head `ad35ca2` + this doc. Not merged to
`master`. **438 tests, `flutter analyze` clean.**

Nothing was installed on the HONOR VNE-N41. Its fajr adhan runs on the build
already there, which we proved works.

---

## 1. The adhan investigation, concluded

The sound pipeline was never broken. Read from the phone before changing
anything:

```
channel adhan_v1 · hasValidSound=true
Playing sound .../raw/chime with usage=USAGE_ALARM
AudioManager streamType=4 volume=15/15 · DND off
MediaPlayer setDataSource(..., 167624) · prepare complete status=0
```

The chime played, correctly, at full alarm volume. What was wrong was the
**content**: `chime.wav` is 1.90 s. It is a placeholder, not an adhan.

Two hypotheses were killed by evidence rather than argument:

- *R8 stripped the audio.* No. R8 shortened the path to `res/d0.wav`, but the
  resource table still maps `0x7f0b0000 raw/chime` to it, and the channel URI
  resolves by name. Checking the file path alone would have been misleading;
  the table is the reliable signal.
- *The gateway created a degraded channel.* Not here — `init()` had created it
  correctly first. But it was a live trap, and is fixed below.

### The one real defect

```
mImportance=3   mOriginalImp=5   mUserLockedFields=5   (PRIORITY|IMPORTANCE)
```

MagicOS downgraded the adhan from MAX to DEFAULT **and locked it**. A locked
field cannot be rewritten by `createNotificationChannel`, and reinstalling does
not clear it. The adhan could never wake a locked screen. Only a new channel id
starts clean.

---

## 2. What changed

### adhan_v2

`channelAdhan` is now `adhan_v2`; `adhan_v1` is in `retiredChannelIds` and
deleted at startup so the settings screen does not show two «الأذان» rows.

### Notification details derived from the channel

The gateway built every notification as
`AndroidNotificationDetails(channelId, channelId)` — the raw id as the display
name, and no sound, importance or audio usage.

This did not cause the incident, but it was a real trap. Scheduled notifications
are delivered by `ScheduledNotificationReceiver`, a pure-Java receiver where
`init()` has never run, and the plugin creates the channel from those details if
one is missing. A fresh install whose first alarm fires before the app is ever
opened would have created a permanently silent adhan channel at notification
volume. Details now come from the channel definition, so the two cannot drift.

The adhan also gains `fullScreenIntent` and `Priority.max`, with
`USE_FULL_SCREEN_INTENT` in the manifest. Nothing else gets either.

### The follow-up redesign, wired

Asks now start from **iqama**, not the adhan. The old fixed 25-minutes-after-
adhan landed 10 minutes *into* the congregation on a 15-minute iqama.

- Ask 1 = iqama + prayer + grace
- Ask 2 = +60 min, capped 15 min before the next adhan, dropped if that leaves
  under 20 minutes
- Ask 2 is worded differently from ask 1
- 22:00 daily summary opens the review sheet
- Follow-ups armed over **3 days**, not 14 — the adhan must survive a fortnight
  unopened; an unanswered question from eleven days ago is only nagging

Alarm count measured, not estimated: **229** (196 core + 33 follow-up), pinned
in a test. Every slot on the full window would have cost 350.

### Two dead paths found while wiring

- `init()` was called with **no response handler**, so no payload was routed
  anywhere. Every tap just opened the app.
- The «صليت» action used `showsUserInterface: false`, which routes to a
  background isolate. No background handler was ever registered, so **the button
  did nothing at all**. It now opens the log sheet — which also lets the user say
  *how* they prayed rather than guessing a quality for them.

### Smaller things

- The review sheet is reachable from Home when prayers are unlogged. It was
  previously only reachable from the 22:00 notification.
- A logged expense can be swiped away, with undo. `deleteExpense` existed on the
  DAO and nothing called it.
- Collapsed day blocks show a pillar strip instead of a bare count; the current
  block names the next task.
- `unansweredPrayersProvider` moved off the per-second clock to a 30-second one.
- Arabic counting is grammatical: «صلاة واحدة» / «صلاتين» / «٣ صلوات».
  `'$n صلوات'` produces «١ صلوات», which is broken Arabic.

---

## 3. Emulator results (API 31, Android 12)

Channels after install — the point of the change:

| Channel | Importance | UserLockedFields | Deleted |
|---|---|---|---|
| `adhan_v1` | 5 | 0 | **true** (retired) |
| `adhan_v2` | **5 (MAX)** | **0** | false |

Real asr alarm delivered with the **app backgrounded and the screen locked**:

```
id=78086  channel=adhan_v2  category=alarm
naturalImportance=5  isNoisy=true  mIsAppImportanceLocked=false
fullscreenIntent=PendingIntent{... startActivity}
android.text=حان الآن موعد صلاة العصر
```

`78086` is the deterministic id: 2440 days since the epoch × 32 slots + 6
(`adhanAsr`). Alarms were `RTC_WAKEUP window=0 exactAllowReason=permission`,
and `stopped=false` throughout.

Follow-up timing confirmed live on the device schedule: asr 15:18 → iqama 15:33
→ **ask 1 at 15:53**, i.e. iqama + 20. The old code would have put it at 15:43.

The emulator runs on Egypt time while prayer times are computed for Kuwait, and
the one-hour offset came out correct — the UTC scheduling fix still holds.

**Not verified on the emulator:** the audio trace for this specific delivery
(the log capture was disrupted by `adb root`). `isNoisy=true` is the system's own
record that it made sound, and the full audio pipeline was traced in detail on
the real phone earlier.

**Nothing here is evidence about HONOR/MagicOS.** Reboot survival, battery-kill
and multi-day reliability remain untested on real hardware.

---

## 4. Blocked: the adhan recitation

**I could not do this part.** I have no way to fetch audio, and adhan recordings
are performances with real copyright holders — I will not invent a file and
present it as a recitation.

Everything else is ready:

```
tool/install_adhan_sound.sh path/to/adhan.ogg
```

It validates the resource name (an illegal character does not fail the build; it
fails at playback, silently, at fajr), installs the file, and prints the exact
two-line source change plus the test to update.

**Use OGG, not WAV.** Measured: `chime.wav` runs at 88,200 bytes/second, so two
minutes in that encoding would add **10.1 MB** to the APK. The same audio as
mono OGG at ~64 kbps is roughly 1 MB.

### Worth deciding before committing to it

A channel sound is the simplest thing that works, and it is what Nouri does now.
For a two-minute recitation it has real limits: the system stops the sound when
the notification is dismissed and there is no other stop control, so silencing a
running adhan means finding and swiping the notification. The audio is also
welded to the channel id, so changing muezzin later means another version bump.

If a full recitation with a proper stop button is the goal, the shape that fits
is a foreground service owning a `MediaPlayer`, with the channel silent and a
stop action on the notification. That is a larger change and is not built.

---

## 5. Test these first, in this order

1. **`docs/install.md` checks 40–47.** Start with 40–42: Settings → Apps → Nouri
   → Notifications should show **one** «الأذان» row, not `adhan_v1` and not two.
2. **Check 44** — the screen-lock test. This is the whole point of `adhan_v2`:
   on v1 the locked importance meant the adhan could only wait silently.
3. Then from a computer:
   ```powershell
   adb shell dumpsys notification | Select-String "adhan_v"
   ```
   Expect `mId='adhan_v2'`, `mImportance=5`, `mUserLockedFields=0`. **If MagicOS
   has downgraded v2 the way it did v1, tell me** — that changes the design, and
   it is a device-policy problem rather than a bug.
4. The follow-up after a real prayer: ask 1 should arrive about 20 minutes after
   iqama, not during it.
5. Tap a follow-up and «صليت» — both should open the log sheet. This path has
   never worked before, so it is the most likely place for a new bug.

Installing the new build re-arms the window and moves the adhan to `adhan_v2`.
Do it **after** a prayer rather than just before one.

---

## 6. Still open

- The adhan recitation (above) — needs a file from you.
- `docs/athkar-verification.md` — 45 athkar, not yet checked against a printed
  حصن المسلم.
- HONOR checks 35–37: reboot, a full day untouched, several days untouched.
- Slice 2 planner design — `docs/superpowers/specs/slice2-worked-example.md` has
  6 implied rules and 6 open questions.
- Prayer duplication on Home (blocks vs list vs separate tab) — still undecided.
