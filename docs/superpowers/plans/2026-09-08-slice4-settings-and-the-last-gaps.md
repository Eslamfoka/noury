# Slice 4 — the settings split, the stepper bug, and the last deterministic gaps

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:executing-plans`
> to work this plan task by task. Steps use `- [ ]` so progress is trackable.

**Goal:** fix the two things the user reported from the phone, repair a red
baseline, and close every remaining brief requirement that does not need the AI
layer — so that after this, the only unbuilt thing in the brief is Slice 5.

**Architecture:** three parts, in this order. Part 0 gets the test suite green,
because everything after it is judged against that. Part 1 is the user's own
report (the iqama stepper and the settings split). Part 2 closes the four brief
requirements that are still missing from the deterministic layer — قيام الليل,
مكالمات, وقت الموبايل, and the gentle budget alert — plus the one piece of
infrastructure they need, which is a wider notification slot space.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12.2, Riverpod, Drift,
`flutter_local_notifications`. Everything offline; no network in this app.

**Spec:** `Nouri_Project_Brief.md` §5.1, §5.4, §5.5; and the user's screenshot
of 8 September 2026, transcribed verbatim in Task 2.

## Global Constraints

Carried from `docs/superpowers/handoffs/2026-09-07-start-here.md`, unchanged:

- Do not merge to `master`, do not switch branches, do not force-push.
- **No network calls.** `INTERNET` is absent from the manifest and
  `no_network_test` fails the build if it returns.
- Do not claim any HONOR/MagicOS behaviour has passed unless it ran on the real
  VNE-N41. Only `emulator-5554` is available tonight.
- If a blocking decision appears, take the safest reversible option, document
  it, and continue.
- Nothing is ever red, nothing is ever marked failed, and no copy accuses.
  `palette_test` and the tone tests enforce both.
- Counters read «٠ من ٣», never «٠ / ٣» — `counter_form_test`.
- Dates are constructed, never offset — `day_stepping_test`.
- Every day-scoped value watches `currentDayProvider`, never `DateTime.now()`.
- Append to `NotificationSlot`, never insert.

---

## Part 0 — the baseline is red

### Task 1: `day_rollover_test` only ever passed on 7 September

**Files:**
- Modify: `test/features/home/day_rollover_test.dart:70-84`

**The bug, measured.** On a clean tree at `8ba2108`, `flutter test` reports
**836 passing, 1 failing**:

```
it changes once a day, not once a tick
  Expected: <0>
    Actual: <1>
  same day, no change
```

`STATUS.md` says 837 passing. The suite was green on 7 September and is red on
8 September, and nothing was committed in between.

**Root cause.** `currentDayProvider` reads
`ref.watch(coarseClockProvider).value ?? DateTime.now()`
(`lib/features/home/home_providers.dart:76`). The test's clock override is a
**broadcast** `StreamController`, which drops events emitted while nothing is
listening. The test emits its seeding tick *before* it subscribes:

```dart
await tick(DateTime(2026, 9, 7, 9, 0));          // dropped — no listener yet
container.listen(currentDayProvider, (_, _) => notifications++);
```

So the provider is first built by that `listen`, with the stream still empty,
and falls back to `DateTime.now()` — the machine's real date. On 7 September
that equalled the ticks that followed, so nothing changed and the count stayed
at 0. On any other date the first loop tick moves the value off the real date,
which is one legitimate change, and the assertion fails.

The provider is correct: in production `coarseClockProvider` yields
`DateTime.now()` synchronously as its first event, so the fallback covers a
single frame. The test is what is wrong, and it was wrong on 7 September too —
it just could not fail that day. It asserted nothing.

- [ ] **Step 1: make the failure reproducible and understood**

Run: `flutter test test/features/home/day_rollover_test.dart`
Expected: FAIL, `Expected: <0> Actual: <1>`.

- [ ] **Step 2: fix the test so the seeding tick is actually delivered**

Subscribe before seeding. Replace the body of
`test('it changes once a day, not once a tick')` with:

```dart
  test('it changes once a day, not once a tick', () async {
    // A provider that fired every thirty seconds would rebuild every
    // day-scoped query in the app all day long.
    //
    // The subscription has to exist *before* the seeding tick. The clock
    // override is a broadcast stream, which drops anything emitted while
    // nothing is listening, and `currentDayProvider` falls back to
    // `DateTime.now()` until its first event arrives. Seeding first left the
    // provider holding the machine's real date, so this test only ever
    // asserted anything on 7 September 2026 — and failed on 8 September.
    final sub = container.listen(currentDayProvider, (_, _) {},
        fireImmediately: true);
    await tick(DateTime(2026, 9, 7, 9, 0));
    expect(sub.read(), DateTime(2026, 9, 7),
        reason: 'the seeding tick must have landed before we count changes');

    var notifications = 0;
    container.listen(currentDayProvider, (_, _) => notifications++);

    for (var minute = 0; minute < 60; minute += 5) {
      await tick(DateTime(2026, 9, 7, 10, minute));
    }
    expect(notifications, 0, reason: 'same day, no change');

    await tick(DateTime(2026, 9, 8, 0, 1));
    expect(notifications, 1);
  });
