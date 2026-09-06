# Slice 2 — one real day, planned by hand

**Not a spec.** A worked example, so tomorrow's design session argues about a
concrete day instead of an abstraction. Every time below was chosen by hand;
the open question is what rules would produce them.

Day: **Sunday 6 September 2026**, Kuwait, **morning shift (صباحي)**.

Fixed anchors, from the brief and the prayer engine:

| | |
|---|---|
| Wake | 05:00 |
| Bus | 06:00 |
| Work | 07:00 – 14:00 |
| Home | 15:15 |
| Fajr / Dhuhr / Asr / Maghrib / Isha | 04:07 · 11:46 · 15:18 · 18:04 · 19:23 |

---

## The day as Nouri would show it

```
الصباح            ٠٤:٠٠ – ٠٧:٠٠
  ٠٤:٠٧  صلاة الفجر                        ديني
  ٠٤:٣٠  أذكار الصباح            خفيف      ديني
  ٠٥:٠٠  فطار                              بدني
  ٠٦:٠٠  الأتوبيس — استماع لمحاضرة  خفيف   تطوير

الدوام            ٠٧:٠٠ – ١٤:٠٠
  ١١:٤٦  صلاة الظهر (جماعة في الشغل)        ديني
  ١٢:٣٠  تسبيح — بريك              خفيف     ديني

بعد الدوام        ١٥:١٥ – ١٨:٠٤
  ١٥:١٨  صلاة العصر                        ديني
  ١٥:٤٥  راحة ٣٠ دقيقة
  ١٦:١٥  مشي ٣٠ دقيقة              ثقيل     بدني
  ١٧:٠٠  ورد القرآن — ربع          ثقيل     ديني

المسا             ١٨:٠٤ – ٢٢:٠٠
  ١٨:٠٤  صلاة المغرب                       ديني
  ١٨:٢٠  أذكار المساء              خفيف     ديني
  ١٩:٠٠  عشا                               بدني
  ١٩:٢٣  صلاة العشاء                       ديني
  ٢٠:٠٠  قراءة ٣٠ دقيقة            ثقيل     تطوير
  ٢٠:٣٠  مكالمات — ساعة
  ٢١:٤٥  أذكار النوم               خفيف     ديني
  ٢٢:٠٠  نوم  (٧ ساعات قبل صحيان ٠٥:٠٠)
```

---

## The rules this day implies

Each of these is a decision the algorithm has to make. **These are the things
to argue about tomorrow**, not the times themselves.

1. **Sleep is sized first, backwards from the wake time.** 05:00 wake and a
   22:00 bedtime is 7 hours. If the day overfills, the brief says defer a light
   task — never shorten sleep.

2. **Heavy tasks only go where the user is home and free.** The walk, the
   Qur'an wird and the reading all land after 15:15. None can go on the bus.

3. **Light tasks ride along.** The lecture rides the 06:00 commute; the tasbeeh
   rides a work break. These cost no extra time in the day.

4. **Breaks scale with the effort just finished.** 30 minutes between arriving
   home and the walk; nothing between maghrib and the athkar. The brief says
   Nouri computes this rather than using a fixed number — *how* is open.

5. **Knowledge time is one flexible block, not three tasks.** The brief is
   explicit: reading, skill learning and religious content rotate rather than
   all appearing daily. Here it surfaced as a lecture and reading.

6. **Prayers are anchors, not tasks.** Everything else fits around them.

---

## Open questions for tomorrow

- **What happens when the day does not fit?** Which task is dropped first, and
  does Nouri say it dropped something or stay quiet?
- **Night shift** — home at 08:00, light task until 09:00–10:00, then sleep
  computed backwards from the next duty. Does the day still show four blocks,
  or does a night day have a different shape?
- **The day off** — no work anchor at all. Does Nouri fill it, or leave it
  deliberately loose?
- **Re-planning mid-day.** The brief wants Nouri to reshuffle when something is
  missed. Is that deterministic in Slice 2, or does it wait for the AI in
  Slice 5?
- **Where do user-defined tasks live** — a Tasks screen, or added straight into
  a block?
- **Do meals get times, or windows?** The 16/8 fasting window (Slice 3) will
  want to constrain them.

---

## What already exists in code

Data models only, in `lib/features/planner/` — `ShiftPattern`, `DayBlock`,
`PlannedTask`, `TaskAnchor` (clock / prayer / flexible), `TaskWeight`. They
come straight from the brief, so they should survive the design session.

**Nothing places a task.** That algorithm is deliberately absent rather than
guessed at, because it is the whole design question.
