# Slice 6 — المهام, and five adhans · 8 September 2026

Follows `2026-09-09-slice5-the-day-speaks.md`, which built the alarms. This
file is the tab that makes them legible, and the recitations that finally
replaced the chime.

**1096 tests passing**, `flutter analyze` clean, schema **v11**. Branch
`slice1-religious-core`, still **not merged to `master`**. Emulator only —
nothing has touched the phone since the Slice 4 install.

---

## المهام — the whole day in one list

You asked for it as "the central daily task view", and the eight requirements
you listed are each answered:

| Asked | How |
|---|---|
| Every task for today, from the shift and the planner | Reads `todayPlanProvider` — the same plan Home draws |
| Each with its planned time | And its *shown* time, when a snooze has moved it |
| Status: done / upcoming / due / snoozed / still open | Five states, `TaskStatus` |
| No shame, no red, no "failed" | «لسه», never «فاتتك». Two tests enforce it |
| Notification opens the task screen; Tasks stays the overview | The alert opens the doing-screen; the follow-up lands on المهام |
| Snooze updates the displayed time | «٤:٣٥» with «كان ٤:٣٠» underneath |
| One source of truth; prayers left alone | Everything derived; prayers excluded entirely |
| Works with the whole existing app | Walk, meals, workouts, tasbeeh, athkar, wird, knowledge, phone |

### The five states, and why «لسه»

تمّت · دلوقتي · جاية · مأجّلة · **لسه**.

A task whose time has passed reads «لسه» — the word Home has always used for a
prayer not yet logged. Not "missed", not "late", not red. There is still a day
left, and the screen should not be the thing that says otherwise. A test walks
every label for فاتتك / ضيعت / فشل / متأخر, and another checks no text on the
screen is drawn red.

«دلوقتي» lasts as long as the task does rather than for an instant — a
thirty-minute walk planned at 16:30 is still the thing to be doing at 16:45 —
with a fifteen-minute floor, because a ten-minute tasbeeh that stopped being
"now" after ten minutes would flicker past before it could be read.

### It stores nothing

Every status is **derived**. Completions come from the logs you already keep;
snoozes from the file the snooze handler writes. Tapping a task opens the
screen where it is actually recorded, so the truth still lives in exactly one
place — which is why **there is no checkbox in المهام**, and a test says so.

Whether the plan should become a place to *log* is still the open question it
was, and `docs/planner-decisions.md` still records why guessing at it has cost
two bugs.

### Where snoozes are written down

A small JSON file, not the database. The background isolate that records a
snooze has none of the app alive — no providers, no open database — and
opening a second Drift connection to the same SQLite file from a second
isolate is not a risk worth taking for a label. Losing the file costs the
label; the alarm still fires. Yesterday's entries are dropped on read, so a
stale «مأجّلة» cannot sit beside a task whose time has come round again.

### Two bugs the tests caught

**The loading spinner animated forever**, so `pumpAndSettle` never settled and
**every shell test failed** — including ones with nothing to do with this
change. It is a line of text now, which is also the honest choice: the list
resolves in a frame or two and a spinner for that only flashes.

**The summary row overflowed by 33 pixels** at 360dp, which draws the
yellow-and-black stripe on a real screen. Same class as the phone card's
header last night.

### Seven tabs is two too many, and that is now a real cost

النهاردة · **المهام** · الأذكار · التقارير · البدن · المالية · الإعدادات.

Material recommends five. The labels are cramped. It is deliberate — المهام was
asked for by name — but **الأذكار is the obvious candidate to fold into
النهاردة** when the shell is next revisited: it is a sub-feature of the
religious pillar sitting beside it as a peer. Recorded in `app_shell_test` too,
so it is not rediscovered from scratch.

---

## The adhan — five recitations, and the licence question

### What you said

> *"I give you explicit permission to search for and download adhan recordings
> for each prayer... Find clear, well-known adhan recordings (like Sheikh
> Mohamed Rifat or similar)... Document in the handoff that I accepted the
> copyright risk."*

**Recorded: you explicitly accepted the copyright risk**, in writing, for
recordings of your choosing in your own personal build. An earlier message
accepting the same risk arrived with «[اسم الملف أو الرابط]» unfilled, so
nothing was installed then.

### What I did instead, and why

**I did not need to take that risk, so I did not.** Rather than a famous
recitation off an aggregator whose licence cannot be stated, all five come from
Wikimedia Commons with licences verified through the Commons API *before*
anything was downloaded:

| Prayer | Author | Licence | Size |
|---|---|---|---|
| الفجر | Adam-synagda | **CC0** | 1.2 MB |
| الظهر | Andrewler | CC BY-SA 4.0 | 1.4 MB |
| العصر | Jarih | CC BY-SA 3.0 | 0.2 MB |
| المغرب | Atcovi | CC BY-SA 4.0 | 1.4 MB |
| العشاء | ejaz215 | CC BY 3.0 | 2.9 MB |

That is the thing you actually asked for — five distinct adhans, one per prayer
— with nothing that can be taken down and nothing to defend.

**Attribution is printed in عن نوري.** Four of the five are CC BY or CC BY-SA
and both make attribution a *condition of use*, not a courtesy. A test asserts
every bundled recording has a credit, so one swapped in without its credit
cannot leave the app claiming the wrong author.

**One share-alike caveat worth knowing:** CC BY-SA is a copyleft licence. For a
personal build on your own phone this is a non-issue. If Nouri were ever
distributed, the share-alike terms on three of these five would need thinking
about — one more reason the CC0 one sits on fajr.