```

The added `expect` on `sub.read()` is the point: it fails loudly if the seeding
tick is ever dropped again, instead of quietly turning the test into a no-op.

- [ ] **Step 3: verify it passes, and that it passes for a reason**

Run: `flutter test test/features/home/day_rollover_test.dart`
Expected: PASS, 4 tests.

Then confirm it is no longer date-blind: temporarily change the seeding tick
and the loop to `DateTime(2030, 1, 1, ...)` and the midnight tick to
`DateTime(2030, 1, 2, 0, 1)`. It must still pass. Revert the temporary change.

- [ ] **Step 4: sweep for the same shape elsewhere**

Run: `grep -rn "coarseClockProvider" test/`
For every hit, confirm the first `tick` happens after a subscription exists.

- [ ] **Step 5: full suite, then commit**

Run: `flutter test`
Expected: 837 passing, 0 failing.

```bash
git add test/features/home/day_rollover_test.dart
git commit -m "test: the rollover test only ever passed on 7 September"
```

---

## Part 1 — what the user reported from the phone

The screenshot of 8 September, transcribed:

> لما باجي ادوس ع الزائد او الناقص عشان ازود او أقلل وقت الإقامة في كليكات
> كتير غلط يعني ممكن ادوس ٣ او ٤ مرات عشان يزود او يقلل (صلح الخطأ)
>
> عايز الاعدادات دي متكنش كلها مع بعض لا عايز مثلا الاشعارات ادوس عليها تفتح
> الخاص ب الاشعارات، فرق وقت الإقامة ادوس عليها تيجي كده مش كله مع بعض

Two things: the ± buttons swallow taps, and الإعدادات should be a menu of
sub-pages rather than one long scroll.

### Task 2: the stepper swallows three taps out of four

**Files:**
- Modify: `lib/features/settings/settings_controller.dart:161-169`
- Modify: `lib/features/settings/settings_screen.dart:313-329`
- Test: `test/features/settings/settings_controller_test.dart`

**Root cause, from the code's own measurement.** `updateIqamaOffset` is:

```dart
Future<void> updateIqamaOffset(String prayer, int minutes) async {
  final s = await db.settingsDao.get();
  final offsets = decodeIqamaOffsets(s.iqamaOffsetsJson)..[prayer] = minutes.clamp(0, 120);
  await db.settingsDao.update(...);
  await _rearmFromSettings();          // <- the whole problem
}
```

and the screen awaits all of it before refreshing:

```dart
onIncrement: () async {
  await controller.updateIqamaOffset(entry.key, entry.value + 5);
  ref.invalidate(settingsProvider);   // <- only after the re-arm
},
```

`DeferredSchedulerPort`'s own doc comment states the cost: **"Arming the alarm
window costs ~11.7s on a mid-range device (262 sequential platform-channel
calls)"**. So one tap holds the UI on the old number for about eleven seconds,
and every tap in that window recomputes `entry.value + 5` from the *same stale*
`entry.value` and writes the identical number. Four taps, one increment. That
is exactly the report.

Two independent faults, and both need fixing — fixing only the second would
leave a 5-minute step costing 11.7 s of dead UI.

**Fix A — the step is a delta, resolved against the database, not the screen.**
The caller says "one step up", not "make it 20". Overlapping taps then compound
instead of colliding.

**Fix B — the write and the re-arm are separated.** The write returns as soon as
the row is written, so the UI refreshes on the first tap. The re-arm is
coalesced: a burst of taps produces one re-arm after the burst, not one per tap.

**Interfaces:**
- Produces: `SettingsController.stepIqamaOffset(String prayer, int delta)
  → Future<int>` — returns the new value. Replaces `updateIqamaOffset`'s use
  from the screen; `updateIqamaOffset(prayer, minutes)` stays for the absolute
  case and for existing tests.
- Produces: `SettingsController.pendingRearm → Future<void>` — completes when
  every coalesced re-arm has finished. Tests await this instead of sleeping.

- [ ] **Step 1: write the failing tests**

Add to `test/features/settings/settings_controller_test.dart`. The fake
scheduler needs to be slow to reproduce the bug, so give it a gate:

```dart
  group('the iqama stepper', () {
    test('four quick taps move it four steps, not one', () async {
      // The bug the user reported: each tap awaited an ~11.7s re-arm before
      // the screen refreshed, so taps two, three and four all recomputed
      // "current + 5" from the same stale number and wrote it again.
      final gate = Completer<void>();
      final scheduler = _GatedScheduler(gate.future);
      final controller = SettingsController(db: db, scheduler: scheduler);

      final start = decodeIqamaOffsets((await db.settingsDao.get()).iqamaOffsetsJson)['dhuhr']!;

      // Four taps with no await between them, which is what a fast finger is.
      final taps = [
        controller.stepIqamaOffset('dhuhr', 5),
        controller.stepIqamaOffset('dhuhr', 5),
        controller.stepIqamaOffset('dhuhr', 5),
        controller.stepIqamaOffset('dhuhr', 5),
      ];
      await Future.wait(taps);

      final after = decodeIqamaOffsets((await db.settingsDao.get()).iqamaOffsetsJson)['dhuhr']!;
      expect(after, start + 20, reason: 'four taps, four steps');

      gate.complete();
      await controller.pendingRearm;
    });

    test('a tap returns before the re-arm does', () async {
      // What makes the screen feel responsive: the row must update on the
      // first tap, not eleven seconds later.
      final gate = Completer<void>();
      final scheduler = _GatedScheduler(gate.future);
      final controller = SettingsController(db: db, scheduler: scheduler);

      final value = await controller.stepIqamaOffset('asr', 5)
          .timeout(const Duration(seconds: 1));

      expect(value, isNotNull);
      expect(scheduler.finished, 0, reason: 'the re-arm has not completed yet');

      gate.complete();
      await controller.pendingRearm;
      expect(scheduler.finished, 1);
    });

    test('a burst of taps costs one re-arm, not four', () async {
      // 262 platform-channel calls each. Four of them is 47 seconds of work
      // for a setting the user changed once.
      final gate = Completer<void>();
      final scheduler = _GatedScheduler(gate.future);
      final controller = SettingsController(db: db, scheduler: scheduler);

      for (var i = 0; i < 4; i++) {
        unawaited(controller.stepIqamaOffset('fajr', 5));
      }
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await controller.pendingRearm;

      expect(scheduler.finished, lessThanOrEqualTo(2),
          reason: 'one re-arm in flight, at most one more queued behind it');
    });

    test('it still clamps, and the clamp does not eat a step', () async {
      final controller = SettingsController(db: db, scheduler: _InstantScheduler());
      await controller.updateIqamaOffset('maghrib', 0);
      final at = await controller.stepIqamaOffset('maghrib', -5);
      expect(at, 0, reason: 'zero is the floor');
      await controller.pendingRearm;
    });
  });
