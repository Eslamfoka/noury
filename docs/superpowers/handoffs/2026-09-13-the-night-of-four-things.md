# The night of four things · 13 September 2026

Follows `2026-09-10-the-night-the-alarms-stopped-vanishing.md`. You sent a
photo of four requests and a folder of eleven recordings, said «understand
and work auto because I go sleep», and went to sleep. This is what happened,
in the order it happened, and what is yours to do when you wake.

**Where it finished: `master`, five commits past `a9ddffc`, tests passing,
`flutter analyze` clean, schema v14.** The counts are at the end. Nothing was
installed on your phone — the build is yours to put there, and the first
thing to do with it is listen.

The four, in your words and in the order you wrote them:

1. «عايز اعدل نغمات الأشعار انا بعتلك ملف فيه الاشعارات اللي عايزها تتعدل واللي
   مش باعته سيبه زي ما هو»
2. «عايز كمان اخلي الصلاه ككل الخمس فروض في قايمة المهام وتنقسم بنسب في المية»
3. «اعدل ع تسجيل الصلوات تبقى في المسجد جماعة، جماعة في البيت، فردي في البيت،
   متأخرة عن وقتها، فاتتني الصلاه»
4. «api اللي معاه ai api وعايزك تبني الجزء الخاص ب CONNECT ومش لازم كلود يحطه
   في الخانة ويدوس عادي ai بس اي»

All four are done. Two decisions were made for you along the way and are
flagged below as yours to reverse.

---

## 1. The eleven recordings

Your folder had eleven files. Each became one tone; the eight you did not
send are the same bytes they were.

| Your file | Became | |
|---|---|---|
| `water.mp3` | مياه | copied as is |
| `walking .mp3` | مشي | copied as is |
| `تسبيح .mp3` | تسبيح | copied as is |
| `ورد القرآن .mp3` | ورد القرآن | copied as is (29 s, the longest) |
| `اذكار الصباح .mp3` | أذكار الصباح | copied as is |
| `اذكار المساء .mp3` | أذكار المساء | copied as is |
| `اذكار النوم .mp3` | أذكار النوم | copied as is |
| `قيام الليل .mp3` | قيام الليل | copied as is |
| `page turn for reading or another skill.mp3` | وقت المعرفة | copied as is |
| `stopwatch for phone time use.mp3` | وقت الموبايل | copied as is |
| `قيام الصلاه .m4a` | **الإقامة** | converted — see below |

Unchanged: تمارين البيت، وجبة، مكالمات، الميزانية، تذكير، صيام بكرة؟، مراجعة
اليوم، سؤال المتابعة.

**«قيام الصلاه .m4a» is not an M4A.** Its first bytes are the EBML header of
a WebM container, and inside is Opus audio. Android's ringtone player is not
reliable with that on every OEM skin, so it was converted to MP3 with PyAV
(`tool/install_alert_recordings.py`, which is also the record of the table
above and can install a second batch the same way).

**The one decision in this section:** the converted iqama was **lifted to a
peak of 0.9**. It decoded at 0.28, quieter than everything else you sent but
two, and it is the one tone that most has to be heard — it says the prayer
is starting. Your MP3s were not touched; only the file that was being
re-encoded anyway. If you want it at its original level, delete
`peak_target` in the script and rerun.

Two things you should know about the levels, because I could measure them
and you can only hear them:

- **Your recordings vary a lot in loudness.** Peaks from 0.33 (water) to
  1.59 (أذكار المساء, which clips), RMS from 0.017 (water) to 0.457. The
  channel's volume is the same for all of them, so water will arrive much
  quieter than the evening athkar. If that bothers you when you hear them on
  the phone, say so and I will normalise the set — it is one flag.
- **None of them loops.** The adhan is the only insistent one. A 29-second
  wird recording plays once.

**Every one of the eleven moved to a fresh channel** — `alert_water_v3`,
`alert_iqama_v4`, and so on — and the old id is retired. This is not
optional: Android freezes a channel's sound at creation, so a new file under
the old id would ship your recording and keep playing the synthesised tone,
and nothing anywhere would say why. A test pins all eleven pairs by name.
The consequence on your phone: after the update, eleven new rows appear in
the system notification settings and eleven old ones go. Any per-channel
tweak you made (volume, importance) on those eleven is gone with the old
row; the eight untouched ones keep theirs.

