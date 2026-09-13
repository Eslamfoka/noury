import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/nag_plan.dart';
import 'package:nouri/core/notifications/nag_store.dart';

/// The two files behind «فكّرني تاني». Written whole, read whole, and never
/// the thing that can fail the user: every failure is an empty answer.
void main() {
  late Directory dir;
  late NagStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nouri-nag-');
    addTearDown(() => dir.deleteSync(recursive: true));
    store = NagStore(
      planFile: File('${dir.path}/nag_plan.json'),
      doneFile: File('${dir.path}/nag_done.json'),
    );
  });

  final day = DateTime(2026, 9, 13);

  test('a plan written is the plan read', () async {
    final plan = NagPlan(
      intervalMinutes: 10,
      enabled: true,
      days: {
        '2026-09-13': NagDay(
          tasks: [
            NagTask(
              id: 'walk',
              title: 'مشي',
              start: DateTime(2026, 9, 13, 17),
              end: DateTime(2026, 9, 13, 17, 30),
              channelId: 'alert_walk_v3',
              payload: 'task:walk',
              question: 'مشيت؟',
            ),
          ],
        ),
      },
    );
    await store.writePlan(plan);
    final back = await store.readPlan();
    expect(back!.days['2026-09-13']!.tasks.single.title, 'مشي');
    expect(back.intervalMinutes, 10);
  });

  test('no plan file is null, not a throw', () async {
    expect(await store.readPlan(), isNull);
  });

  test('a corrupt plan file is null, not a throw', () async {
    await store.planFile.writeAsString('{not json');
    expect(await store.readPlan(), isNull);
  });

  test('marking done merges — a write site knows only its own task', () async {
    await store.markDone(day, ['walk']);
    await store.markDone(day, ['quran-wird']);
    expect(await store.readDone(day), {'walk', 'quran-wird'});
  });

  test('replacing done is the re-arm\'s truth, and can un-do', () async {
    // The wird toggled back off: the log no longer says done, the re-arm
    // rewrites the set from the log, and the nag can ask again.
    await store.markDone(day, ['walk', 'quran-wird']);
    await store.replaceDone(day, {'walk'});
    expect(await store.readDone(day), {'walk'});
  });

  test('yesterday is kept, the day before is dropped', () async {
    await store.markDone(DateTime(2026, 9, 10), ['old']);
    await store.markDone(DateTime(2026, 9, 12), ['yesterday']);
    await store.markDone(day, ['today']);

    expect(await store.readDone(DateTime(2026, 9, 12)), {'yesterday'});
    expect(await store.readDone(DateTime(2026, 9, 10)), isEmpty,
        reason: 'three days back is pruned on write');
  });

  test('a corrupt done file is empty, not a throw', () async {
    await store.doneFile.writeAsString('[1,2');
    expect(await store.readDone(day), isEmpty);
    await store.markDone(day, ['walk']);
    expect(await store.readDone(day), {'walk'}, reason: 'and it heals');
  });
}
