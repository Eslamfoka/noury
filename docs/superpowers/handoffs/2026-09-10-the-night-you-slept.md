# The night you slept · 9–10 September 2026

Follows `2026-09-09-the-phone-install-and-the-sound-audit.md`. You sent seven
decisions and two screenshots, said *«keep working while I sleep»*, and went to
bed. This is what happened.

**1170 tests passing**, `flutter analyze` clean, schema **v12**. Branch
`slice1-religious-core`, still **not merged to `master`**. Four commits.

**Your phone was not touched.** Everything below was done on the emulator
(`nourdm-api35`), as you asked.

---

## The headline: the adhan now gets through Do Not Disturb, and it is measured

This was your third decision and the one that mattered most — you sleep through
the day after a night shift with DND on, which is exactly when the adhan has to
reach you.

It works. Not "should work": **watched happening**, on a device, with DND
actually switched on:

```
adhan_fajr_v3d          intercepted=false   USAGE_ALARM   ← gets through
adhan_isha_v3d          intercepted=false   USAGE_ALARM
adhan_maghrib_v3d       intercepted=false   USAGE_ALARM
alert_iqama_v3          intercepted=false   USAGE_ALARM
alert_followup_v2       intercepted=true    USAGE_NOTIFICATION  ← stays quiet
general_v1              intercepted=true    USAGE_NOTIFICATION
```

`intercepted=false` is Android saying it will let the sound out. The bottom two
rows are the control that makes the top four mean something: with the same DND
setting, at the same moment, the soft «عملتها؟» questions **were** silenced.
That is your bug reproduced and the fix beside it.

The adhan gets through; the app quietly asking whether you walked does not.
That is the split you would want if someone described it to you.

### How it was done, and the one thing only you can do

`flutter_local_notifications` cannot express this, so there is now a small
native plugin (`DndPlugin.kt`) that creates the adhan channels itself with
`setBypassDnd(true)`.

Two Android rules shaped the design and neither is negotiable:

1. The bypass is **ignored** unless you have granted notification-policy
   access, and that is granted on a system screen — no app can raise a dialog
   for it.
2. A channel's bypass is **fixed when the channel is created**, exactly like
   its sound.

So a bypassing adhan has to be a *different channel*: `adhan_fajr_v3` becomes
`adhan_fajr_v3d` once access is held. Only one variant exists at a time; the
other is deleted, so you will not find ten «الأذان» rows in your settings.

**الإعدادات → حالة التنبيهات has a fourth row now**: «الأذان بيعدّي وضع عدم
الإزعاج», with a «اسمح» button that takes you straight to the system screen.
When you come back, Nouri rebuilds the channels and re-arms the fortnight onto
them by itself — you do not have to know that had to happen.

### One honest nuance

Under *priority-only* DND, the task tones marked as alarms already got through
on alarm audio usage alone. The explicit bypass matters for the stricter zen
modes, where alarm usage is not enough. Both are now in place, so it holds
either way — but if you had been on priority-only DND all along, the adhan
should already have been audible, which suggests MagicOS or a stricter mode was
involved on your phone. Worth one look next time you have it in your hand.

### And it is loud and persistent, as you asked

The adhan now carries `FLAG_INSISTENT`: the recitation **loops until you deal
with it** rather than playing once into an empty room.

With a ten-minute cap. A phone left in another room must not call the adhan
until its owner comes back — that is not devotion, that is a fault. Ten minutes
is a little over two passes of the longest recitation, which is enough to wake
someone and not enough to become a problem. One constant if you want it longer.

---

## The nineteen tones now sound like their tasks

Your second decision. They were sums of sine waves — distinct from each other,
meaningless on their own. Now:

- **مياه** is running water, with drops falling into it
- **مشي** is four footsteps, with the scuff of a shoe on top
- **مكالمات** is a landline ringing, with the 20 Hz rasp that makes it one
- **تمارين** is a coach's whistle
- **وجبة** is a spoon rung twice against a glass
- **تسبيح** is three light wooden beads; **الإقامة** is two firm low knocks
- **أذكار الصباح** is birds at first light; **المساء** is the same birds
  settling, lower and falling