الأصوات in الإعدادات now says «تسجيلك» under each of the eleven, so you can
tell which row is yours before you press «شغّل». عن نوري says eleven are
yours and the rest Nouri's.

A debug APK built clean with the MP3s in `res/raw`. The tests changed
shape: the waveform guard (`alert_sound_character_test`) still measures the
eight WAVs, and for your eleven it asserts only that no two are the same
file and each is long enough. Your choices are yours; the test does not
second-guess what water should sound like to you.

## 2. The prayers as one line in المهام

A card at the top of المهام, shaped like every other task: the fajr time,
«الصلاة — الخمس فروض», and a chip that reads **the percentage** instead of a
status word. Under it, a bar in twenty-percent steps and the five prayers by
name, each with a dot that fills when it is prayed. It counts as one task in
«٣ من ٩», done at a hundred and not before.

Your example, exactly: log fajr → «٢٠٪»; log dhuhr → «٤٠٪»; isha → «١٠٠٪».

**The second decision, yours to reverse:** *prayed, not graded.* A late
prayer counts twenty like any other — the percentage is whether the prayer
happened; the score on Home already grades how. And **«فاتتني» counts
nothing**: you said «صليت ... وعلمت عليها» — prayed, then marked — and a
missed prayer is marked but not prayed. So a day with one missed prayer
ends at eighty, which is the honest number, and its status is «لسه» like
every other unfinished task. Never a word that names a failure, never red.
If you would rather «فاتتني» count as "dealt with" and reach a hundred,
that is one line in `prayers_line.dart` (`PrayerSlotState.prayed`).

The status follows the clock: «جاية» before fajr, **«دلوقتي» with the gold
edge while the current prayer is still unlogged**, «لسه» otherwise, «تمّت»
at a hundred.

Tapping the card opens the five rows Home draws, on a sheet, and logging one
there goes through the same `logPrayer` every other door uses. المهام used
to refuse prayers on the argument that a second place would drift; the line
is derived from the same log, so nothing drifts.

## 3. The five states of the prayer sheet

Relabelled to your words: «في المسجد جماعة، جماعة في البيت، فردي في البيت،
متأخرة عن وقتها، فاتتني الصلاة». Only the wording moved — the enum, its
order and its scores are exactly as they were, and drift stores the state by
index, so **every prayer already logged on your phone keeps meaning what it
meant.**

## 4. CONNECT — الإعدادات → الذكاء الاصطناعي

A ninth settings section. Pick a service, paste a key, press CONNECT.

**Four services, not one.** You said it does not have to be Claude, so:
Claude, OpenAI, Gemini, and «متوافق مع OpenAI» — anything that speaks
OpenAI's chat shape from a URL you type (Groq, OpenRouter, DeepSeek, a local
Ollama). Each knows only the three things that differ: where to send, how
to say the key, how to read the reply. The prompt, the parser and the plan
are the same whichever you pick.

**CONNECT proves the key before keeping it.** It asks the service for its
model list — free, no tokens — and only a key the service accepted is
written. The list comes back as «اختار» next to the model field, so you
pick a model the service actually has rather than one I guessed at. The
defaults, until you pick: `claude-haiku-4-5` (the brief's cost rule and your
10 September decision — «Haiku for the build»), `gpt-4o-mini`,
`gemini-2.5-flash`. **I have not verified those three names against the
live services** — CONNECT will, the first time you press it, and «اختار»
shows what is really there.

**The key is stored in `flutter_secure_storage`** (the platform keystore),
under one versioned name, and nowhere in the database — a test asserts no
settings column carries the word "key". The settings row records only the
provider, the model, the base URL, and when CONNECT last succeeded. The field
on screen is obscured, and once a key is stored the field is empty: a stored
key is a fact, not a string to display. Leave it empty and press CONNECT
again to reuse it after changing the provider or the model. «امسح المفتاح»
forgets it.

