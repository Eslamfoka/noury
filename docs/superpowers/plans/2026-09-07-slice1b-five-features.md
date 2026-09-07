# Slice 1b — five new features

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add calendar reminders, a live step counter, frame-animated home
workouts, long-run challenges, and a mushaf-style rendering of Qur'anic athkar
— all offline, all on schema v4.

**Architecture:** Every feature follows the shape Slice 1 already uses: pure
Dart domain logic in its own file with unit tests, a drift table plus a DAO,
and a widget layer that only renders. Nothing new reaches the network. The two
features that touch the platform (step sensor, reminder alarms) go through an
interface with a fake, so the whole of the logic is testable without a device.

**Tech Stack:** Flutter 3.44.6 · drift 2.34 · riverpod 3.4 ·
flutter_local_notifications 22.3 · a hand-written Kotlin sensor channel (no new
pub dependency).

**Spec:** this file. It stands in for a design doc — the five features were
specified by the user in one message on 7 September 2026, quoted verbatim in
each task's *Requirement* line. The open questions the user must answer are
collected in "Decisions taken alone" below rather than blocking the build.

---

## Global Constraints

Copied from `docs/STATUS.md` and the standing constraints in
`docs/superpowers/handoffs/2026-09-07-start-here.md`. Every task inherits them.

- **Offline.** No new direct dependency may reach the network;
  `test/guard/no_network_test.dart` enforces it. The APK ships without
  `INTERNET`.
- **No new pub dependency** unless a task says so explicitly. The step counter
  is a hand-written platform channel precisely to avoid one.
- **Enums stored by index are append-only.** Never insert or reorder a value in
  `PrayerState`, `MealFeeling`, or any enum added here — drift stores the index
  and reordering silently rewrites the user's history.
- **Dates are constructed, never offset.** `DateTime(y, m, d + 1)`, never
  `add(Duration(days: 1))` — Egypt's DST made a 24-hour day the wrong length.
- **Migrations are additive only.** v3 → v4 creates tables and adds columns. It
  never drops or rewrites one.
- **Money in fils, weight in grams, distance in metres — integers.** No
  accumulated floating-point error in anything the user sees a trend of.
- **Arabic-Indic digits everywhere in the UI**, via
  `toArabicDigits()` from `lib/core/format/arabic_numerals.dart`.
- **Never build a Cairo `TextStyle` by hand.** Use `cairo()` from
  `lib/core/theme/nouri_theme.dart` — Cairo is a variable font and a bare
  `fontWeight:` renders regular.
- **Nothing is ever marked failed, and nothing is ever red.** There is no
  failure colour in `NouriColors`. A missed challenge day is neutral, never a
  reprimand.
- **Emulator only this session.** `emulator-5554` (`nourdm-api35`). Do not
  install to the HONOR VNE-N41. No claim about MagicOS behaviour may be made
  from an emulator result.
- Do not merge to `master`, do not switch branches, do not force-push.

---

## Decisions taken alone

The standing constraints say: if a blocking decision appears, take the safest
reversible option, document it, and continue. Four appeared.

1. **No new bottom tabs.** Six is already one past Material's recommendation
   and the handoff lists the tab structure as an open Slice 2 question. So:
   step counting and workouts go **inside البدن**, challenges go **inside
   التقارير**, and the calendar opens as a **route from the Home header**.
   Nothing about the shell changes, so any answer the user gives later is still
   available.
2. **The step counter needs no background service.** It reads the hardware
   counter while the session screen is open and reconciles on resume from the
   sensor's own cumulative total, which the OS keeps counting while the app is
   backgrounded. A foreground service would be the way to survive the screen
   locking for an hour; it is much bigger work and pairs with the adhan service
   already sketched in the handoff. Deferred, not forgotten.
3. **Workout "videos" are vector frames, not video files.** The user asked for
   "exercise videos as frames". A frame-interpolated stick figure is a few KB,
   ships offline, needs no codec or `video_player` dependency, and renders at
   any size. Real footage can replace it later behind the same widget API.
4. **The mushaf rendering is additive to the athkar JSON.** Qur'anic entries
   gain an optional `quran` block; entries without one render exactly as they
   do today. No existing athkar content changes meaning, so
   `docs/athkar-verification.md` stays valid.

---

## File structure

```
lib/data/db/tables.dart                  + 4 tables, 3 enums (append-only)
lib/data/db/nouri_database.dart          + v4 migration, 4 DAOs

lib/features/reminders/
  reminder.dart                          domain: Reminder, RepeatRule, occurrences
  reminder_ids.dart                      the notification ID space (isolated, no plugin import)
  reminder_scheduler.dart                turns reminders into ScheduledNotification
  calendar_month.dart                    pure month-grid maths
  calendar_screen.dart                   the month view
  reminder_editor_sheet.dart             pick a day, write the text
  reminder_providers.dart

lib/features/steps/
  step_source.dart                       interface + SimulatedStepSource
  sensor_step_source.dart                the platform channel client
  walk_session.dart                      domain: steps -> distance, calories, pace
  walk_screen.dart                       the live session
  steps_providers.dart

lib/features/workouts/
  pose.dart                              joints, a Pose, lerp
  exercise.dart                          an exercise: keyframes, reps, work/rest
  workout_catalogue.dart                 the bundled routines
  interval_timer.dart                    domain: work/rest state machine
  pose_painter.dart                      CustomPainter for one frame
  exercise_animation.dart                the frame player widget
  workout_screen.dart                    the session runner
  workout_providers.dart

lib/features/challenges/
  challenge.dart                         domain: definition, kind, target
  challenge_catalogue.dart               the bundled challenges
  challenge_evaluator.dart               progress from existing logs
  challenges_panel.dart                  the UI, inside التقارير
  challenge_providers.dart

lib/features/athkar/
  quran_passage.dart                     domain: surah, bismillah, ayat
  widgets/mushaf_card.dart               the mushaf rendering
lib/data/athkar/athkar_item.dart         + optional `quran` block
assets/athkar/{morning,evening,sleep}.json  + quran blocks on Qur'anic entries

android/app/src/main/kotlin/com/nouri/nouri/
  StepCounterPlugin.kt                   TYPE_STEP_COUNTER over an EventChannel
  MainActivity.kt                        registers it
```

Tests mirror the source tree under `test/`, as the project already does.

---

## Task 1: Schema v4

**Requirement:** every feature below stores something. One migration, done once,
so no later task has to touch the schema.

**Files:**
- Modify: `lib/data/db/tables.dart`
- Modify: `lib/data/db/nouri_database.dart` (schemaVersion, migration, DAOs)
- Test: `test/data/db/schema_v4_test.dart`

**Interfaces — Produces:**

