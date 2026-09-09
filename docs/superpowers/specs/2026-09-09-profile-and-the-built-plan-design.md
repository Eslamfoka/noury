# الملف الشخصي، و«ابني خطتي» — design

**9 September 2026.** From two screenshots the user wrote by hand and sent
while going to sleep. This is the feature the brief has been calling Phase 5
since the beginning, arriving in the shape he actually wants rather than the
shape §7 guessed at.

## What he asked for, in his words

> عايز ف البرنامج حاجة زي كده بروفايل داش بورد من خلالها البرنامج يقدر يجمع
> المعلومات ويبعتها لل ai عشان النتيجة تبقى خطة خاصة مش حاجة fixed للناس كلها

> وبعدين البرنامج يستقبل الخطة يوزعها ك مهام ع حسب الوقت امتا شغله امتا دراسته
> وامتا اكل او شرب … امتا يقرا امتا يلعب وهكذا

> وتحت أو فوق أو في اي مكان يبقى ف زي زر … معناها ابني الخطة يلا نبدأ

> حتة القراءة دي برضه مفروض ترشح كتب يقراها ع حسب اهتماماته

Read together: **a profile Nouri can reason from, a button that turns it into a
plan, and the plan landing as ordinary timed tasks.**

## The one insight the whole design turns on

Nouri already has a planner. `planDay` places a day from the shift and the
prayer times, `المهام` draws it, `task_alarm_plan` arms an alarm per task, and
nineteen tones announce them. All of that works, is tested, and is on his
phone.

**The AI must feed that pipeline, not stand beside it.** The plan Claude
returns has to arrive as the same `PlannedTask` values `planDay` already emits,
so every downstream thing — the list, the alarms, the tones, the snooze, the
derived completion — keeps working without knowing where the day came from.

The alternative, a second parallel plan with its own screen and its own alarms,
is how this project has already lost قيام and the budget note: two sources for
one truth, drifting. It is not on the table.

So the feature is three seams, not one system:

```
الملف الشخصي  ──►  PlanRequest  ──►  PlanClient  ──►  PlanDocument  ──►  PlannedTask[]
  (stored)          (assembled)      (the only         (parsed,           (the existing
                                      network)          validated)         pipeline)
```

Each is testable alone. Only the third touches the network, and it is an
interface with a fake behind it everywhere except the one production binding.

## 1. What the profile holds

Two kinds of field, because he asked for both and they behave differently.

**Known fields**, which Nouri understands and can reason about:

| Field | Why it is in the plan |
|---|---|
| الاسم | Nouri addresses him by it |
| النوع | affects nothing yet; he asked for it, and it is one column |
| تاريخ الميلاد | age shapes sleep need and exercise advice |
| موظف / طالب / الاتنين | the branch that decides which of the two blocks below applies |
| نوع الدوام وساعاته | already exists as `shiftType`; the profile reads and writes the same setting rather than keeping a second copy |
| شغل تاني | a second job is time that has to come out of the same day |
| المرحلة الدراسية | a student's day has a different shape from a worker's |
| عدد المحاضرات / الحصص | the hours to place |
| دروس خصوصية | more hours, at different times |
| نظام الأكل والشرب | already partly exists — the 16/8 window and the water target |
| نظام النوم | already exists as `targetSleep` |
| الاهتمامات | **the input to the book recommendations**, which is the one thing he asked for that has no other source |

**Custom fields**, because he said so directly: *«حاجة كمان ممكن المستخدم
يضيف … انا مش عارف احصرها»*. A label and a value, added by him, stored as
rows, and sent to Claude verbatim under a heading that says these are the
user's own. Nouri does not try to interpret them; Claude is the part that can
read an arbitrary sentence, and pretending otherwise would be building a worse
version of the thing being called.

**A photo**, stored as a file beside the database and referenced by path. Not
in SQLite: a few hundred KB of JPEG in a row that every settings read touches
would make every one of those reads slower for a thing shown on one screen.

### Every field carries its own explanation

He asked for this explicitly — *«ولو ف شرح … تبقى مكتوبة عشان المستخدم
يفهم»*. Not a tooltip: a line of Arabic under the field saying what Nouri will
do with the answer. «طالب ولا موظف» is not a demographic question, it is the
question that decides whether the day is built around lectures or shifts, and
the screen should say so.

This is also the honest thing. The user is handing over his life in a form; he
is owed a plain statement of what each answer changes.

## 2. Assembling the request