```

with, at the bottom of the file:

```dart
/// A scheduler that does not finish until it is let go.
///
/// Stands in for the real one, which the controller measures at ~11.7s.
class _GatedScheduler implements SchedulerPort {
  _GatedScheduler(this._gate);
  final Future<void> _gate;
  int started = 0;
  int finished = 0;

  @override
  Future<void> rearm(SchedulingConfig config) async {
    started++;
    await _gate;
    finished++;
  }
}

class _InstantScheduler implements SchedulerPort {
  int calls = 0;
  @override
  Future<void> rearm(SchedulingConfig config) async => calls++;
}
```

- [ ] **Step 2: run them and watch them fail**

Run: `flutter test test/features/settings/settings_controller_test.dart`
Expected: FAIL — `stepIqamaOffset` and `pendingRearm` are not defined.

- [ ] **Step 3: implement**

In `settings_controller.dart`, add the coalescing re-arm and the delta step:

```dart
  /// The re-arm currently running, if any.
  Future<void>? _rearming;

  /// True when a change landed while a re-arm was already in flight.
  bool _rearmAgain = false;

  /// Completes when every requested re-arm has finished.
  ///
  /// Nothing in the app awaits this; it exists so tests can wait for the
  /// background work instead of sleeping and hoping.
  Future<void> get pendingRearm async {
    while (_rearming != null) {
      await _rearming;
    }
  }

  /// Requests a re-arm without waiting for it.
  ///
  /// Arming the window costs ~11.7s (262 platform-channel calls), so a caller
  /// that awaited it would hold the UI still for eleven seconds — which is
  /// what made the iqama stepper swallow three taps out of four. Requests that
  /// arrive while one is running collapse into a single follow-up run, so a
  /// burst of taps costs one re-arm after the burst rather than one each.
  void _requestRearm() {
    if (_rearming != null) {
      _rearmAgain = true;
      return;
    }
    _rearming = () async {
      try {
        do {
          _rearmAgain = false;
          await _rearmFromSettings();
        } while (_rearmAgain);
      } finally {
        _rearming = null;
      }
    }();
  }

  /// Moves one iqama offset by [delta] minutes and returns where it landed.
  ///
  /// A delta rather than an absolute value, deliberately. The screen used to
  /// compute `shown + 5` and send that, which is only correct while the shown
  /// value is current — and it was not, because the previous tap was still
  /// inside an 11.7-second re-arm. Two taps then sent the same number twice.
  /// Resolving the delta against the row itself makes overlapping taps
  /// compound, which is what the user expects from a button pressed twice.
  Future<int> stepIqamaOffset(String prayer, int delta) async {
    final landed = await _writeQueue(() async {
      final s = await db.settingsDao.get();
      final offsets = decodeIqamaOffsets(s.iqamaOffsetsJson);
      final next = ((offsets[prayer] ?? 0) + delta).clamp(0, 120);
      offsets[prayer] = next;
      await db.settingsDao.update(SettingsRowsCompanion(
          iqamaOffsetsJson: Value(encodeIqamaOffsets(offsets))));
      return next;
    });
    _requestRearm();
    return landed;
  }

  /// Serialises read-modify-write pairs.
  ///
  /// Without this, two taps can both read the row before either writes, and
  /// the second write overwrites the first — the same lost update the delta
  /// was meant to prevent, one layer down.
  Future<T> _writeQueue<T>(Future<T> Function() work) {
    final next = _queue.then((_) => work());
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _queue = Future<void>.value();
```

`updateIqamaOffset` keeps its existing signature and behaviour for its existing
callers, but goes through the same queue and the same non-blocking re-arm:

```dart
  Future<void> updateIqamaOffset(String prayer, int minutes) async {
    await _writeQueue(() async {
      final s = await db.settingsDao.get();
      final offsets = decodeIqamaOffsets(s.iqamaOffsetsJson)
        ..[prayer] = minutes.clamp(0, 120);
      await db.settingsDao.update(SettingsRowsCompanion(
          iqamaOffsetsJson: Value(encodeIqamaOffsets(offsets))));
    });
    _requestRearm();
  }
```

Then in `settings_screen.dart`, the two callbacks become deltas:

```dart
                onDecrement: () async {
                  await controller.stepIqamaOffset(entry.key, -5);
                  ref.invalidate(settingsProvider);
                },
                onIncrement: () async {
                  await controller.stepIqamaOffset(entry.key, 5);
                  ref.invalidate(settingsProvider);
                },
```

- [ ] **Step 4: run the tests**

Run: `flutter test test/features/settings/`
Expected: PASS.

- [ ] **Step 5: check every other caller of a slow settings write**

`updateLocation`, `updateMethod`, `updateMadhab`, `toggleChannel` and
`detectLocation` all `await _rearmFromSettings()` too. A toggle is one tap and
does not compound, so the stale-read half does not apply — but the eleven
seconds do. Convert each to `_requestRearm()` so no settings control blocks the
UI on the window. Confirm `settings_controller_test.dart` still passes; where a
test asserted `scheduler.calls == 1` immediately after a call, insert
`await controller.pendingRearm;` first.

- [ ] **Step 6: full suite, then commit**

```bash
flutter test
git add lib/features/settings/ test/features/settings/
git commit -m "fix(settings): the ± buttons swallowed three taps out of four"
```

### Task 3: الإعدادات becomes a menu, not one long scroll

**Files:**
- Create: `lib/features/settings/settings_sections.dart`
- Create: `lib/features/settings/settings_section_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Test: `test/features/settings/settings_screen_test.dart`

The seven sections already exist as `_Section` widgets in one column:
الإشعارات (117), الدوام (171), البدن والمشي (224), مواقيت الصلاة (256),
فرق وقت الإقامة (313), الورد (333), عن نوري (353). The change is navigational
only — **no setting moves between sections, and no control changes behaviour**,
so the existing per-control tests keep their meaning.

**Interfaces:**
- Produces: `enum SettingsSection { notifications, duty, body, prayerTimes,
  iqamaOffsets, wird, about }` with `String get title` and `IconData get icon`.
- Produces: `SettingsSectionScreen({required SettingsSection section})` — a
  `Scaffold` with the section's title as its app-bar title and only that
  section's controls in its body.

- [ ] **Step 1: write the failing tests**

```dart
  testWidgets('الإعدادات opens as a list of sections, not every control',
      (tester) async {
    await pumpSettings(tester);

    for (final s in SettingsSection.values) {
      expect(find.text(s.title), findsOneWidget);
    }
    // A control from inside a section is not on the index page.
    expect(find.text('فرق التاريخ الهجري'), findsNothing);
  });

  testWidgets('tapping a section opens it, and it holds its own controls',
      (tester) async {
    await pumpSettings(tester);
    await tester.tap(find.text('فرق وقت الإقامة'));
    await tester.pumpAndSettle();

    expect(find.text('الفجر'), findsOneWidget);
    expect(find.text('العشاء'), findsOneWidget);
    // and nothing from another section
    expect(find.text('هدف التسبيح'), findsNothing);
  });

  testWidgets('every section is reachable, and every one has something in it',
      (tester) async {
    for (final s in SettingsSection.values) {
      await pumpSettings(tester);
      await tester.tap(find.text(s.title));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSectionScreen), findsOneWidget);
      expect(find.descendant(of: find.byType(SettingsSectionScreen),
          matching: find.byType(Text)).evaluate().length, greaterThan(1),
          reason: '${s.title} opened empty');
    }
  });
```

- [ ] **Step 2: run and watch them fail**

Run: `flutter test test/features/settings/settings_screen_test.dart`
Expected: FAIL — `SettingsSection` undefined.

- [ ] **Step 3: extract each section's children into its own builder**

In `settings_sections.dart`:

```dart
enum SettingsSection {
  notifications('الإشعارات', Icons.notifications_none),
  duty('الدوام', Icons.badge_outlined),
  body('البدن والمشي', Icons.directions_walk),
  prayerTimes('مواقيت الصلاة', Icons.schedule),
  iqamaOffsets('فرق وقت الإقامة', Icons.more_time),
  wird('الورد', Icons.menu_book_outlined),
  about('عن نوري', Icons.info_outline);

  const SettingsSection(this.title, this.icon);
  final String title;
  final IconData icon;
}
```

Move each `_Section`'s `children:` list into a method
`List<Widget> _buildX(BuildContext, WidgetRef, SettingsRow, SettingsController)`
in `settings_section_screen.dart`, keeping the bodies byte-identical apart from
their new parameters. `SettingsSectionScreen` switches on the enum.

- [ ] **Step 4: the index page**

`settings_screen.dart` becomes the notification-status panel (which is a
warning surface and belongs on the way in, not buried) followed by one tappable
row per section, each pushing `SettingsSectionScreen`.

- [ ] **Step 5: run the tests**

Run: `flutter test test/features/settings/`
Expected: PASS. Existing control tests will need their `pump` helper to open
the owning section first — update the helper, not the assertions.

- [ ] **Step 6: full suite, then commit**

```bash
flutter test
git add lib/features/settings/ test/features/settings/
git commit -m "feat(settings): a menu of sections, not one long scroll"
```

---

## Part 2 — the last deterministic gaps in the brief

### Task 4: widen the slot space, deliberately

**Files:**
- Modify: `lib/core/notifications/notification_slot.dart:6`
- Test: `test/core/notifications/notification_slot_test.dart`

The slot space is full: 31 slots against `kSlotsPerDay = 32`. قيام الليل and
the budget nudge need two more. `STATUS.md` says raising it "renumbers every
alarm already on a device, so it needs a deliberate re-arm rather than a quiet
bump" — this task is that deliberation.

**Why it is safe.** `LocalNotificationGateway.cancelAllBelow(ceiling)` does not
compute the IDs it cancels; it enumerates `pendingNotificationRequests()` from
the plugin and cancels every one below the ceiling. `RollingWindowScheduler
.rearm()` opens with `cancelAllBelow(kOutOfWindowIdBase)` and runs on every
launch. So alarms written under the old stride are *found and cancelled* by the
first re-arm after the upgrade, whatever their numbering. There are no orphans.

The new IDs are `daysSince2020 * 64 + slot` ≈ 156,000 today, growing ~23,400 a
year — it does not reach `kOutOfWindowIdBase` (900,000,000) for some 38,000
years, so reminders stay safe.

- [ ] **Step 1: write the test that states the property**

```dart
  test('a re-arm cancels alarms it could never have numbered itself', () async {
    // The orphan question, asked directly. Raising kSlotsPerDay renumbers
    // every future alarm; what makes that safe is that clearing the window
    // enumerates what is actually pending rather than recomputing IDs.
    final gateway = FakeGateway();
    // An ID from the old stride of 32 that no current slot can produce.
    await gateway.schedule(ScheduledNotification(
      id: 78000 * 32 + 7, slot: NotificationSlot.adhanFajr,
      when: DateTime(2026, 9, 9), title: 't', body: 'b', channelId: 'adhan_v2'));
    // And a reminder, which must survive.
    await gateway.schedule(ScheduledNotification(
      id: kOutOfWindowIdBase + 1, slot: NotificationSlot.adhanFajr,
      when: DateTime(2026, 9, 9), title: 't', body: 'b', channelId: 'adhan_v2'));

    await gateway.cancelAllBelow(kOutOfWindowIdBase);

    expect(await gateway.pendingIds(), [kOutOfWindowIdBase + 1]);
  });

  test('the widened stride still exceeds the slot count', () {
    expect(NotificationSlot.values.length, lessThan(kSlotsPerDay));
  });

  test('the ID space does not reach the reminder base this century', () {
    final id = notificationIdFor(DateTime(2100, 1, 1), NotificationSlot.values.last);
    expect(id, lessThan(kOutOfWindowIdBase));
  });
```

- [ ] **Step 2: run — the first two should already pass, and must**

Run: `flutter test test/core/notifications/notification_slot_test.dart`

- [ ] **Step 3: raise the stride**

```dart
/// Stride between days in the ID space.
///
/// Raised from 32 to 64 on 8 September 2026, when the slot list reached 31 of
/// 32 and قيام الليل and the budget nudge still had to fit.
///
/// Renumbering every future alarm is safe *only* because clearing the window
/// enumerates what is pending rather than recomputing IDs:
/// `LocalNotificationGateway.cancelAllBelow` reads
/// `pendingNotificationRequests()` and cancels everything below the ceiling,
/// so alarms written under the old stride are found and removed by the first
/// re-arm after the upgrade — which happens on the next launch. Do not change
/// this again without checking that property still holds.
const kSlotsPerDay = 64;
```

- [ ] **Step 4: run the notification suite, then commit**

```bash
flutter test test/core/notifications/
git add lib/core/notifications/notification_slot.dart test/core/notifications/
git commit -m "feat(notifications): widen the slot stride to 64, deliberately"
```

### Task 5: قيام الليل — the one religious reminder that was never built

**Files:**
- Modify: `lib/core/notifications/notification_slot.dart` (append `qiyam`)
- Modify: `lib/core/notifications/rolling_window_scheduler.dart`
- Modify: `lib/features/settings/settings_section_screen.dart` (a toggle)
- Test: `test/core/notifications/qiyam_reminder_test.dart`

**The brief, §5.1:** "**Qiyam al-layl:** a reminder, timed around the user's
sleep schedule." Nothing in `lib/` mentions قيام — `grep -rn "قيام\|qiyam"
lib/ test/` returns nothing. It is the only religious item in §5.1 with no
code at all.

**Timing.** The last third of the night, which is the sunnah time, runs from
`isha + 2/3 × (fajr_tomorrow − isha)` to fajr. Nouri wakes the user partway
into it rather than at its start, and **never on a night the shift makes it
impossible** — a night shift means the user is at work through the whole last
third, and a reminder then is noise. Off by default: waking someone for a
voluntary prayer is not something an app should opt them into.

**Interfaces:**
- Produces: `DateTime? qiyamTimeFor({required DateTime isha, required DateTime
  fajrTomorrow, required ShiftPattern shift})` in a new
  `lib/features/prayers/qiyam.dart` — null when the shift rules it out.
- Consumes: `SchedulingConfig.notifyQiyam` (default `false`).

- [ ] **Step 1: write the failing tests**

```dart
  test('it lands in the last third of the night, not at its start', () {
    // isha 20:00, fajr 04:00 -> night is 8h, last third opens at 01:20.
    final at = qiyamTimeFor(
      isha: DateTime(2026, 9, 8, 20, 0),
      fajrTomorrow: DateTime(2026, 9, 9, 4, 0),
      shift: ShiftPattern.morning,
    )!;
    expect(at.isAfter(DateTime(2026, 9, 9, 1, 20)), isTrue);
    expect(at.isBefore(DateTime(2026, 9, 9, 4, 0)), isTrue);
  });

  test('it leaves room before fajr, so it is not a second fajr alarm', () {
    final at = qiyamTimeFor(
      isha: DateTime(2026, 9, 8, 20, 0),
      fajrTomorrow: DateTime(2026, 9, 9, 4, 0),
      shift: ShiftPattern.morning,
    )!;
    expect(DateTime(2026, 9, 9, 4, 0).difference(at).inMinutes,
        greaterThanOrEqualTo(45));
  });

  test('a night shift gets none — the user is at work through all of it', () {
    expect(
      qiyamTimeFor(
        isha: DateTime(2026, 9, 8, 20, 0),
        fajrTomorrow: DateTime(2026, 9, 9, 4, 0),
        shift: ShiftPattern.night,
      ),
      isNull,
    );
  });

  test('it is constructed from the night, never offset by a day', () {
    // The night crosses midnight; a date built with add(Duration(days: 1))
    // is 24 hours and breaks across DST. day_stepping_test guards the shape;
    // this checks the value.
    final at = qiyamTimeFor(
      isha: DateTime(2026, 10, 29, 18, 0),
      fajrTomorrow: DateTime(2026, 10, 30, 4, 30),
      shift: ShiftPattern.morning,
    )!;
    expect(at.day, 30);
  });

  test('off by default — Nouri does not opt anyone into waking at 2am', () {
    const config = SchedulingConfig(geo: kKuwait, iqamaOffsets: {});
    expect(config.notifyQiyam, isFalse);
  });

  test('with it on, exactly one qiyam alarm is armed per night', () async {
    final armed = await armWindow(notifyQiyam: true);
    final qiyam = armed.where((n) => n.slot == NotificationSlot.qiyam);
    expect(qiyam.length, kWindowDays);
  });

  test('the copy invites and never accuses', () async {
    final armed = await armWindow(notifyQiyam: true);
    final n = armed.firstWhere((n) => n.slot == NotificationSlot.qiyam);
    for (final word in ['فاتتك', 'ضيعت', 'فشل', 'كسلان']) {
      expect('${n.title} ${n.body}'.contains(word), isFalse);
    }
  });
```

- [ ] **Step 2: run and watch fail.** Run:
`flutter test test/core/notifications/qiyam_reminder_test.dart`

- [ ] **Step 3: implement `lib/features/prayers/qiyam.dart`**

```dart
/// When to offer قيام الليل, or null when the night does not allow it.
///
/// The last third of the night is the sunnah time. Nouri wakes the user a
/// little way into it rather than at its opening — the opening is often barely
/// past midnight, which is a strange hour to be woken — and never inside the
/// last 45 minutes, where it would arrive as a second fajr alarm.
///
/// A night shift returns null. The user is at work from 22:00 to 07:00, so the
/// entire last third is duty time, and a reminder there is noise rather than an
/// invitation.
DateTime? qiyamTimeFor({
  required DateTime isha,
  required DateTime fajrTomorrow,
  required ShiftPattern shift,
}) {
  if (shift == ShiftPattern.night) return null;

  final night = fajrTomorrow.difference(isha);
  if (night <= const Duration(hours: 3)) return null;

  final lastThirdOpens = isha.add(night * (2 / 3));
  final at = lastThirdOpens.add(const Duration(minutes: 20));
  final latest = fajrTomorrow.subtract(const Duration(minutes: 45));
  return at.isAfter(latest) ? latest : at;
}
```

Note `isha.add(...)` is an offset *within a night*, not a day step — it is
minutes-to-hours, which is exactly what `Duration` arithmetic is for. The
guard `day_stepping_test` targets `add(Duration(days:))` specifically.

- [ ] **Step 4: wire it into the window**

Append `qiyam` to `NotificationSlot` (never insert). Add `notifyQiyam = false`
to `SchedulingConfig`. In `rearm`, for each day in the window compute
`qiyamTimeFor` from that day's isha and the *next* day's fajr, and arm:

- title: `قيام الليل`
- body: `الثلث الأخير — لو قدرت` (invites; asserts clean against the tone list)
- channel: the athkar channel, not the adhan one — this is not an adhan.

- [ ] **Step 5: a toggle in الإشعارات**, defaulting off, with a one-line
explanation that it is silent on night shifts.

- [ ] **Step 6: run, then commit**

```bash
flutter test
git add -A
git commit -m "feat(prayers): قيام الليل, in the last third and never on a night shift"
```

### Task 6: مكالمات — an hour, placed by shift

**Files:**
- Modify: `lib/features/planner/daily_tasks.dart`
- Test: `test/features/planner/daily_tasks_test.dart`

**The brief, §5.5:** "**Calls time:** **one hour**, placed by shift — after
morning/evening shift or before sleep; for the night shift, before duty or
during it if there's a chance."

It exists in `lib/features/planner/example_day.dart:210` — the hand-worked
example — and nowhere else. `dailyTasksFor` never emits it, so the real planner
has never placed it. The example promises something the app does not do.

- [ ] **Step 1: write the failing tests**

```dart
  test('an hour of calls is planned, every day', () {
    final tasks = dailyTasksFor(date: DateTime(2026, 9, 8), shift: ShiftPattern.morning);
    final calls = tasks.firstWhere((t) => t.id == 'calls');
    expect(calls.duration, const Duration(hours: 1));
  });

  test('on a morning shift it sits after work, not before it', () {
    final calls = dailyTasksFor(date: DateTime(2026, 9, 8), shift: ShiftPattern.morning)
        .firstWhere((t) => t.id == 'calls');
    expect((calls.anchor as FlexibleAnchor).preferredBlock, DayBlockKind.afterWork);
  });

  test('on a night shift it goes before duty, which is the evening', () {
    final calls = dailyTasksFor(date: DateTime(2026, 9, 8), shift: ShiftPattern.night)
        .firstWhere((t) => t.id == 'calls');
    expect((calls.anchor as FlexibleAnchor).preferredBlock, DayBlockKind.evening);
  });

  test('it is light — an hour on the phone is not a heavy task', () {
    final calls = dailyTasksFor(date: DateTime(2026, 9, 8), shift: ShiftPattern.morning)
        .firstWhere((t) => t.id == 'calls');
    expect(calls.weight, TaskWeight.light);
  });

  test('a day that cannot hold it defers it by name, not silently', () {
    // planDay's existing deferral path; this only checks calls participates.
    final plan = planDay(/* a saturated day */);
    expect(plan.deferred.map((d) => d.task.id), contains('calls'));
  });
```

- [ ] **Step 2–4:** run (fail), add the task to `dailyTasksFor` under a
`includeCalls = true` flag matching the file's existing style, run (pass).

- [ ] **Step 5: commit**

```bash
git commit -am "feat(planner): مكالمات — an hour, placed by shift"
```

### Task 7: وقت الموبايل — a reserved slot with a cap

**Files:**
- Create: `lib/features/phone/phone_budget.dart`
- Create: `lib/features/phone/phone_time_card.dart`
- Modify: `lib/data/db/` — a `phone_sessions` table, schema v9
- Test: `test/features/phone/phone_budget_test.dart`

**The brief, §5.5:** "**Phone/social time:** Nouri reserves a **fixed slot** and
notifies if exceeded (the user wants a hard-ish cap here)."

**A decision taken alone, and why it is the reversible one.** "Notifies if
exceeded" could mean Nouri reads actual device usage. That needs
`PACKAGE_USAGE_STATS` — a special-access permission granted through a system
settings page, invisible to the emulator, and the single most privacy-heavy
permission an app can hold. It would also make Nouri *infer* rather than ask,
which this project has refused everywhere else: a fasting day is the user's
word, a prayer is logged not detected.

So: **the user starts the slot and Nouri times it.** A card in the planned day
with a start button, a countdown against the cap, and a gentle note when the
cap passes. Reversible in both directions — the UsageStats path can replace the
source behind the same widget later, and the cap is a setting.

Default cap: **60 minutes**, matching the calls hour the brief does name.
Documented in `docs/planner-decisions.md` as decision 7.

- [ ] **Step 1: write the failing tests**

```dart
  test('a session under the cap is fine, and says so without praise', () {
    final s = PhoneBudget(cap: const Duration(minutes: 60));
    expect(s.stateFor(const Duration(minutes: 20)), PhoneBudgetState.within);
  });

  test('the cap is a line, not a wall — passing it is reported, not blocked', () {
    final s = PhoneBudget(cap: const Duration(minutes: 60));
    expect(s.stateFor(const Duration(minutes: 75)), PhoneBudgetState.over);
  });

  test('nothing about being over is red', () {
    // palette_test covers the app; this states the intent locally.
    expect(PhoneBudgetState.over.colorToken, isNot('red'));
  });

  test('the copy states the number and does not scold', () {
    final note = PhoneBudget(cap: const Duration(minutes: 60))
        .noteFor(const Duration(minutes: 75));
    for (final word in ['فاتتك', 'ضيعت', 'فشل', 'كسلان', 'مدمن']) {
      expect(note.contains(word), isFalse);
    }
  });

  test('two sessions in a day add up', () async {
    await dao.log(date: DateTime(2026, 9, 8), minutes: 20);
    await dao.log(date: DateTime(2026, 9, 8), minutes: 25);
    expect(await dao.totalFor(DateTime(2026, 9, 8)), 45);
  });

  test("yesterday's phone time is not today's", () async {
    await dao.log(date: DateTime(2026, 9, 7), minutes: 90);
    expect(await dao.totalFor(DateTime(2026, 9, 8)), 0);
  });
```

- [ ] **Step 2–5:** run (fail); add the table and a schema v9 migration
following the existing migration pattern exactly; implement; run (pass).

- [ ] **Step 6:** add `phone-time` to `dailyTasksFor` as a light flexible task
in the evening, one hour, so the plan reserves the slot the brief asks for.

- [ ] **Step 7: commit**

```bash
git commit -am "feat(phone): a reserved slot for phone time, and a cap that reports"
```

### Task 8: the gentle budget alert

**Files:**
- Modify: `lib/core/notifications/notification_slot.dart` (append `budgetNudge`)
- Modify: `lib/core/notifications/rolling_window_scheduler.dart`
- Test: `test/features/finance/budget_alert_test.dart`

**The brief, §5.4:** "**Gentle budget alerts:** when a category nears its limit,
notify softly (not an alarm) so month-end isn't a surprise."

`BudgetStatus` already computes everything needed — `isOver`, `isAheadOfPace`,
`pacedAllowance` — and its own comment says "this is what makes an alert useful
rather than alarming". The computation is shown on screen. **No notification is
ever sent.** That is the gap.

**Armed for today only, from today's real numbers.** Budget state is not known
a fortnight ahead, so unlike the adhan this cannot be armed across the window.
It is computed at re-arm time — which runs on every launch and every settings
change — and armed for this evening only. If the app is not opened, the nudge
reflects the last known state, which is honest and is what the code comment
should say.

- [ ] **Step 1: write the failing tests**

```dart
  test('a category comfortably inside its budget says nothing', () async {
    final armed = await armWithSpending({'food': 100}, limits: {'food': 1000}, day: 15);
    expect(armed.where((n) => n.slot == NotificationSlot.budgetNudge), isEmpty);
  });

  test('ahead of pace on day 4 is worth one soft note', () async {
    // 60% of the food budget is fine on day 18 and worth noticing on day 4 —
    // BudgetStatus.pacedAllowance's own words.
    final armed = await armWithSpending({'food': 600}, limits: {'food': 1000}, day: 4);
    expect(armed.where((n) => n.slot == NotificationSlot.budgetNudge).length, 1);
  });

  test('60% on day 18 says nothing — the same number, a different month', () async {
    final armed = await armWithSpending({'food': 600}, limits: {'food': 1000}, day: 18);
    expect(armed.where((n) => n.slot == NotificationSlot.budgetNudge), isEmpty);
  });

  test('three stretched categories are one note, not three', () async {
    final armed = await armWithSpending(
      {'food': 600, 'transport': 600, 'personal': 600},
      limits: {'food': 1000, 'transport': 1000, 'personal': 1000}, day: 4);
    expect(armed.where((n) => n.slot == NotificationSlot.budgetNudge).length, 1);
  });

  test('it goes on a quiet channel, not the adhan one', () async {
    final armed = await armWithSpending({'food': 600}, limits: {'food': 1000}, day: 4);
    final n = armed.firstWhere((x) => x.slot == NotificationSlot.budgetNudge);
    expect(n.channelId, isNot(kAdhanChannelId));
  });

  test('it names the number and does not accuse', () async {
    final armed = await armWithSpending({'food': 600}, limits: {'food': 1000}, day: 4);
    final n = armed.firstWhere((x) => x.slot == NotificationSlot.budgetNudge);
    for (final word in ['فاتتك', 'ضيعت', 'فشل', 'إسراف', 'مبذر']) {
      expect('${n.title} ${n.body}'.contains(word), isFalse);
    }
  });
```

- [ ] **Step 2–4:** run (fail), implement, run (pass).

- [ ] **Step 5: commit**

```bash
git commit -am "feat(finance): a gentle budget note, once, when a category is ahead of pace"
```

---

## Part 3 — verification

### Task 9: run it on the emulator

The user asked for emulator verification tonight. `docs/superpowers/handoffs/
2026-09-08-slices-2-and-3.md` records the machine's limit: **15.9 GB RAM, and
a Gradle build alongside a running emulator has killed the emulator twice.**
So: build first, then start the emulator, then install. Never both at once.

- [ ] **Step 1:** `flutter build apk --release` with no emulator running.
- [ ] **Step 2:** start `nourdm-api35` with `-memory 1536`.
- [ ] **Step 3:** `adb install -r build/app/outputs/flutter-apk/app-release.apk`
- [ ] **Step 4: the stepper, which is the whole point.** Open الإعدادات →
  فرق وقت الإقامة. Tap `+` on الظهر four times as fast as possible. It must
  read 20 minutes more than it started, not 5. Screenshot it.
- [ ] **Step 5: the sections.** Confirm الإعدادات opens as seven rows and each
  one opens its own page.
- [ ] **Step 6: the alarms survived the stride change.**
  `adb shell dumpsys alarm | grep com.nouri.nouri | wc -l` — the count should
  be in the same range as before (~230), not doubled. A doubled count means
  old-stride alarms were not cleared and the safety argument in Task 4 is
  wrong.
- [ ] **Step 7: قيام** — turn the toggle on, and confirm one alarm per night
  appears in the last third.

### Task 10: write the handoff and update STATUS

- [ ] `docs/superpowers/handoffs/2026-09-09-slice4.md` — what was built, what
  was verified on the emulator, what was not verified anywhere, and what still
  needs the user.
- [ ] `docs/STATUS.md` — test count, schema version, the new guards, and the
  known limits that changed.
- [ ] `docs/planner-decisions.md` — decision 7, the phone-time source.

---

## Self-review

**Spec coverage.** §5.1 قيام → Task 5. §5.4 gentle alerts → Task 8. §5.5
calls → Task 6, phone/social → Task 7. The user's screenshot → Tasks 2 and 3.
The red baseline → Task 1. Everything else in the brief is either built or is
Slice 5 (book recommendations, the skill path, the daily religious content, the
AI re-plan and the AI report), which needs the API key and the network that
Slice 1 forbids.

**Not in this plan, on purpose.** Marking a task done from the planned day, and
re-planning around a missed one: both are decisions about where the truth lives
and what to move, and `docs/planner-decisions.md` records why guessing at them
has already caused two bugs. The rota. The adhan recitation, which needs the
user's OGG. All four need the user.

**Type consistency.** `stepIqamaOffset(String, int) → Future<int>` and
`pendingRearm → Future<void>` are used identically in Tasks 2 and 9.
`SettingsSection` and `SettingsSectionScreen` in Tasks 3 and 5.
`qiyamTimeFor` in Task 5 only. `NotificationSlot.qiyam` and
`.budgetNudge` are appended in Tasks 5 and 8 respectively, in that order.