```dart
enum ReminderRepeat { once, daily, weekly, monthly }   // append-only

class Reminders extends Table {
  IntColumn      get id       => integer().autoIncrement()();
  DateTimeColumn get onDate   => dateTime()();          // midnight local
  IntColumn      get minutes  => integer()();           // minutes past midnight
  TextColumn     get title    => text()();
  TextColumn     get note     => text().nullable()();
  IntColumn      get repeat   => intEnum<ReminderRepeat>()();
  BoolColumn     get done     => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

class WalkSessions extends Table {
  IntColumn      get id           => integer().autoIncrement()();
  DateTimeColumn get startedAt    => dateTime()();
  IntColumn      get seconds      => integer()();
  IntColumn      get steps        => integer()();
  IntColumn      get metres       => integer()();       // integer metres
  IntColumn      get kcal         => integer()();
  IntColumn      get targetMinutes => integer()();
}

class WorkoutSessions extends Table {
  IntColumn      get id         => integer().autoIncrement()();
  DateTimeColumn get startedAt  => dateTime()();
  TextColumn     get routineId  => text()();
  IntColumn      get doneCount  => integer()();
  IntColumn      get totalCount => integer()();
  IntColumn      get seconds    => integer()();
}

class ChallengeEnrollments extends Table {
  IntColumn      get id          => integer().autoIncrement()();
  TextColumn     get challengeId => text()();
  DateTimeColumn get startedOn   => dateTime()();       // midnight local
  DateTimeColumn get abandonedOn => dateTime().nullable()();
  @override
  List<Set<Column>> get uniqueKeys => [{challengeId, startedOn}];
}
```

DAOs: `ReminderDao`, `StepsDao`, `WorkoutDao`, `ChallengeDao`, each exposed as
a `late final` field on `NouriDatabase` alongside the existing five.

`SettingsRows` gains two columns:

```dart
/// Walking stride, centimetres. 72 cm is the adult male average; the
/// distance readout is only as good as this, so it is user-adjustable.
IntColumn get strideCm => integer().withDefault(const Constant(72))();

/// Whether the walk screen may run its simulated source. Debug aid only —
/// the emulator has no step-counter hardware, and a walk that silently
/// invented steps on a real phone would be a lie.
BoolColumn get allowSimulatedSteps =>
    boolean().withDefault(const Constant(false))();
```

- [ ] **Step 1: Write the failing migration test**

```dart
// test/data/db/schema_v4_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';

void main() {
  test('schema is at v4', () {
    final db = NouriDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 4);
  });

  test('a reminder round-trips', () async {
    final db = NouriDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final id = await db.reminderDao.add(
      onDate: DateTime(2026, 9, 20),
      minutes: 9 * 60 + 30,
      title: 'ميعاد الدكتور',
      repeat: ReminderRepeat.once,
    );

    final rows = await db.reminderDao.forDay(DateTime(2026, 9, 20));
    expect(rows, hasLength(1));
    expect(rows.single.id, id);
    expect(rows.single.title, 'ميعاد الدكتور');
    expect(rows.single.minutes, 570);
  });

  test('a walk session round-trips and totals by day', () async {
    final db = NouriDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.stepsDao.addSession(
      startedAt: DateTime(2026, 9, 7, 18),
      seconds: 1800, steps: 3400, metres: 2448, kcal: 122, targetMinutes: 30,
    );
    await db.stepsDao.addSession(
      startedAt: DateTime(2026, 9, 7, 21),
      seconds: 600, steps: 900, metres: 648, kcal: 31, targetMinutes: 10,
    );

    expect(await db.stepsDao.stepsOn(DateTime(2026, 9, 7)), 4300);
    expect(await db.stepsDao.stepsOn(DateTime(2026, 9, 8)), 0);
  });

  test('an upgrade from v3 keeps every existing row', () async {
    // The point of the whole migration: additive only.
    final db = NouriDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.prayerDao.upsertLog(
      date: DateTime(2026, 9, 7),
      prayer: 'fajr',
      scheduledTime: DateTime(2026, 9, 7, 4, 20),
      state: PrayerState.mosque,
    );
    expect(await db.prayerDao.logsForDate(DateTime(2026, 9, 7)), hasLength(1));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/data/db/schema_v4_test.dart`
Expected: FAIL — `schemaVersion` is 3, `reminderDao` undefined.

- [ ] **Step 3: Add the tables, the DAOs and the migration**

In `nouri_database.dart`, bump `schemaVersion` to 4, register the four tables
in `@DriftDatabase`, and extend `onUpgrade`:

```dart
// v4 adds reminders, walking, workouts and challenges. Additive only,
// like every migration before it.
if (from < 4) {
  await m.createTable(reminders);
  await m.createTable(walkSessions);
  await m.createTable(workoutSessions);
  await m.createTable(challengeEnrollments);
  await m.addColumn(settingsRows, settingsRows.strideCm);
  await m.addColumn(settingsRows, settingsRows.allowSimulatedSteps);
}
```

`ReminderDao` needs `add`, `update`, `delete`, `setDone`, `forDay`,
`between`, and `allActive`. `StepsDao` needs `addSession`, `stepsOn`,
`sessionsOn`, `recentSessions`. `WorkoutDao` needs `addSession`,
`sessionsOn`, `recentSessions`. `ChallengeDao` needs `enroll`, `abandon`,
`active`, `history`.

- [ ] **Step 4: Regenerate drift and run the test**

Run: `dart run build_runner build --delete-conflicting-outputs`
Run: `flutter test test/data/db/schema_v4_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the whole suite — the migration must not disturb Slice 1**

Run: `flutter test`
Expected: the existing 474 tests still pass.

- [ ] **Step 6: Commit**

```bash
git add lib/data/db test/data/db/schema_v4_test.dart
git commit -m "feat(db): schema v4 for reminders, walking, workouts, challenges"
```

---

## Task 2: Reminder domain and its notification ID space

**Requirement:** "Calendar-based reminders: open a calendar, pick a day, write
what I want to be reminded of."

A reminder has to fire. The rolling window owns IDs of the form
`daysSince2020 * 32 + slot`, which is about 78,000 today and climbs ~11,700 a
year. Reminders need a disjoint range that no amount of time can collide with.

**Files:**
- Create: `lib/features/reminders/reminder_ids.dart`
- Create: `lib/features/reminders/reminder.dart`
- Test: `test/features/reminders/reminder_test.dart`

**Interfaces — Produces:**

```dart
const kReminderIdBase = 900000000;
int reminderNotificationId(int rowId);       // base + rowId
bool isReminderNotificationId(int id);

DateTime reminderFireTime(Reminder r);
List<DateTime> occurrencesOf(Reminder r, {required DateTime from, required DateTime to});
DateTime? nextOccurrence(Reminder r, {required DateTime after});
```

- [ ] **Step 1: Write the failing test**

```dart
// test/features/reminders/reminder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_slot.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/reminders/reminder.dart';
import 'package:nouri/features/reminders/reminder_ids.dart';

