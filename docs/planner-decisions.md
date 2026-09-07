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

**Answer: deterministic, now.**

`planDay` takes a `now` and simply plans the rest of the day from it. There is
no memory of the earlier plan, so nothing drifts and the same inputs always
give the same day — a test asserts that. A prayer already passed is not
re-listed.

This is the cheapest answer and it is genuinely enough. When the AI layer
arrives in Slice 5 it can *advise* on a re-plan rather than perform it.

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

## And one bug the tests found

The first window model advanced a window's start past anything placed in it. A
prayer at 11:46 inside a window running 04:07–18:04 moved the start to 12:01
and **silently threw away seven usable hours** — which made a day off look
fuller than a work day. Windows now *split* when something lands in their
middle. That is why `_consume` is more careful than it first appears.

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
