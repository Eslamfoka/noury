import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/tasks/snooze_store.dart';

/// The record of «فكّرني بعد ٥ دقايق», so المهام can show where a task went.
///
/// Written by the background isolate, read by the app. Losing it costs a
/// label, never an alarm — the notification is still the thing that fires —
/// so every path here fails soft.
void main() {
  late Directory dir;
  late SnoozeStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nouri_snooze');
    store = SnoozeStore(File('${dir.path}/snoozes.json'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a fresh install reads as empty, not as an error', () async {
    expect(await store.read(), isEmpty);
  });

  test('a snooze round-trips', () async {
    final until = DateTime(2026, 9, 8, 13, 5);
    await store.record('walk', until);
    expect(await store.read(now: until), {'walk': until});
  });

  test('snoozing again replaces rather than stacking', () async {
    await store.record('walk', DateTime(2026, 9, 8, 13, 5));
    await store.record('walk', DateTime(2026, 9, 8, 13, 10));

    final read = await store.read(now: DateTime(2026, 9, 8, 13, 6));
    expect(read, {'walk': DateTime(2026, 9, 8, 13, 10)});
  });

  test('two tasks are kept apart', () async {
    await store.record('walk', DateTime(2026, 9, 8, 13, 5));
    await store.record('first-meal', DateTime(2026, 9, 8, 14, 0));

    final read = await store.read(now: DateTime(2026, 9, 8, 13, 0));
    expect(read.keys, containsAll(['walk', 'first-meal']));
  });

  test('clearing forgets one and leaves the rest', () async {
    await store.record('walk', DateTime(2026, 9, 8, 13, 5));
    await store.record('first-meal', DateTime(2026, 9, 8, 14, 0));

    await store.clear('walk');

    final read = await store.read(now: DateTime(2026, 9, 8, 13, 0));
    expect(read.keys, ['first-meal']);
  });

  test('clearing something that was never snoozed is harmless', () async {
    await store.clear('walk');
    expect(await store.read(), isEmpty);
  });

  test("yesterday's snooze is dropped, not shown against today", () async {
    // A stale «مأجّلة» beside a task whose time has come round again would be
    // Nouri reporting something that is no longer true.
    await store.record('walk', DateTime(2026, 9, 7, 13, 5));

    final read = await store.read(now: DateTime(2026, 9, 8, 13, 0));
    expect(read, isEmpty);
  });

  test('hiding a stale entry does not delete it out from under a later write',
      () async {
    // The bug of 9 September 2026, stated directly rather than as the symptom
    // that exposed it. `record` and `clear` used to merge into whatever
    // `read()` returned, so anything the 20-hour display filter was hiding at
    // that instant was silently dropped from the file. The visible cost was
    // that snoozing a second task erased the first — but only when the clock
    // happened to make the first one stale, which is why it survived a suite
    // that otherwise passed.
    //
    // The property that must hold: a write touches the key it was given and
    // nothing else, whatever the clock says about the rest.
    await store.record('walk', DateTime(2026, 9, 7, 13, 5)); // long stale
    await store.record('first-meal', DateTime(2026, 9, 8, 14, 0));

    // Hidden from a reader standing well after it...
    expect(await store.read(now: DateTime(2026, 9, 8, 13, 0)),
        {'first-meal': DateTime(2026, 9, 8, 14, 0)});

    // ...but never removed from the file by the write that followed it.
    expect(await store.read(now: DateTime(2026, 9, 7, 13, 6)),
        containsPair('walk', DateTime(2026, 9, 7, 13, 5)));
  });

  test('a corrupt file reads as empty rather than throwing', () async {
    // A half-written file after the process was killed. This is read inside a
    // background isolate, which is the worst place to raise an exception.
    await File('${dir.path}/snoozes.json').writeAsString('{not json at all');
    expect(await store.read(), isEmpty);
  });

  test('a file holding the wrong shape reads as empty', () async {
    await File('${dir.path}/snoozes.json').writeAsString('["walk"]');
    expect(await store.read(), isEmpty);
  });

  test('an unparseable date is skipped, and its neighbours survive', () async {
    await File('${dir.path}/snoozes.json')
        .writeAsString('{"walk":"not-a-date","first-meal":"2026-09-08T14:00:00"}');

    final read = await store.read(now: DateTime(2026, 9, 8, 13, 0));
    expect(read.keys, ['first-meal']);
  });

  test('writing creates the directory if it is not there yet', () async {
    final nested = SnoozeStore(File('${dir.path}/a/b/snoozes.json'));
    await nested.record('walk', DateTime(2026, 9, 8, 13, 5));
    expect(await nested.read(now: DateTime(2026, 9, 8, 13, 0)),
        {'walk': DateTime(2026, 9, 8, 13, 5)});
  });
}