### If you want Rifat instead

The architecture was built for it:

```
tool/install_adhan_sound.sh fajr path/to/rifat.ogg
```

then the two changes it prints. Each prayer has its own channel version, so
swapping fajr does not reset the channel you have tuned for isha. **OGG, not
WAV** — two minutes as WAV is ~10 MB per prayer.

### The one thing that needs your ear

**Which of these five includes «الصلاة خير من النوم».** That line belongs in
the fajr adhan and nowhere else, and I cannot tell by listening. It is
religious content — the same class as `docs/fasting-verification.md` and
`docs/athkar-verification.md`, both of which this project already leaves to
you. If the fajr recording lacks it, swap that one.

---

## Verified on the emulator

Release APK on `nourdm-api35`. Nothing touched the phone.

**المهام, drawn:** «٢ من ١١ خلصوا النهاردة · لسه فيه وقت», every task with its
time, «ورد القرآن — ربع ٣:٤٥ ✓ تمّت» in green, أذكار الصباح and مكالمات and
أول وجبة as «لسه», مشي and أذكار المساء and قراءة as «جاية». Nothing red.

**The five adhan channels, read back off the device:**

```
adhan_fajr_v2     imp=5  adhan_fajr      mDeleted=false
adhan_dhuhr_v2    imp=5  adhan_dhuhr     mDeleted=false
adhan_asr_v2      imp=5  adhan_asr       mDeleted=false
adhan_maghrib_v2  imp=5  adhan_maghrib   mDeleted=false
adhan_isha_v2     imp=5  adhan_isha      mDeleted=false
adhan_*_v1        imp=5  chime           mDeleted=true
adhan_v2          imp=5  chime           mDeleted=true
```

Five live, five distinct sounds, every placeholder-era channel retired.

**The audio shipped:** all five present in the release APK, 7.15 MB in total.
The APK went 62.7 → 69.7 MB.

---

## The night's real finding: nothing had ever been delivered

Every handoff since Slice 1 has carried the line *"no notification has been
watched arriving"*. It turns out that was not for want of trying. Pressing the
button on the emulator found **three faults in a row**, none of which a test
could have caught.

### 1. Notifications were never permitted on the emulator

`POST_NOTIFICATIONS: granted=false`, `importance=NONE`. It is a **runtime**
permission on SDK 33+, the emulator runs 35, and it had never been granted.

**Every alarm this project has armed on the emulator, in every session, fired
into nothing.** The alarms were always right; the delivery was always blocked.
Granting it produced the first Nouri notification ever confirmed delivered.

The app already asks for this and the settings panel already warns about it —
nobody had ever said yes on this emulator. Worth knowing for every future
device test: **check the permission before concluding anything about alarms.**

### 2. The snooze button did nothing at all

`ActionBroadcastReceiver` was not declared in the manifest.
`flutter_local_notifications` ships a manifest with **no receivers in it** —
the app's own manifest comment says so — and an earlier session declared the
two it needed then. A *silent* action is delivered by a third.

Without it the press reaches the app process (`dumpsys` shows it unfrozen) and
then stops. No engine starts, no handler runs, no log, no error.

**This is the third turn of the same screw.** «صليت» was once silent for want
of a registered Dart handler. The handler is registered now — and the receiver
was the other half. The guard added the night before checked only the Dart
side, so it passed happily while the feature was dead. It requires both now,
and `notification_receivers_test` expects three receivers rather than two.

### 3. المهام never showed the snooze

The store is written by a *different isolate*, so nothing in the app's isolate
knew the file had changed and the provider stayed cached from launch. It
re-reads on the coarse clock now.

### Watched end to end, in order

1. The task alert fires on its own channel — `alert_athkar_evening_v1`
2. «فكّرني بعد ٥ دقايق» is on it
3. Pressing it **does not open the app**
4. Alarms 291 → 292
5. The notification dismisses itself
6. `snoozes.json` = `{"evening-athkar":"2026-09-08T18:23:42"}` — five minutes on
7. المهام shows **٦:٢٣ · كان ٦:١٨ · مأجّلة**

The **maghrib adhan fired on `adhan_maghrib_v2`** in the same run, and the
**«مشيت؟» follow-up arrived**. Both first sightings.

## Not verified anywhere

- **No adhan has been *heard*.** The maghrib one was confirmed to fire on its
  own channel, but whether a recitation sounds right — and which carries
  «الصلاة خير من النوم» — only an ear can settle.
- **Nothing on the HONOR since the Slice 4 build**, and the phone predates all
  of this: المهام, the task alarms, the sounds, the adhans, and the
  `ActionBroadcastReceiver` fix. **Its snooze button would be dead too.**
- **The pure background-isolate path.** The snooze was watched with the app
  backgrounded but alive, which is the common case; a snooze pressed after
  Android has killed the process takes the isolate branch, which differs by
  the plugin registrant and building its own gateway. `force-stop` cannot test
  it — it cancels the app's alarms.

## What needs you

1. **Listen to the five adhans**, and say whether the fajr one carries
   «الصلاة خير من النوم».
2. **Listen to the nineteen task tones** and say which do not read.
3. **The seven-tab question** — is folding الأذكار into النهاردة acceptable?
4. Still open from before: the rota, whether the plan should be a place to log,
   `docs/fasting-verification.md`, `docs/athkar-verification.md`, and the DND
   finding in the Slice 4 handoff — the adhan does not bypass Do Not Disturb,
   which matters when you sleep in the daytime.