`PlanRequest.fromProfile(profile, settings, days)` builds a compact Arabic
summary — **never raw rows**. The brief is explicit and it is a privacy
boundary, not a cost optimisation: aggregate only.

What goes: the profile fields above, the fourteen days of shift shape, the
prayer times those days imply, and the fixed anchors. What never goes: meals,
expenses, symptoms, prayer log states, weights. Claude is being asked to place
time, and none of that is time.

A test asserts the payload contains no value drawn from those tables. It is
the kind of promise that is easy to make and easy to break by accident later.

## 3. The one network call

```dart
abstract interface class PlanClient {
  Future<PlanDocument> build(PlanRequest request);
}
```

`AnthropicPlanClient` is the only implementation that opens a socket, and the
only place in Nouri that does. It posts to `api.anthropic.com/v1/messages` with
the key from `flutter_secure_storage`, asks for structured JSON, and parses
defensively — fences stripped, every field type-checked, any failure returning
a `PlanFailure` rather than throwing.

**Model routing**, per §7: Haiku for the plan build, which is routine and
frequent; the stronger model is reserved for the periodic report when that
arrives. `max_tokens` stays modest.

**Called only on the button.** Never on a tap, a screen open, a settings
change, or a schedule. One press, one call.

### What this costs the project

Nouri currently has **no `INTERNET` permission at all**, removed from the
manifest deliberately, with `no_network_test` failing the build if it comes
back. That guard was written for Slice 1 and it did its job.

It now narrows rather than disappears:

- `INTERNET` returns to the manifest.
- The guard becomes: **exactly one file may import an HTTP client**, and the
  only host it may name is `api.anthropic.com`. Any other network import, or
  any other host literal anywhere in `lib/`, fails the build.

That is a stronger statement than the old one for everything except the single
call the user asked for, and it is checkable. Writing it down here because
weakening a guard is the kind of change that should never be silent.

## 4. The plan that comes back

```json
{
  "days": [
    {
      "date": "2026-09-10",
      "blocks": [
        {"title": "الصبح", "tasks": [
          {"id": "first-meal", "at": "07:35", "minutes": 30, "weight": "light"}
        ]}
      ]
    }
  ],
  "books": [{"title": "…", "why": "…"}],
  "note": "…"
}
```

Parsed into `PlanDocument`, then mapped onto `PlannedTask`. **Unknown task ids
are dropped, not invented.** Every id must already exist in `TaskAlertKind`'s
mapping, because a task with no alert is a task that never rings, and a silent
task in المهام is worse than an absent one — it looks like a promise.

The books are the other half of §5.3 and the thing he named last: stored,
shown in the knowledge card, attributed to his stated interests. They are
recommendations and are labelled as such — Nouri still claims nothing it has
not been told.

## 5. What happens when it fails

Everything above is an enhancement over a working app, and it degrades in that
direction:

| Failure | What the user sees |
|---|---|
| No API key | The button explains that a key is needed, and where to put it. No call. |
| No network | «مش قادر أوصل دلوقتي» and the day stays as `planDay` built it. |
| Bad JSON | Same. The parse never throws into the UI. |
| Partial plan | The days that parsed are used; the rest fall back per day. |
| No plan ever built | Exactly today's app. `planDay` is unchanged and still the default. |

`planDay` is not being replaced. It is the floor, and the AI plan sits on top
of it for the days it covers.

## 6. What is deliberately not in this slice

- **Daily re-plan** (§7 moment 2). It needs the plan build to exist first, and
  it needs a definition of "the day went wrong" that has not been agreed.
- **The periodic report** (§7 moment 3). Different call, different model,
  different screen; it belongs with التقارير.
- **A rota**. The profile asks for the shift as it is today, one setting, as
  now. The rotating pattern is a separate open question and folding it in here
  would hide it inside a much larger change.

## Open questions, for him to answer when he wakes

1. **Does the AI plan overwrite the day, or propose it?** Built as *propose*:
   the plan is stored and shown, and becomes the day's plan when accepted. That
   is the reversible direction — the other way round means a bad plan silently
   replaces a working day.
2. **How many days per call?** Fourteen, matching the brief and the existing
   alarm window. One call a fortnight is also the cheapest reading of §7.
3. **Which model exactly.** Haiku for this; he confirms the id when he adds his
   key.

---

*Written while he slept, from two screenshots. Nothing here is committed to
until he has read it — the implementation plan beside it stages the work so
the parts that cannot go wrong land first.*