Reminder r({
  DateTime? on,
  int minutes = 9 * 60,
  ReminderRepeat repeat = ReminderRepeat.once,
  int id = 1,
}) =>
    Reminder(
      id: id,
      onDate: on ?? DateTime(2026, 9, 20),
      minutes: minutes,
      title: 'كشف',
      note: null,
      repeat: repeat,
      done: false,
    );

void main() {
  group('the ID space', () {
    test('never collides with the rolling window, even far in the future', () {
      // The window's highest ID a century out must still be below the base.
      final farOff = notificationIdFor(DateTime(2126, 1, 1), NotificationSlot.dailySummary);
      expect(farOff, lessThan(kReminderIdBase));
    });

    test('is recognisable, so a tap can be routed', () {
      expect(isReminderNotificationId(reminderNotificationId(7)), isTrue);
      expect(isReminderNotificationId(notificationIdFor(DateTime(2026, 9, 7), NotificationSlot.adhanFajr)), isFalse);
    });

    test('is derived from the row id, so re-arming overwrites', () {
      expect(reminderNotificationId(7), reminderNotificationId(7));
      expect(reminderNotificationId(7), isNot(reminderNotificationId(8)));
    });
  });

  group('fire time', () {
    test('is the reminder day at its minute', () {
      expect(reminderFireTime(r(on: DateTime(2026, 9, 20), minutes: 570)),
          DateTime(2026, 9, 20, 9, 30));
    });
  });

  group('occurrences', () {
    test('a one-off appears once, and only inside the range', () {
      final one = r(repeat: ReminderRepeat.once, on: DateTime(2026, 9, 20));
      expect(
        occurrencesOf(one, from: DateTime(2026, 9, 1), to: DateTime(2026, 9, 30)),
        [DateTime(2026, 9, 20, 9, 0)],
      );
      expect(
        occurrencesOf(one, from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 30)),
        isEmpty,
      );
    });

    test('a daily reminder never starts before its own date', () {
      final daily = r(repeat: ReminderRepeat.daily, on: DateTime(2026, 9, 20));
      final got = occurrencesOf(daily, from: DateTime(2026, 9, 18), to: DateTime(2026, 9, 22));
      expect(got, [
        DateTime(2026, 9, 20, 9, 0),
        DateTime(2026, 9, 21, 9, 0),
        DateTime(2026, 9, 22, 9, 0),
      ]);
    });

    test('a weekly reminder keeps its weekday', () {
      final weekly = r(repeat: ReminderRepeat.weekly, on: DateTime(2026, 9, 20));
      final got = occurrencesOf(weekly, from: DateTime(2026, 9, 20), to: DateTime(2026, 10, 11));
      expect(got.map((d) => d.weekday).toSet(), {DateTime(2026, 9, 20).weekday});
      expect(got, hasLength(4));
    });

    test('a monthly reminder on the 31st skips months that have no 31st', () {
      // Never silently slides to the 1st of the next month — that would fire
      // a reminder on a day the user did not choose.
      final monthly = r(repeat: ReminderRepeat.monthly, on: DateTime(2026, 1, 31));
      final got = occurrencesOf(monthly, from: DateTime(2026, 1, 1), to: DateTime(2026, 4, 30));
      expect(got.map((d) => d.month), [1, 3]);
    });

    test('crossing a DST boundary keeps the wall-clock minute', () {
      // Dates are constructed, never offset: 09:00 stays 09:00.
      final daily = r(repeat: ReminderRepeat.daily, on: DateTime(2026, 4, 23), minutes: 540);
      final got = occurrencesOf(daily, from: DateTime(2026, 4, 23), to: DateTime(2026, 4, 26));
      expect(got.every((d) => d.hour == 9 && d.minute == 0), isTrue);
    });
  });

  group('nextOccurrence', () {
    test('is null once a one-off has passed', () {
      final one = r(repeat: ReminderRepeat.once, on: DateTime(2026, 9, 20));
      expect(nextOccurrence(one, after: DateTime(2026, 9, 21)), isNull);
    });

    test('rolls forward for a repeat', () {
      final daily = r(repeat: ReminderRepeat.daily, on: DateTime(2026, 9, 20));
      expect(nextOccurrence(daily, after: DateTime(2026, 9, 25, 10)),
          DateTime(2026, 9, 26, 9, 0));
    });
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/reminders/reminder_test.dart`
Expected: FAIL — nothing under `lib/features/reminders/` exists yet.

- [ ] **Step 3: Implement**

`reminder_ids.dart` holds only the two functions and the constant, with no
plugin import, so the scheduler tests stay off the platform channel — the same
reason `notification_channels_ids.dart` exists.

`Reminder` is a plain value class built from a drift `Reminder` row via
`Reminder.fromRow`. `occurrencesOf` walks by **construction**:
`DateTime(y, m, d + n)` for daily, `d + 7*n` for weekly, and for monthly
`DateTime(y, m + n, day)` guarded by a check that the constructed date's `day`
still equals the requested one — that guard is what makes the 31st skip
February rather than land on 2 March.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/reminders/reminder_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reminders test/features/reminders
git commit -m "feat(reminders): the domain and a collision-free ID space"
```

---

## Task 3: Scheduling reminders

**Files:**
- Create: `lib/features/reminders/reminder_scheduler.dart`
- Modify: `lib/core/notifications/notification_route.dart` (add `ReminderRoute`)
- Modify: `lib/core/notifications/notification_channels_ids.dart` — nothing new;
  reminders ride `channelGeneral`, which already exists and is the honest
  importance for "you asked me to remind you", not an alarm.
- Test: `test/features/reminders/reminder_scheduler_test.dart`

**Interfaces — Consumes:** `Reminder`, `reminderNotificationId` (Task 2);
`NotificationGateway`, `ScheduledNotification` (existing).
**Produces:**

```dart
class ReminderScheduler {
  ReminderScheduler(this._gateway);
  Future<void> arm(List<Reminder> reminders, {DateTime? now});
  Future<void> cancelFor(int rowId);
}
```

- [ ] **Step 1: Write the failing test**

```dart
// Uses the same recording fake the existing scheduler tests use.
test('arms only the next occurrence of each reminder', () async {
  final gateway = RecordingGateway();
  await ReminderScheduler(gateway).arm([
    r(id: 1, on: DateTime(2026, 9, 20), repeat: ReminderRepeat.daily),
    r(id: 2, on: DateTime(2026, 9, 25), repeat: ReminderRepeat.once),
  ], now: DateTime(2026, 9, 19, 12));

  expect(gateway.scheduled.map((s) => s.id),
      [reminderNotificationId(1), reminderNotificationId(2)]);
});

test('skips a reminder already marked done', () async {
  final gateway = RecordingGateway();
  await ReminderScheduler(gateway).arm(
    [r(id: 1, on: DateTime(2026, 9, 20)).copyWith(done: true)],
    now: DateTime(2026, 9, 19),
  );
  expect(gateway.scheduled, isEmpty);
});

test('skips a one-off whose time has passed', () async {
  final gateway = RecordingGateway();
  await ReminderScheduler(gateway).arm(
    [r(id: 1, on: DateTime(2026, 9, 20))],
    now: DateTime(2026, 9, 21),
  );
  expect(gateway.scheduled, isEmpty);
});

test('carries a payload that routes back to the reminder', () async {
  final gateway = RecordingGateway();
  await ReminderScheduler(gateway).arm(
    [r(id: 7, on: DateTime(2026, 9, 20))], now: DateTime(2026, 9, 19));
  expect(gateway.scheduled.single.payload, 'reminder:7');
  expect(parseNotificationRoute('reminder:7'), isA<ReminderRoute>());
});

test('cancelling uses the same derived id', () async {
  final gateway = RecordingGateway();
  await ReminderScheduler(gateway).cancelFor(7);
  expect(gateway.cancelled, [reminderNotificationId(7)]);
});
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/reminders/reminder_scheduler_test.dart`
Expected: FAIL — `ReminderScheduler` undefined.

- [ ] **Step 3: Implement the scheduler and the route**

`arm` computes `nextOccurrence` for each reminder, drops nulls and `done`
rows, and schedules on `channelGeneral` with title = the reminder title and
body = the note (or a neutral «فكّرك بده» when there is no note). Add
`ReminderRoute(int id)` to the route union and its `reminder:<id>` parse.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/reminders test/core/notifications`
Expected: PASS, including the existing route tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reminders lib/core/notifications test
git commit -m "feat(reminders): arm the next occurrence on the general channel"
```

---

## Task 4: The calendar month grid

**Requirement:** "open a calendar, pick a day".

The grid maths is pure and deserves its own test — an off-by-one in the leading
blanks is the classic calendar bug and it is invisible in a screenshot.

**Files:**
- Create: `lib/features/reminders/calendar_month.dart`
- Test: `test/features/reminders/calendar_month_test.dart`

**Interfaces — Produces:**

```dart
/// A six-row, seven-column grid. Cells outside the month are null.
class MonthGrid {
  const MonthGrid({required this.year, required this.month, required this.cells});
  final int year, month;
  final List<DateTime?> cells;          // always 42 entries
  static MonthGrid of(int year, int month);
}

const arabicWeekdayHeadings = <String>['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];
```

Weeks start on **Saturday**, as they do in Egypt and Kuwait.

- [ ] **Step 1: Write the failing test**

```dart
void main() {
  test('always 42 cells, so the grid never jumps height between months', () {
    for (var m = 1; m <= 12; m++) {
      expect(MonthGrid.of(2026, m).cells, hasLength(42));
    }
  });

  test('the first day lands under the right heading', () {
    // 1 September 2026 is a Tuesday. Saturday-first, Tuesday is index 3.
    final g = MonthGrid.of(2026, 9);
    expect(g.cells.indexWhere((c) => c?.day == 1), 3);
  });

  test('leading and trailing cells are empty', () {
    final g = MonthGrid.of(2026, 9);
    expect(g.cells.take(3).every((c) => c == null), isTrue);
    expect(g.cells.where((c) => c != null), hasLength(30));
  });

  test('February in a leap year has 29 days', () {
    expect(MonthGrid.of(2024, 2).cells.where((c) => c != null), hasLength(29));
    expect(MonthGrid.of(2026, 2).cells.where((c) => c != null), hasLength(28));
  });

  test('a month starting on Saturday wastes no leading row', () {
    // 1 August 2026 is a Saturday.
    expect(MonthGrid.of(2026, 8).cells.first?.day, 1);
  });

  test('cells are midnight local, so they compare equal to dayOf()', () {
    final c = MonthGrid.of(2026, 9).cells.firstWhere((c) => c != null)!;
    expect(c, DateTime(c.year, c.month, c.day));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/reminders/calendar_month_test.dart`
Expected: FAIL — `MonthGrid` undefined.

- [ ] **Step 3: Implement**

`MonthGrid.of` builds `DateTime(year, month, 1)`, maps Dart's Monday-first
`weekday` (1–7) to a Saturday-first column with `(weekday + 1) % 7`, then fills
`DateTime(year, month, d)` for each day. Never `add(Duration(days: 1))`.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/reminders/calendar_month_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/reminders/calendar_month.dart test/features/reminders/calendar_month_test.dart
git commit -m "feat(reminders): the month grid, Saturday-first"
```

---

## Task 5: The calendar screen and the reminder editor

**Files:**
- Create: `lib/features/reminders/reminder_providers.dart`
- Create: `lib/features/reminders/calendar_screen.dart`
- Create: `lib/features/reminders/reminder_editor_sheet.dart`
- Modify: `lib/features/home/home_screen.dart` — a calendar button in the header
- Test: `test/features/reminders/calendar_screen_test.dart`

**Interfaces — Consumes:** `MonthGrid`, `Reminder`, `ReminderDao`,
`ReminderScheduler`.

The screen: month title with «‹ ›» arrows, the seven Arabic headings, the grid.
A day with reminders carries a gold dot. Today has a gold ring. Tapping a day
selects it and lists that day's reminders below, each with a check to mark done
and a swipe to delete. A «＋» adds one for the selected day, opening the editor
sheet — title field, optional note, a time picker, and the four repeat choices
as chips.

- [ ] **Step 1: Write the failing widget test**

```dart
testWidgets('shows a dot on a day that has a reminder', (t) async {
  final db = inMemoryDatabase(t);
  await db.reminderDao.add(
    onDate: DateTime(2026, 9, 20), minutes: 540,
    title: 'كشف', repeat: ReminderRepeat.once);

  await withLargeSurface(t, () async {
    await t.pumpWidget(testApp(db: db, child: const CalendarScreen()));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('day-dot-2026-09-20')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-dot-2026-09-21')), findsNothing);
  });
});

testWidgets('tapping a day lists its reminders', (t) async { /* ... */ });

testWidgets('adding a reminder writes it and shows it', (t) async { /* ... */ });

testWidgets('marking done never colours the row red', (t) async {
  // Nothing in the app is red. A done reminder goes muted, not punished.
});
```

- [ ] **Step 2: Run and watch it fail.** `flutter test test/features/reminders/calendar_screen_test.dart`

- [ ] **Step 3: Implement the providers, the screen and the sheet.**

Providers: `remindersForMonthProvider` (family on `(year, month)`),
`remindersForDayProvider` (family on a `DateTime`), and a
`reminderSchedulerProvider`. Every write invalidates both and re-arms.

- [ ] **Step 4: Run the tests.** Expected: PASS.

- [ ] **Step 5: Verify on the emulator**

```bash
flutter run -d emulator-5554
```
Open the calendar from Home, add a reminder for today two minutes out, lock the
emulator, and confirm the notification arrives and its tap opens the calendar.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(reminders): the calendar, the editor and the Home entry point"
```

---

## Task 6: Step counting — the source

**Requirement:** "start a walking session (e.g. 30 minutes), count steps live".

Android's `TYPE_STEP_COUNTER` reports a **cumulative** count since boot, not a
delta. A session's steps are therefore `current - atStart`, and the counter
resets to zero on reboot — which must not produce a negative or absurd session.

**Files:**
- Create: `android/app/src/main/kotlin/com/nouri/nouri/StepCounterPlugin.kt`
- Modify: `android/app/src/main/kotlin/com/nouri/nouri/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml` — `ACTIVITY_RECOGNITION`
  and a **non-required** `android.hardware.sensor.stepcounter` feature, so the
  app still installs on a device without one
- Create: `lib/features/steps/step_source.dart`
- Create: `lib/features/steps/sensor_step_source.dart`
- Test: `test/features/steps/step_source_test.dart`

**Interfaces — Produces:**

```dart
abstract interface class StepSource {
  Future<bool> isAvailable();
  Stream<int> cumulativeSteps();     // since boot, monotonic
  void dispose();
}

/// Deterministic, for tests and for the emulator, which has no such hardware.
class SimulatedStepSource implements StepSource { ... }

class SensorStepSource implements StepSource { ... }   // EventChannel client
```

Kotlin side: a `MethodChannel` `com.nouri.nouri/steps` with `isAvailable`, and
an `EventChannel` `com.nouri.nouri/steps_stream` that registers a
`SensorEventListener` on `TYPE_STEP_COUNTER` at `SENSOR_DELAY_UI` and
unregisters in `onCancel`. Nothing is stored natively.

- [ ] **Step 1: Write the failing test**

```dart
test('a simulated source emits a rising cumulative count', () async {
  final s = SimulatedStepSource(startAt: 1000, stepsPerTick: 2,
      tick: const Duration(milliseconds: 1));
  addTearDown(s.dispose);
  final got = await s.cumulativeSteps().take(3).toList();
  expect(got, [1002, 1004, 1006]);
});

test('a simulated source reports itself available', () async {
  expect(await SimulatedStepSource().isAvailable(), isTrue);
});
```

- [ ] **Step 2: Run and watch it fail.**

- [ ] **Step 3: Implement the Dart interface, the simulated source, and the
      Kotlin plugin.**

- [ ] **Step 4: Run the test.** Expected: PASS.

- [ ] **Step 5: Confirm the Kotlin compiles**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL. (A Kotlin error here is a compile failure, not a
test failure — the Dart suite would never catch it.)

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(steps): a step source, hardware and simulated"
```

---

## Task 7: Walk session maths

**Files:**
- Create: `lib/features/steps/walk_session.dart`
- Test: `test/features/steps/walk_session_test.dart`

**Interfaces — Produces:**

```dart
class WalkStats {
  const WalkStats({required this.steps, required this.metres,
      required this.kcal, required this.elapsed});
  final int steps, metres, kcal;
  final Duration elapsed;
}

WalkStats walkStats({
  required int steps,
  required Duration elapsed,
  required int strideCm,
  required int weightGrams,
});

String formatDistance(int metres);   // «١٫٢ كم» over 1000 m, else «٤٥٠ م»
String formatPace(int metres, Duration elapsed);
```

Calories use the standard MET formula, `kcal/min = MET × 3.5 × kg / 200`, with
the MET chosen from pace: 2.8 below 4 km/h, 3.5 to 5.5 km/h, 5.0 above. It is
an estimate and the UI says so.

- [ ] **Step 1: Write the failing test**

```dart
test('distance is steps times stride', () {
  final s = walkStats(steps: 1000, elapsed: const Duration(minutes: 10),
      strideCm: 72, weightGrams: 87000);
  expect(s.metres, 720);
});

test('a reboot mid-session cannot produce negative steps', () {
  final s = walkStats(steps: -5, elapsed: const Duration(minutes: 1),
      strideCm: 72, weightGrams: 87000);
  expect(s.steps, 0);
  expect(s.metres, 0);
});

test('zero elapsed time never divides by zero', () {
  final s = walkStats(steps: 0, elapsed: Duration.zero,
      strideCm: 72, weightGrams: 87000);
  expect(s.kcal, 0);
  expect(formatPace(0, Duration.zero), '—');
});

test('calories scale with weight', () {
  final light = walkStats(steps: 3000, elapsed: const Duration(minutes: 30),
      strideCm: 72, weightGrams: 70000);
  final heavy = walkStats(steps: 3000, elapsed: const Duration(minutes: 30),
      strideCm: 72, weightGrams: 100000);
  expect(heavy.kcal, greaterThan(light.kcal));
});

test('a 30-minute walk at a normal pace lands in a believable range', () {
  // 3400 steps, 87 kg, half an hour: roughly 100-160 kcal. A formula that
  // returned 12 or 1200 would be wrong in a way no unit test of the
  // arithmetic alone would catch.
  final s = walkStats(steps: 3400, elapsed: const Duration(minutes: 30),
      strideCm: 72, weightGrams: 87000);
  expect(s.kcal, inInclusiveRange(90, 180));
});

test('distance formats in Arabic digits, switching unit at a kilometre', () {
  expect(formatDistance(450), contains('م'));
  expect(formatDistance(1200), contains('كم'));
  expect(RegExp(r'[0-9]').hasMatch(formatDistance(1200)), isFalse);
});
```

- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the test.** Expected: PASS.
- [ ] **Step 5: Commit** — `feat(steps): distance, calories and pace`

---

## Task 8: The walk screen

**Files:**
- Create: `lib/features/steps/steps_providers.dart`
- Create: `lib/features/steps/walk_screen.dart`
- Modify: `lib/features/body/body_screen.dart` — a «المشي» card that opens it
- Test: `test/features/steps/walk_screen_test.dart`

A duration chooser (١٥ · ٣٠ · ٤٥ · ٦٠ دقيقة), a start button, then a live
face: a ring counting down the target, the step count large, distance and
calories beneath, pause and finish. Finishing writes a `WalkSession` row.

When `isAvailable()` is false the screen says so plainly — «جهازك مافيهوش حساس
خطوات» — and offers the simulated run **only** when
`settings.allowSimulatedSteps` is on, labelled «تجربة». That switch lives in
الإعدادات and is off by default, so a real phone can never quietly invent steps.

- [ ] **Step 1: Write the failing widget test** — starting a session with a
  simulated source raises the count; finishing persists a row with the right
  totals; an unavailable sensor with simulation off shows the honest message
  and no start button.
- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests.**
- [ ] **Step 5: Verify on the emulator** — turn the simulation switch on in
  الإعدادات, run a session, confirm the row appears in البدن.
- [ ] **Step 6: Commit** — `feat(steps): the live walking session`

---

## Task 9: Workout poses and the frame player

**Requirement:** "show exercise videos as frames".

**Files:**
- Create: `lib/features/workouts/pose.dart`
- Create: `lib/features/workouts/pose_painter.dart`
- Create: `lib/features/workouts/exercise_animation.dart`
- Test: `test/features/workouts/pose_test.dart`

**Interfaces — Produces:**

```dart
enum Joint { head, neck, shoulderL, shoulderR, elbowL, elbowR, handL, handR,
             hip, kneeL, kneeR, footL, footR }

/// Joint positions in a unit box: (0,0) top-left, (1,1) bottom-right.
class Pose {
  const Pose(this.joints);
  final Map<Joint, Offset> joints;
  static Pose lerp(Pose a, Pose b, double t);
}

/// The frame at [t] seconds of a looping keyframe sequence.
Pose frameAt(List<Pose> keyframes, double t, {required double loopSeconds});

class ExerciseAnimation extends StatefulWidget { ... }   // plays it
```

- [ ] **Step 1: Write the failing test**

```dart
test('lerp at the ends returns the endpoints', () {
  expect(Pose.lerp(a, b, 0).joints[Joint.head], a.joints[Joint.head]);
  expect(Pose.lerp(a, b, 1).joints[Joint.head], b.joints[Joint.head]);
});

test('lerp requires both poses to define every joint', () {
  // A missing joint would draw a limb to (0,0) — a figure with its hand
  // pinned to the corner of the screen.
  expect(() => Pose.lerp(a, incomplete, 0.5), throwsArgumentError);
});

test('every pose stays inside the unit box', () {
  for (final p in allCataloguePoses()) {
    for (final o in p.joints.values) {
      expect(o.dx, inInclusiveRange(0, 1));
      expect(o.dy, inInclusiveRange(0, 1));
    }
  }
});

test('the animation loops seamlessly', () {
  final loop = 2.0;
  expect(frameAt(kf, 0, loopSeconds: loop).joints,
         frameAt(kf, loop, loopSeconds: loop).joints);
});

test('frameAt is stable past many loops', () {
  expect(frameAt(kf, 0.5, loopSeconds: 2).joints,
         frameAt(kf, 100.5, loopSeconds: 2).joints);
});
```

- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement.** The painter strokes limbs as rounded lines in
  `NouriColors.text` on `NouriColors.surface`, with the head a filled circle.
- [ ] **Step 4: Run the tests.**
- [ ] **Step 5: Commit** — `feat(workouts): pose keyframes and the frame player`

---

## Task 10: The exercise catalogue and the interval timer

**Requirement:** "guide me through reps/rest (e.g. 30s work, 30s rest)".

**Files:**
- Create: `lib/features/workouts/exercise.dart`
- Create: `lib/features/workouts/workout_catalogue.dart`
- Create: `lib/features/workouts/interval_timer.dart`
- Test: `test/features/workouts/interval_timer_test.dart`
- Test: `test/features/workouts/catalogue_test.dart`

**Interfaces — Produces:**

```dart
class Exercise {
  final String id, nameAr, cueAr;      // cue: one line of form advice
  final List<Pose> keyframes;
  final double loopSeconds;
}

class Routine {
  final String id, nameAr;
  final List<Exercise> exercises;
  final Duration work, rest;
  int get totalCount => exercises.length;
}

enum IntervalPhase { ready, work, rest, done }

class IntervalTimer extends ChangeNotifier {
  IntervalTimer(this.routine);
  IntervalPhase get phase;
  int get index;                 // 0-based exercise
  int get doneCount;             // completed exercises
  Duration get remaining;
  double get fraction;           // doneCount / totalCount
  void start(); void pause(); void skip(); void tick(Duration d);
}
```

`tick(Duration)` rather than an internal `Timer`: the state machine is then
fully testable without pumping real time. The widget owns the ticker.

- [ ] **Step 1: Write the failing test**

```dart
test('starts ready, not running', () {
  expect(IntervalTimer(routine).phase, IntervalPhase.ready);
});

test('work runs for the routine work duration, then rest', () {
  final t = IntervalTimer(routine)..start();     // 30s work, 30s rest
  t.tick(const Duration(seconds: 29));
  expect(t.phase, IntervalPhase.work);
  t.tick(const Duration(seconds: 1));
  expect(t.phase, IntervalPhase.rest);
  expect(t.doneCount, 1);
});

test('a tick longer than the phase does not skip past the next one', () {
  // A backgrounded app resumes with one big tick. Losing a whole rest
  // period to it would be wrong.
  final t = IntervalTimer(routine)..start();
  t.tick(const Duration(seconds: 45));
  expect(t.phase, IntervalPhase.rest);
  expect(t.remaining, const Duration(seconds: 15));
});

test('progress is completed over total — 5 of 20 is 25%', () {
  final t = IntervalTimer(routineOf20);
  for (var i = 0; i < 5; i++) { t.skip(); }
  expect(t.doneCount, 5);
  expect(t.fraction, 0.25);
});

test('the last exercise has no trailing rest', () {
  final t = IntervalTimer(routineOf(2))..start();
  t.tick(const Duration(seconds: 30));   // ex 1 work done -> rest
  t.tick(const Duration(seconds: 30));   // rest done -> ex 2 work
  t.tick(const Duration(seconds: 30));   // ex 2 work done
  expect(t.phase, IntervalPhase.done);
  expect(t.fraction, 1.0);
});

test('every catalogue exercise has a name, a cue and at least two keyframes', () {
  for (final r in kRoutines) {
    expect(r.exercises, isNotEmpty);
    for (final e in r.exercises) {
      expect(e.nameAr.trim(), isNotEmpty);
      expect(e.cueAr.trim(), isNotEmpty);
      expect(e.keyframes.length, greaterThanOrEqualTo(2));
    }
  }
});

test('exercise ids are unique across the catalogue', () { /* ... */ });
```

- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement.** Ship three routines — «تمرين البيت السريع» (8
  exercises), «الجسم كامل» (20), «الإحماء» (5) — built from squat, push-up,
  jumping jack, plank, lunge, crunch, glute bridge, high knees.
- [ ] **Step 4: Run the tests.**
- [ ] **Step 5: Commit** — `feat(workouts): the catalogue and the interval timer`

---

## Task 11: The workout screen

**Files:**
- Create: `lib/features/workouts/workout_providers.dart`
- Create: `lib/features/workouts/workout_screen.dart`
- Modify: `lib/features/body/body_screen.dart` — a «تمارين البيت» card
- Test: `test/features/workouts/workout_screen_test.dart`

Routine picker, then the session: the animation filling the upper half, the
exercise name and cue, a big countdown, a «٥ من ٢٠ — ٢٥٪» progress line, and
pause/skip. Rest phases show the *next* exercise, which is the whole point of a
rest screen. Finishing writes a `WorkoutSession` row — including a partial one,
because five of twenty is real work and Nouri never treats it as nothing.

- [ ] **Step 1: Write the failing widget test** — the picker lists the
  routines; starting shows the first exercise; the progress line reads
  «٥ من ٢٠» after five skips; finishing early still persists a row.
- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests.**
- [ ] **Step 5: Verify on the emulator** — run a routine, confirm the figure
  animates and the rest screen names the next exercise.
- [ ] **Step 6: Commit** — `feat(workouts): the guided session`

---

## Task 12: Challenges

**Requirement:** "e.g. pray all prayers in congregation at the mosque for 40
days, or dhikr challenges".

The 40-day challenge is *the* well-known one, and it has a real rule: it is a
streak, and a missed day restarts it. That is a fact about the challenge, not a
punishment Nouri invents — but the wording around it must stay encouraging, and
the day is neutral, never red.

**Files:**
- Create: `lib/features/challenges/challenge.dart`
- Create: `lib/features/challenges/challenge_catalogue.dart`
- Create: `lib/features/challenges/challenge_evaluator.dart`
- Test: `test/features/challenges/challenge_evaluator_test.dart`

**Interfaces — Produces:**

```dart
enum ChallengeKind { prayerState, athkarType, tasbeehCount, walkMinutes }
enum ChallengeMode { streak, cumulative }   // append-only

class ChallengeDef {
  final String id, nameAr, descriptionAr;
  final ChallengeKind kind;
  final ChallengeMode mode;
  final int targetDays;
  /// For prayerState: the minimum state that counts, e.g. PrayerState.mosque.
  final PrayerState? minState;
  final String? athkarType;
  final int? minCount;
}

class ChallengeProgress {
  final int daysDone, targetDays, currentStreak, bestStreak;
  final bool completedToday;
  double get fraction;
  int get remaining;
}

ChallengeProgress evaluate(
  ChallengeDef def, {
  required DateTime startedOn,
  required DateTime today,
  required List<PrayerLog> prayers,
  required List<AthkarLog> athkar,
  required List<WalkSession> walks,
});
```

- [ ] **Step 1: Write the failing test**

```dart
test('a day counts only when all five prayers meet the bar', () {
  final p = evaluate(kFortyDaysInMosque,
      startedOn: DateTime(2026, 9, 1), today: DateTime(2026, 9, 2),
      prayers: fiveOn(DateTime(2026, 9, 1), PrayerState.mosque),
      athkar: [], walks: []);
  expect(p.daysDone, 1);
});

test('four of five is not a day', () {
  final logs = fiveOn(DateTime(2026, 9, 1), PrayerState.mosque)..removeLast();
  final p = evaluate(kFortyDaysInMosque, startedOn: DateTime(2026, 9, 1),
      today: DateTime(2026, 9, 2), prayers: logs, athkar: [], walks: []);
  expect(p.daysDone, 0);
});

test('congregation at home does not satisfy a mosque challenge', () {
  final p = evaluate(kFortyDaysInMosque, startedOn: DateTime(2026, 9, 1),
      today: DateTime(2026, 9, 2),
      prayers: fiveOn(DateTime(2026, 9, 1), PrayerState.congregation),
      athkar: [], walks: []);
  expect(p.daysDone, 0);
});

test('a streak challenge restarts after a gap, and remembers the best', () {
  // Days 1-3 kept, day 4 missed, days 5-6 kept.
  expect(p.currentStreak, 2);
  expect(p.bestStreak, 3);
});

test('a cumulative challenge does not restart after a gap', () {
  expect(p.daysDone, 5);
  expect(p.fraction, closeTo(5 / 40, 1e-9));
});

test('today is never counted against the user before it ends', () {
  // An unlogged today must not break a streak at 09:00.
  final p = evaluate(kFortyDaysInMosque, startedOn: DateTime(2026, 9, 1),
      today: DateTime(2026, 9, 4),
      prayers: [...fiveOn(DateTime(2026, 9, 1), PrayerState.mosque),
                ...fiveOn(DateTime(2026, 9, 2), PrayerState.mosque),
                ...fiveOn(DateTime(2026, 9, 3), PrayerState.mosque)],
      athkar: [], walks: []);
  expect(p.currentStreak, 3);
  expect(p.completedToday, isFalse);
});

test('days before enrolment do not count', () { /* ... */ });

test('progress never exceeds the target', () { /* ... */ });

test('a dhikr challenge counts a day when the tasbeeh target is reached', () {
  final p = evaluate(kTasbeehThirtyDays, /* athkar rows with progressCount */);
  expect(p.daysDone, 1);
});
```

- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement.** Catalogue: «أربعين يوم في المسجد» (40, streak,
  mosque), «الصلاة في وقتها ٣٠ يوم» (30, streak, onTime), «أذكار الصباح
  والمساء ٤٠ يوم» (40, cumulative), «١٠٠ تسبيحة كل يوم ٣٠ يوم» (30,
  cumulative), «مشي ٣٠ دقيقة ٢١ يوم» (21, cumulative).
- [ ] **Step 4: Run the tests.**
- [ ] **Step 5: Commit** — `feat(challenges): definitions and the evaluator`

---

## Task 13: The challenges panel

**Files:**
- Create: `lib/features/challenges/challenge_providers.dart`
- Create: `lib/features/challenges/challenges_panel.dart`
- Modify: `lib/features/reports/reports_screen.dart` — the panel below the
  weekly summary
- Test: `test/features/challenges/challenges_panel_test.dart`

Enrolled challenges show a ring, «١٢ من ٤٠ يوم», and the streak. Available ones
show a join button. A broken streak reads «ابدأ من تاني — اللي فات مش ضايع»,
never a failure notice, and carries no red.

- [ ] **Step 1: Write the failing widget test** — joining writes an enrolment
  and moves the card to the active list; progress renders in Arabic digits;
  no widget in the tree uses a red colour.
- [ ] **Step 2: Run and watch it fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the tests.**
- [ ] **Step 5: Commit** — `feat(challenges): the panel inside التقارير`

---

## Task 14: The mushaf rendering

**Requirement:** "show Quranic surahs as images or typeset like a mushaf (ayah
numbers, Bismillah on its own line), not plain text with separators."

Typeset, not images: an image cannot scale with the user's text size, cannot be
selected, and would add megabytes. Amiri is already bundled and is a mushaf-style
face.

**Files:**
- Create: `lib/features/athkar/quran_passage.dart`
- Create: `lib/features/athkar/widgets/mushaf_card.dart`
- Modify: `lib/data/athkar/athkar_item.dart` — optional `quran` block
- Modify: `assets/athkar/{morning,evening,sleep}.json`
- Modify: `lib/features/athkar/athkar_screen.dart` — use `MushafCard` when the
  item has a passage
- Test: `test/features/athkar/quran_passage_test.dart`
- Test: `test/features/athkar/mushaf_card_test.dart`

**Interfaces — Produces:**

```dart
class QuranPassage {
  const QuranPassage({required this.surahNameAr, required this.surahNumber,
      required this.bismillah, required this.ayat, this.ayahNumbers});
  final String surahNameAr;
  final int surahNumber;
  final bool bismillah;          // rendered on its own line, never numbered
  final List<String> ayat;
  final List<int>? ayahNumbers;  // defaults to 1..n; set for a partial surah
  int numberFor(int index);
  static QuranPassage fromJson(Map<String, dynamic> j);
}

/// The ayah-end ornament: ۝ with the number inside, in Arabic-Indic digits.
String ayahMarker(int n);
```

The JSON gains, on Qur'anic entries only:

```json
"quran": {
  "surah": "الإخلاص",
  "surahNumber": 112,
  "bismillah": true,
  "ayat": [
    "قُلْ هُوَ ٱللَّهُ أَحَدٌ",
    "ٱللَّهُ ٱلصَّمَدُ",
    "لَمْ يَلِدْ وَلَمْ يُولَدْ",
    "وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ"
  ]
}
```

**The text of `ayat` must be the same words already in `text`, split at ayah
boundaries — nothing added, nothing removed.** A test enforces exactly that, so
this change cannot alter a single letter of religious content and
`docs/athkar-verification.md` stays valid.

- [ ] **Step 1: Write the failing test**

```dart
test('a passage numbers its ayat from one', () {
  expect(passage.numberFor(0), 1);
  expect(passage.numberFor(3), 4);
});

test('a partial surah carries its real ayah numbers', () {
  // Ayat al-Kursi is 2:255, not verse 1 of anything.
  final p = QuranPassage.fromJson(kursiJson);
  expect(p.numberFor(0), 255);
});

test('the marker is Arabic-Indic inside the ornament', () {
  expect(ayahMarker(4), '۝٤');
  expect(RegExp(r'[0-9]').hasMatch(ayahMarker(12)), isFalse);
});

test('bismillah is a flag, never an ayah', () {
  expect(passage.bismillah, isTrue);
  expect(passage.ayat.any((a) => a.contains('بِسْمِ ٱللَّهِ')), isFalse);
});

test('every passage reproduces its item text exactly', () async {
  // The guard that makes this change safe. Strips the Basmala and all
  // diacritics/spacing differences are NOT tolerated -- only the ayah
  // split points may differ.
  final repo = AthkarRepository();
  for (final c in AthkarRepository.categories) {
    for (final item in (await repo.load(c)).items) {
      final p = item.passage;
      if (p == null) continue;
      expect(normalise(p.ayat.join(' ')), contains(normalise(p.ayat.first)));
      expect(normaliseForCompare(item.text),
          contains(normaliseForCompare(p.ayat.join(' '))),
          reason: '${item.id}: the mushaf split changed the text');
    }
  }
});

testWidgets('the mushaf card puts bismillah on its own line', (t) async {
  await t.pumpWidget(testShell(MushafCard(passage: passage, ...)));
  final bismillah = find.text('بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ');
  expect(bismillah, findsOneWidget);
  // Its own Text widget, centred, above the body -- not inline in the flow.
  expect(t.widget<Text>(bismillah).textAlign, TextAlign.center);
});

testWidgets('ayat run together in one justified block with markers between',
    (t) async {
  // A mushaf does not break a line per ayah. One RichText, one span per
  // ayah, a marker span after each.
  expect(find.byType(RichText), findsWidgets);
  expect(find.textContaining('۝'), findsWidgets);
});

testWidgets('a non-Quranic dhikr still renders as before', (t) async {
  await t.pumpWidget(testShell(DhikrCard(item: plainDhikr, ...)));
  expect(find.byType(MushafCard), findsNothing);
});
```

- [ ] **Step 2: Run and watch it fail.**

- [ ] **Step 3: Implement.**

`MushafCard`: a framed panel with a hairline gold border and the surah name in
a header band, the Basmala centred on its own line in Amiri, then a single
justified `RichText` of the ayat with `۝`-plus-number ornaments in gold
between them. Source and repeat pill stay exactly where `DhikrCard` puts them,
so nothing about the flow changes.

- [ ] **Step 4: Run the tests.**

- [ ] **Step 5: Verify on the emulator** — أذكار الصباح, confirm الإخلاص,
  الفلق, الناس and آية الكرسي render as a mushaf page and the rest are unchanged.

- [ ] **Step 6: Commit** — `feat(athkar): typeset Qur'anic athkar as a mushaf page`

---

## Task 15: Documentation and the final sweep

**Files:**
- Modify: `docs/STATUS.md`
- Create: `docs/superpowers/handoffs/2026-09-08-slice1b.md`
- Modify: `docs/install.md` — device checks for reminders and the step sensor

- [ ] **Step 1: Run everything**

```bash
flutter analyze
flutter test
flutter build apk --debug
```

All three must be clean before the handoff is written.

- [ ] **Step 2: Write the handoff**, listing honestly what was verified on the
  emulator, what was not verified anywhere, and every decision taken alone.

- [ ] **Step 3: Update STATUS.md** — schema v4, the new test count, the new
  features, and the standing limits.

- [ ] **Step 4: Commit** — `docs: Slice 1b status and handoff`

---

## Self-review

**Spec coverage.** Calendar reminders → Tasks 2–5. Step counter → Tasks 6–8.
Workout videos as frames with reps/rest and progress → Tasks 9–11. Challenges →
Tasks 12–13. Mushaf athkar → Task 14. Schema for all of it → Task 1. Docs →
Task 15.

**Type consistency.** `WalkStats` is produced in Task 7 and consumed in Task 8.
`Pose`/`frameAt` are produced in Task 9 and consumed by `Exercise` in Task 10
and the screen in Task 11. `ChallengeDef`/`ChallengeProgress` are produced in
Task 12 and consumed in Task 13. `Reminder`/`reminderNotificationId` are
produced in Task 2 and consumed in Tasks 3 and 5. DAO names used in later tasks
(`reminderDao`, `stepsDao`, `workoutDao`, `challengeDao`) all come from Task 1.

**Known gap, stated rather than hidden.** The step counter reads the sensor
only while its screen is open (decision 2). A 30-minute walk with the phone
pocketed and the screen off will reconcile correctly on resume, because
`TYPE_STEP_COUNTER` keeps counting in the OS — but a *live* readout during
those minutes is not there, and neither is a session that survives the app being
killed. Both need the foreground service, which is deliberately deferred.
