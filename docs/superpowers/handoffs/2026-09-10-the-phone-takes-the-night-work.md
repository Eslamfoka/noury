# The phone takes the night's work · 9 September 2026, evening

Follows `2026-09-10-the-night-you-slept.md`. You plugged the HONOR in and said
install it and run the tests. This is what went on, what was measured, and the
one thing I got wrong.

**1176 tests passing**, `flutter analyze` clean, schema **v13**. Branch
`slice1-religious-core`, head `f53c496`, pushed. Still **not merged to
`master`**.

---

## The adhan is through Do Not Disturb, on your phone, confirmed by MagicOS

The whole point of the night's work, and it is no longer an argument from the
emulator.

All five channels on the HONOR:

```
adhan_fajr_v3d      mImportance=4  mBypassDnd=true
adhan_dhuhr_v3d     mImportance=4  mBypassDnd=true
adhan_asr_v3d       mImportance=4  mBypassDnd=true
adhan_maghrib_v3d   mImportance=4  mBypassDnd=true
adhan_isha_v3d      mImportance=4  mBypassDnd=true
```

**The proof that MagicOS accepts it came from MagicOS**, not from Nouri. Its own
zen configuration flipped the moment those channels were created:

```
Diff[areChannelsBypassingDnd:false → true]
mConsolidatedPolicy=[… areChannelsBypassingDnd=true]
```

That system-wide flag is true only when some app on the device holds a channel
Android will let through DND. It was `false` before Nouri's `_v3d` channels
existed and `true` after. There was no need to fire a second adhan at you to
find out.

### The route it took

Granting was done the way you would do it — the settings screen was open, the
policy access was granted, the app was backgrounded and resumed. `_onResume`
then rebuilt the channels onto the bypassing variant, deleted the plain one,
and re-armed the fortnight. First try, no intervention. That resume path had
never run on a device before.

### One thing to know

The same policy carries `SUPPRESSED_EFFECT_FULL_SCREEN_INTENT`. So with DND on
you will **hear** the adhan but it will not seize the screen. Sound gets
through; the takeover does not. That is Android's rule, not a Nouri setting.

---

## Isha fired on the new recitation while I watched

19:19:00, the first prayer after the install:

```
NotificationService: Playing sound android.resource://com.nouri.nouri/raw/adhan_isha
  with attributes usage=USAGE_ALARM content=CONTENT_TYPE_SONIFICATION
CHANNELID:"adhan_isha_v3"  IMPORTANCE:4  category=alarm  flags=0x94
HwNotificationService: isHwSoundAllow … soundVibrate=3
```

`flags=0x94` is `FLAG_HIGH_PRIORITY | FLAG_AUTO_CANCEL | **FLAG_INSISTENT**`.
The insistent flag is the loop. You dismissed it at 19:20:50, so it ran about a
minute and fifty seconds.

That is the whole chain proven on real hardware: the alarm fired on time, on
its own channel, playing the new file, at alarm volume, looping until dealt
with. Every previous handoff had to say "nobody has watched a notification
arrive". That sentence can go.

---

## The install itself

Two of them, both release builds, both clean:

| | |
|---|---|
| 19:08 | the night's work — five reciters, nineteen retuned tones, الملف الشخصي |
| 19:49 | the date-clear fix and ساعات الوردية |

**69.6 MB**, down from 73. The channel swap was exact: **27 live, 27 retired**,
nothing orphaned, every old id gone from your notification settings.

**The v11 → v12 → v13 migrations were clean on your real database.** Today's
prayer log came through intact — الفجر جماعة, الظهر متأخرة, العصر في الوقت —
and the profile row survived the second upgrade with its answers in place. That
was the part worth being careful about and it is the part that went right.

`ACCESS_NOTIFICATION_POLICY: granted=true` while
`enabled_notification_policy_access_packages: null` was the state on arrival,
and it is worth writing down: **holding the manifest permission is not having
policy access.** They are different things, and Nouri correctly built the
non-bypassing channels rather than pretending. The design was built around that
distinction and the phone confirmed it.

---

## What I got wrong

While scrolling الملف الشخصي I fired five swipes without reading the screen
between them. The first began directly on the تاريخ الميلاد field, opened the
date picker, and a following gesture confirmed its default — writing
**2001/1/1** into your profile. Your data, changed by me, not by you.

The rule in this project is *confirm `mCurrentFocus` is Nouri before any tap*,
and I did. Focus was right every time. **Focus being right does not make a
gesture land where you intended**, and that is the part the rule does not say.
Read the screen between gestures, not just before the first one.

It also exposed a real gap: every other field could be emptied — text by
deleting it, a chip by tapping the selected one — but a date could only be
*replaced*, because a picker has no "none". A value set by mistake was
permanent. That is now fixed with a × beside any set date, and it matters more
than a wrong string would: the age computed from that field goes to Claude and
shapes what it says about sleep and effort. A wrong birth date is a wrong plan,
quietly.

By the time I got back to the phone the field was already clear, so you had
removed it yourself. The button and its three tests stand either way.

---

## ساعات الوردية, which I had missed

You caught it: the screenshot asks two things — *«نوع دوامك ايه وعدد ساعاتك
دوامك ايه»* — and I had built only the first.

The **type** already lives in الإعدادات → الدوام and is not duplicated in the
profile; one setting, one place, which this project has paid for twice. The
**length** was missing entirely, and it is the half that decides how much of a
day is left once duty is taken out.

Chips for the four you named — ٨ · ١٢ · ١٦ · ٢٤ — and a free field beside them,
because your own shifts are seven and nine hours and a closed list would have
had no room for the person it was built for. Schema v13, additive.

---

## Still yours

Unchanged in substance from last night, minus the ones now settled:

1. **Listen to the five adhans** in الإعدادات → الأصوات and say whether the
   fajr one carries «الصلاة خير من النوم». You have now heard isha; fajr is the
   one that matters and it fires at 04:09.
2. **Listen to the nineteen tones** and say which do not read.
3. **Say yes or no to `INTERNET` returning**, so «ابني خطتي» can call anything.
   This is the only item blocking work.
4. **Grant `ACTIVITY_RECOGNITION`** — البدن → امشي → «اسمح لنوري». Still never
   granted; a real step has still never been counted.
5. `docs/athkar-verification.md` and `docs/fasting-verification.md`, both still
   waiting on a person.

Settled since last night: the DND access is granted and measured, the adhan has
been heard, and a notification has been watched arriving.

---

## Start here next time

Branch `slice1-religious-core`, head **`f53c496`**, pushed, tree clean. 1176
tests, analyze clean, schema v13.

**Your phone is on the current build** and holds policy access. 265 alarms
armed. The emulator has an older build and is powered off.

### Rules this project keeps re-learning

- **Read the device, not the tests.** Fifth time it has paid.
- **Read the screen between gestures**, not only before the first. Confirming
  focus is necessary and not sufficient — see above, in your profile.
- **Never build while the emulator runs.** 15.9 GB of RAM.
- **A display filter is not a persistence rule.**
- A drift stream keeps a timer alive past the end of a widget test; use
  `FutureProvider`. A lazy `ListView` reports everything below the fold as
  "found 0", so screen tests need a surface taller than any phone.