- **الميزانية** is coins set down
- **قيام** is a distant bell, faded in over a quarter of a second

Written with filtered noise, damped bursts, inharmonic partials and pitch
sweeps rather than added sine waves.

**Distinctness is now measured, not asserted.** There was a test called «water
sounds like water» that compared a *filename* — it would have passed with all
nineteen files holding the same recording. The new one reads the actual audio
and fails when any two tones come within a threshold on duration, onset count,
sustain and brightness.

It immediately caught something real: قيام was opening like a struck bell, at
01:30, next to a sleeping man. It now fades in. That is a bug the old test
could never have seen.

All nineteen channels were bumped and the old ids retired — Android freezes a
channel's sound at creation, so a retuned tone under its old id ships new audio
and plays the old one, silently.

---

## Five famous reciters, and one thing I could not do

Your first decision. The Wikimedia set is gone; these are in:

| | reciter | length |
|---|---|---|
| الفجر | **مشاري العفاسي** — أذان الفجر | 4:23 |
| الظهر | **عبد الباسط عبد الصمد** | 3:58 |
| العصر | **ناصر القطامي** | 2:12 |
| المغرب | **المدينة المنورة، ١٩٥٢** | 2:52 |
| العشاء | **مشاري العفاسي** | 2:37 |

5.0 MB in total — *less* than the 7.0 MB the placeholder set cost.

**Sheikh Mohamed Rifat, whom you asked for by name, has no adhan recording in
any reachable archive.** He is remembered for Qur'an, not for the call, and
what exists under his name is recitation. Abdul Basit is the same era and the
same standing, and is the nearest honest answer I could give.

### «الصلاة خير من النوم» — what I can and cannot tell you

I cannot hear. So here is exactly what the evidence is:

- The fajr file is the only one in its source collection labelled as the
  **morning** adhan.
- It runs **263 seconds** against **157 seconds** for the *same reciter's*
  ordinary adhan — 68% longer.

That is consistent with the tathwib and it is the strongest thing available
without ears. **It is not proof.** الأصوات now carries a «مؤقت» badge and a
line asking you to confirm precisely this, because it is one minute of your
time and no amount of measuring replaces it.

### On rights, plainly

Unlike the Wikimedia five, these licences cannot be individually verified. You
asked for famous reciters, were told the trade-off, and accepted it for
**personal use on your own phone**. Nothing is distributed and the app is not
published. The stale comments in the source claiming "all freely licensed, all
from Wikimedia Commons" have been corrected rather than left to mislead — if
Nouri is ever put in front of anyone else, these five are the first thing to
revisit.

They are marked **مؤقت** in الأصوات, as you asked, until you send your own five.

---

## الملف الشخصي — your two screenshots, built

This is the biggest piece and it is half done, deliberately.

**What is built and working now**, with no key and no network:

- **The profile**: name, النوع, birth date, موظف/طالب/الاتنين, second job,
  study stage, lectures, private lessons, your own sentences about eating and
  sleeping, and your interests.
- **Every field says what it changes**, which you asked for in as many words.
  «انت إيه دلوقتي» is not a demographic question — the line under it says it
  decides whether your day is built around shifts or lectures. Choosing طالب
  reveals the study fields and hides the second-job one.
- **Fields Nouri never thought of** are yours to add, because you said you
  could not enumerate them. Label and value, your own words, passed through
  untouched.
- **«ابني خطتي»**, at the bottom, in gold.
- The assembler that turns all of that into the summary Claude would receive.
- The parser that turns Claude's reply into ordinary timed tasks.

**Nothing here is a score.** No percentage, no bar, no «٣ من ٨». A completion
meter over a form about your own life is self-blame wearing a progress bar. The
line under the button says what a fuller profile would buy you and stops. The
button works on a completely empty profile.

