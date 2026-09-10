# The planner — decisions taken without you

`docs/superpowers/specs/slice2-worked-example.md` ended with six open
questions and said the design session needed you in the room. You said to keep
going, so each was answered the safest reversible way and written down here.

**Every one of these is a setting or a constant away from being changed.**
Nothing below is baked into a schema or into stored data, so changing your mind
costs an edit, not a migration.

The algorithm is `lib/features/planner/day_planner.dart`; the day's task list
is `lib/features/planner/daily_tasks.dart`. Both are pure functions with no
database, clock or providers, so a day is entirely a function of its inputs.

---

## The six questions

### 1. What happens when the day does not fit?

**Answer: defer the overflow, and always say so.**

Tasks are placed heavy-first — a heavy task fits in fewer places, so letting
the light ones settle first would leave nowhere for it to go. What is left over
becomes a `DeferredTask` with a reason, and Home prints every one.

**Nouri never silently shortens the day.** A plan that quietly dropped the
Qur'an wird would be the app deciding it did not matter, which is the one thing
the brief spends its whole tone avoiding. The notes explain and never accuse —
a test asserts none of them contains فاتتك, ضيعت, فشل or كسلان.

*To change:* the deferral order is the `sort` in `planDay`; the wording is
`DeferredTask.arabicNote`.

### 2. Night shift — same four blocks or a different shape?

**Answer: a different shape, and it says so.**

A night day has no morning: the user gets home at 08:00, stays up an hour, and
sleeps through the middle of the day. So sleep is computed **forwards** from
getting home rather than backwards from a wake time, and the waking day is what
follows it, out to the next shift. There is no الدوام block on the day the
shift *starts* — the work runs into tomorrow.

*To change:* `_sleepAndWaking` and the night branch of `_windowsFor`.

### 3. The day off — filled or left loose?

**Answer: loose.**

Prayers still anchor it and everything you asked for still lands, but the
planner invents nothing to fill an empty day. Two broad windows split at
maghrib, so the evening still reads as an evening.

A test pins this: on a day off, the only tasks in the plan are the ones that
came from the task list.

### 4. Re-planning mid-day — deterministic, or wait for the AI?

**Answer, revised: not implemented, and the plan is now stable instead.**

I first answered "deterministic, now" and gave `planDay` a `now` that planned
the rest of the day from the current time. That was wrong twice over, and both
faults were found by building on it:

- Clamping every window to `now` made a flexible task land at "now" and then
  keep moving — 15:45, 15:55, 16:05 — chasing the clock and never arriving.
  A plan that will not hold still is not a plan.
- Filtering *past* prayers out before placing was subtler and worse. A fajr
  that had already happened stopped consuming its fifteen minutes, so the
  tasks around it shifted, and **the same day planned at noon came out
  different from the same day planned at dawn.**

`now` is gone. The day is planned once and whole; what is past is still in it,
in a block the UI collapses and marks. That is a true statement about the day.

**Re-planning around a missed task is a real feature and it is not built.**
The brief asks for it — move tonight's reading because this morning's was
missed — but it is a decision about what to move and what to drop, not a clock
parameter. Pretending a clock parameter was that feature is what caused both
bugs above. It wants either your judgement or the AI layer.

### 5. Where do user-defined tasks live?

**Answer: nowhere new, for now — the calendar already holds them.**

Deliberately unanswered in code. Adding a Tasks screen means answering how a
user task competes with a planned one, whether it repeats, and whether it can
be heavy — three more design questions, each with a wrong answer that would be
awkward to unpick.

Calendar reminders already give you "remind me of this on this day", which is
most of what a task list is for. `planDay` takes an arbitrary `List<PlannedTask>`,
so wiring user tasks in later is a change to the caller, not to the algorithm.

### 6. Do meals get times, or windows?

**Answer: windows.**

Meals are flexible tasks with a preferred block and no clock anchor. The 16/8
eating window already owns when food is allowed, and a planner that also pinned
a time to breakfast would be two systems disagreeing about the same meal. A
test asserts neither meal carries a clock anchor.

---

## Three rules the tests forced, that the worked example only implied

**Fajr outranks the shift's wake time.** The morning shift says wake at 05:00
and fajr is at 04:07. Bounding the day by the shift filed fajr as "before the
day began" and dropped it. Waking for fajr is the point, so the day now starts
at whichever comes first.

**The hour before leaving for work is light-only.** By the letter of rule 2 the
user is home and free at 05:30, so a heavy task was allowed there. The worked
example puts nothing heavy before 07:00 and is right: that hour is fajr,
athkar, breakfast and getting out of the door. A thirty-minute walk in it
describes a morning nobody has.

**The evening cannot begin before the user is home.** On a shift ending after
maghrib, opening the evening block at maghrib handed the planner four free
hours the user spends at work — and it put a heavy task in them.

## And two bugs the tests found

The first window model advanced a window's start past anything placed in it. A
prayer at 11:46 inside a window running 04:07–18:04 moved the start to 12:01
and **silently threw away seven usable hours** — which made a day off look
fuller than a work day. Windows now *split* when something lands in their
middle. That is why `_consume` is more careful than it first appears.

The second is question 4 above: the plan changed depending on when you opened
it. Both bugs came from the same instinct — trying to make the planner clever
about the current moment — and both were caught by asking a test to state
something obvious out loud.

---

## A seventh question, answered on 8 September

### 7. Where does phone/social time come from?

**Answer: the user's word, not the device.**

§5.5 asks Nouri to reserve a slot for phone and social time and to say when
the cap is passed. "Notifies if exceeded" could mean reading real usage. That
needs `PACKAGE_USAGE_STATS` — a special-access permission granted through a
system settings page, invisible to the emulator, and the heaviest privacy
permission an Android app can hold.

It would also make Nouri **infer** where every other pillar **asks**. A fasting
day is the user's word. A prayer is logged, not detected. A walk is counted
only while its screen is open and says so. Measuring phone use silently would
be the one place Nouri watched rather than listened.

So the user reports the sitting and Nouri keeps the total. The planner reserves
an evening block the length of the cap — that reservation is the half the
planner owns, and it is what stops phone time eating the hours the rest of the
day was planned into.

*To change:* a usage-stats source would replace the writer behind
`PhoneTimeCard` without touching `phone_sessions` or the cap. The cap itself is
a setting — الإعدادات → البدن والمشي → حد وقت الموبايل — defaulting to the same
sixty minutes §5.5 already names for calls.

**Sittings rather than a running timer** is the same kind of choice, one level
down: it matches وقت المعرفة, which keeps the two cards legible together, and a
live session wants the machinery the walk screen already needed. A timer slots
in behind the same card later without changing anything stored.

## What is still not decided

- **A rota.** The shift is a single current setting, not a repeating pattern.
  The brief describes a rotation, but guessing at one would put wrong times in
  front of you every day. Setting today's shift is honest and reversible.
- **Whether a task can be marked done from the plan.** The blocks are still
  read-only. Logging a prayer already works from Home and from the
  notification, and giving the plan a second way to do it is a decision about
  where the truth lives.
- **The dedicated adhan screen**, still deferred from Slice 1 with its
  reasoning intact in the worked example.