**What happens when it goes wrong** is a sentence in the status row, in
attention orange, never red, with the service's own words under it for the
bug report: a refused key (401/403), the rate limit or a spent balance
(429/402), no internet, the service's own 5xx, a 200 that is not JSON, a
reply with no text. Nothing throws.

### What this cost the guard

`INTERNET` is back in the manifest, once, granted. `no_network_test`
narrows rather than disappears, exactly as the 9 September spec §3 said:

- **exactly one file may open a socket** — `lib/features/ai/ai_http_client.dart`;
- the only URLs anywhere under `lib/` are the three hosts in
  `ai_provider.dart`; a URL literal in any other file fails the build;
- no package that reaches the network may be a dependency — the socket is
  `dart:io`, in the open;
- debug and profile keep Flutter's own `INTERNET`; no other source set may
  add one.

That is a stronger statement than the old one for everything except the
call you asked for.

**One bug that would have been invisible until your first real call:**
`HttpClientRequest.write` encodes with the content type's charset, which is
latin-1 by default, and would have turned every Arabic letter of the prompt
into a question mark before it left the phone. The body goes as UTF-8
bytes now, and the client test runs every provider against a loopback
server that reads the wire — 28 tests, none touching the internet.

### And «ابني خطتي» works

With a key connected, the button assembles three days from today (every
prayer time, your profile, the allowed task ids), makes the one call, and
shows what came back on a sheet: Nouri's note, each day's tasks with the
titles المهام uses, the books. Without a key it still explains itself, and
the sheet now has a gold «افتح إعدادات الذكاء الاصطناعي» that lands on the
CONNECT page.

**Proposed, not applied.** The sheet says so — «دي اقتراح — يومك لسه زي ما
نوري رتّبه». Nothing is written into the day or the alarms. That is the
reversible direction the spec built toward, and the question it left open —
does the AI plan *propose* or *overwrite* the day — is still yours. When you
answer it, the next step is mapping `PlanDocument` onto `PlannedTask` and
into the pipeline `planDay` already feeds, which the spec §4 describes.

**Three days per call**, one constant (`planDaysPerCall`). The spec's other
open question. Three is the smallest number that is a plan rather than a
day, and the task-alarm window is three days too.

---

## What is yours to do

1. **Install the build and listen.** All eleven, from الإعدادات → الأصوات,
   and especially the iqama (converted and lifted) and water (the quietest).
   Say if any level is wrong; normalising the set is one flag.
2. **Paste a key and press CONNECT.** Then «اختار» — that is the real list
   from your service, and the first proof the three default names are right.
3. **Press «ابني خطتي» once** and read the sheet. That call costs money on
   your account; it is the only one that does.
4. **Answer the two open questions** when you have seen a plan: propose or
   overwrite; and how many days.
5. Two decisions to reverse if you disagree: the iqama lift (§1), and
   «فاتتني» counting nothing toward the percentage (§2).

## What was deliberately not done

- The plan is not applied to the day (above).
- Your recordings were not normalised (above) — only the one file that had
  to be re-encoded.
- No key was entered anywhere, and no real call was made. Nothing left the
  machine.
- The phone was not touched.

## The commits

```
03459a1 feat: تسجيل الصلاة بقى بالخمس حالات اللي كتبها
9fa8abc feat: إحدى عشر نغمة بقت تسجيلاته هو
8165749 feat: الصلاة بقت سطر في المهام — ٢٠٪ لكل فرض
213b372 feat: الذكاء الاصطناعي — مفتاح، وزرار CONNECT، لأي خدمة
fad92f0 feat: «ابني خطتي» بقى بيبعت فعلاً، ويرجّع الخطة ويعرضها
```

New files worth knowing: `tool/install_alert_recordings.py`,
`lib/features/tasks/prayers_line.dart`, `lib/features/ai/` (seven files),
`lib/features/planner/ai/build_plan.dart`, `lib/features/profile/plan_result_sheet.dart`.
New dependency: `flutter_secure_storage ^11.1.1` (minSdk 24, ours is 26).
