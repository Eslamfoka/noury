# ورقة مراجعة الصيام — Sunnah fasting verification sheet

> **This file has NOT yet been checked by a person.**
> Nouri suggests fasting days. Which days those are, and which days must never
> be suggested, is a religious question — and the same rule applies here as to
> the athkar: an AI does not settle it alone. Please read this before trusting
> the reminders.

The rules live in `lib/features/fasting/sunnah_fasting.dart` and are covered by
`test/features/fasting/sunnah_fasting_test.dart`.

---

## What Nouri suggests

Exactly what the brief names in §5.2, and nothing beyond it.

| Day | Rule | Source in the brief |
|---|---|---|
| الاتنين | every Gregorian Monday | "reminders for Mondays & Thursdays" |
| الخميس | every Gregorian Thursday | same |
| الأيام البيض | the 13th, 14th and 15th of each Hijri month | "the white days (Ayyam al-Beed)" |

A day that is both — a Monday that is also a white day — is named as both in
the same reminder rather than sent twice.

## What Nouri never suggests

This is the half that needs checking most carefully, because getting it wrong
means the app suggests a fast on a day fasting is forbidden.

| Day | Hijri | Why |
|---|---|---|
| عيد الفطر | ١ شوال | fasting prohibited |
| عيد الأضحى | ١٠ ذو الحجة | fasting prohibited |
| أيام التشريق | ١١ و١٢ و١٣ ذو الحجة | fasting prohibited |

**The 13th of ذو الحجة is the trap.** It is a white day by the general rule and
a day of التشريق by the calendar, and fasting is forbidden on it. A naive
"13, 14, 15 every month" would have Nouri suggest a forbidden fast once every
year. The exclusion is tested by name — see «the 13th of ذو الحجة is excluded
despite being a white day».

The 14th and 15th of ذو الحجة fall after التشريق and are still offered.

## What is deliberately absent

These are well-known sunnah fasts that Nouri does **not** suggest, because the
brief does not name them and choosing which to add is a religious judgement
rather than a coding decision:

- يوم عرفة — ٩ ذو الحجة
- عاشوراء وتاسوعاء — ٩ و١٠ المحرم
- الست من شوال
- أيام أخرى

**If you want any of these, say so and they are a few lines each.** They were
left out on purpose, not forgotten.

## How the day is decided

The Hijri date comes from `hijriFor()`, the same civil calculation the Home
header shows, including the ±1 day nudge in الإعدادات. So the fasting days can
never disagree with the date on the header — if you correct the header for a
sighting, the fasting days move with it.

Civil calculation can differ from local sighting by a day. That is a known
limit of the whole app, not of this feature.

## The wording

The reminder goes out at **20:00 the evening before**, and names tomorrow:

> صيام بكرة؟
> بكرة الاتنين. لو حابب تصوم، دي نيّتك من دلوقتي.

Phrased as an offer. A test asserts the words «لو حابب» are in it — Nouri never
obliges, and least of all about worship.

## To review

- [ ] The three suggested day-rules are correct and complete for what was asked.
- [ ] The prohibited days are correct and complete.
- [ ] The 13th of ذو الحجة exclusion is right.
- [ ] The wording offers rather than instructs.
- [ ] Decide whether عرفة, عاشوراء and الست من شوال should be added.
