# Start here — 7 September 2026

Read `docs/STATUS.md` first for where the project stands. This file is only
what to do next.

Branch `slice1-religious-core` at `dc05519`, clean and pushed. 474 tests green.
**Do not merge to `master`.**

---

## 1. First thing: install the current build

The phone is running the build from 15:20 yesterday, which predates the
follow-up cancellation fix. Until it is replaced, logging a prayer at ask 1
still leaves ask 2 to fire an hour later.

```
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

**Install after a prayer, not just before one** — installing re-arms all 230
alarms, and doing it in the last minutes before an adhan risks missing it.

Then confirm, from `docs/install.md`:

- checks 40–42 — one «الأذان» row, `adhan_v2`, `mUserLockedFields` state
- check 45 — tapping a follow-up and «صليت» both open the log sheet
- that logging a prayer removes its two follow-up alarms:
  ```
  adb shell dumpsys alarm | Select-String "com.nouri.nouri" | Measure-Object
  ```
  The count should drop by exactly 2.

## 2. The adhan recitation

You said you would get an OGG file of about two minutes. When you have it:

```
tool/install_adhan_sound.sh path/to/your-adhan.ogg
```

It validates the resource name, installs it, and prints the exact two source
changes plus the test to update. Both halves are required — Android ignores a
new sound on an existing channel, so without the version bump you would ship
the new audio and keep hearing the takbir.

**OGG, not WAV.** Measured: the current file runs at 88,200 bytes/second, so two
minutes as WAV would add 10.1 MB to the APK.

Decide before installing it: a channel sound stops when the notification is
dismissed and has no other stop control, so silencing a two-minute adhan means
hunting for the notification. If that is unacceptable, the shape that fits is a
foreground service owning a `MediaPlayer` with a stop action — bigger work,
and it pairs with the dedicated adhan screen in item 4.

## 3. The Slice 2 design session

This is the main event and it needs you in the room.

Read `docs/superpowers/specs/slice2-worked-example.md` — one real day planned by
hand, with 6 implied rules and 6 open questions. The models exist
(`lib/features/planner/`) and Home shows a static preview marked «معاينة».
**No planner algorithm has been written**, deliberately.

Three questions carried over:

- **Prayer duplication on Home.** Blocks, list, or a separate tab? Asked twice,
  both times the answer arrived as an unfilled template. My view: prayers only
  inside the blocks, since two places to log the same thing is two places to
  keep in sync.
- **The tab structure.** Six tabs is one past the recommendation. الأذكار is a
  sub-feature of the religious pillar yet has a whole tab, while the planner
  will want one.
- **Should the dedicated adhan screen carry log buttons?** My lean is no — the
  prayer name is not sensitive, but a visible history on the lock screen is.

## 4. Untouched work, roughly by value

- **Self-development (§5.3)** — the one pillar with nothing at all. One flexible
  "knowledge time" block holding reading, skill learning and religious content.
  Note it expects Nouri to *recommend* books and *propose* skills, which is AI
  work and probably belongs with Slice 5.
- **A dedicated adhan screen** — minimal, no personal data, shows over the
  keyguard. Rationale in the slice2 spec.
- **Reports beyond the religious pillar** — body and wealth have real data now
  and appear nowhere in reports. You chose a religious summary originally, so
  this is a change, not an omission.
- **Sleep windows tied to shifts** (§5.2) — belongs with the planner.
- **Islamic fasting reminders** — Mondays, Thursdays, the white days.
- **Water reminders** — deferred to Slice 3, tied to prayers and the fasting
  window.

## 5. Verification debt

Nothing here has been tested on real hardware, and emulator results say nothing
about MagicOS:

- reboot survival (check 35)
- a full day untouched (36)
- several days untouched — the OEM battery-kill case (37)

Also outstanding: `docs/athkar-verification.md` lists 45 athkar that no human
has checked against a printed حصن المسلم. That is a correctness question about
religious text and should not be resolved by an AI alone.

---

## Standing constraints

- Do not merge to `master`, do not switch branches, do not force-push.
- Do not add network calls in Slice 1.
- Do not claim any HONOR/MagicOS behaviour has passed unless it was tested on
  the real VNE-N41.
- Do not create a new project or discard existing work.
- If a blocking decision appears, take the safest reversible option, document
  it, and continue.