**What is not built**: the network call itself. Pressing the button today
explains that it needs your own API key rather than appearing to work and doing
nothing.

That is where it stops for a reason, and it is the one thing I want you to
decide rather than find:

> **Nouri currently has no `INTERNET` permission at all** — removed from the
> manifest deliberately, with a test that fails the build if it comes back. The
> AI layer needs it. The plan is to *narrow* that guard rather than delete it:
> exactly one file may open a socket, and the only host it may name is
> `api.anthropic.com`. That is a stronger promise than today's for everything
> except the one call you asked for. But it reverses a decision you made on
> purpose, and I would rather you said yes to it awake.

The design is written up in full at
`docs/superpowers/specs/2026-09-09-profile-and-the-built-plan-design.md`,
including three open questions.

**The photo says it is not ready** instead of looking broken. It needs a
platform picker — a dependency and a permission set — which is not a thing to
add and leave untested overnight. It was also the most tentative thing you
asked for and it feeds nothing in the plan.

---

## A bug that was already there

STATUS claimed 1118 tests passing. It was **1117 passing and one failing**, and
had been for some time.

**Snoozing a second task erased the first.** `record` and `clear` built the
next file out of what `read()` returned — and `read()` hides entries older than
twenty hours. So a *display* filter was deciding what survived a *write*.

Press «فكّرني بعد ٥ دقايق» on the walk, then on the meal, and the walk's snooze
was gone.

Writes now merge into the unfiltered file. The store is keyed by task id and so
can never hold more entries than there are kinds of task, which is why it never
needed the pruning that cost it data in the first place.

---

## The step permission, when it has been refused for good

Your fourth decision. The runtime request was already there and already
explained itself. What was missing was the trap on the other side: once Android
records "don't ask again", `request()` returns denied and **shows nothing at
all** — so «اسمح لنوري» became a button that did nothing, forever, with no way
to discover why.

That is now its own state with its own remedy: Nouri says the permission is
locked in system settings and offers «افتح إعدادات التطبيق», which goes
straight there.

---

## Still yours to do

In the order that matters:

1. **الإعدادات → الأصوات: listen to the five adhans.** Say whether the fajr one
   carries «الصلاة خير من النوم». Everything above is evidence; you are the
   proof.
2. **Listen to the nineteen tones** and say which do not read. They are
   synthesised — any of them is one function in `tool/make_alert_sounds.py`.
3. **Say yes or no to `INTERNET`** returning, so «ابني خطتي» can actually
   build a plan. Then add your Anthropic key.
4. **Grant DND access on your phone** — الإعدادات → حالة التنبيهات → «اسمح».
   Nouri does the rest when you come back.
5. **Grant `ACTIVITY_RECOGNITION`** — البدن → امشي → «اسمح لنوري». Still never
   granted, so a real step has still never been counted.
6. Religious content — `docs/athkar-verification.md` and
   `docs/fasting-verification.md`, both still waiting on a person. Untouched,
   as you asked.

---

## Start here next time

Branch `slice1-religious-core`, head **`c21847d`**, tree clean, **not merged**.
1170 tests, analyze clean, schema v12.

The emulator has the DND build (the one *before* the profile screen) — it was
installed to measure the bypass and has not been rebuilt since. Your phone is
still on the 8 September build and was not touched.

### Rules this project keeps re-learning

- **Read the device, not the tests.** The DND result above is the fourth time
  this has paid. 1170 tests cannot tell you whether Android will let a sound
  out.
- **Never build while the emulator runs.** 15.9 GB of RAM.
- **Check `POST_NOTIFICATIONS` before concluding anything about alarms.**
- **A display filter is not a persistence rule.** The snooze bug, in one line.
- Two new ones, written where they bit: a drift stream keeps a timer alive past
  the end of a widget test and fails the file on `!timersPending` long after
  the assertions passed — use `FutureProvider`, like every other read here; and
  a lazy `ListView` reports everything below the fold as "found 0", so screen
  tests lay out on a surface taller than any phone.
