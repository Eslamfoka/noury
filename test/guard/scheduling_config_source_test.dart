import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/scheduling_config_from_db.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/planner/shift.dart';

/// One place builds the alarm window's config. Only one.
///
/// **This guard exists because of a bug that shipped past every unit test.**
///
/// `main.dart` armed the window on every launch and `SettingsController` armed
/// it on every settings change, and each assembled its own `SchedulingConfig`
/// from the same settings rows. قيام الليل and the budget note were added to
/// the settings one and not to the launch one — so opening the app rebuilt the
/// window *without* them, overwriting whatever the settings path had just
/// armed. Turning قيام on and reopening Nouri left no قيام alarm at all.
///
/// Both call sites were individually correct about the fields they knew about,
/// so nothing failed. It was found by counting pending alarms on the emulator:
/// the count did not move when it should have risen by fourteen.
///
/// The fix was to have one builder. This guard keeps it that way.
void main() {
  /// Matches a *construction* of SchedulingConfig.
  ///
  /// The declaration opens `SchedulingConfig({` — a named-parameter list — so
  /// the negative lookahead on `{` tells the two apart without needing to know
  /// which file it is in.
  final construction = RegExp(r'SchedulingConfig\((?!\{)');

  test('the regex it guards with matches a call and not the declaration', () {
    // Both directions. A guard whose pattern matched nothing would pass
    // forever while guarding nothing; one that matched the declaration would
    // fail forever and get deleted.
    expect(construction.hasMatch('await s.rearm(SchedulingConfig('), isTrue);
    expect(construction.hasMatch('  return SchedulingConfig(geo: g,'), isTrue);
    expect(construction.hasMatch('  const SchedulingConfig({'), isFalse,
        reason: 'the declaration is not a call site');
  });

  test('only the shared builder constructs a SchedulingConfig', () {
    final offenders = <String>[];

    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final normalised = file.path.replaceAll(r'\', '/');

      // The class's own file declares it and returns one from copyWith; the
      // shared builder is the one legitimate construction site.
      if (normalised.endsWith('rolling_window_scheduler.dart')) continue;
      if (normalised.endsWith('scheduling_config_from_db.dart')) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (construction.hasMatch(lines[i])) {
          offenders.add('$normalised:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'a second place building the alarm config is how قيام الليل and '
          'the budget note were silently dropped on every launch. Use '
          'schedulingConfigFromDb instead.\n${offenders.join('\n')}',
    );
  });

  group('the builder carries every setting the window needs', () {
    late NouriDatabase db;

    setUp(() => db = NouriDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() async => db.close());

    test('قيام reaches the config when it is switched on', () async {
      // The exact field that was being dropped.
      await db.settingsDao
          .update(const SettingsRowsCompanion(notifyQiyam: Value(true)));

      final cfg = await schedulingConfigFromDb(db, now: DateTime(2026, 9, 8));

      expect(cfg.notifyQiyam, isTrue);
    });

    test('the shift reaches it too, since قيام depends on it', () async {
      await db.settingsDao
          .update(const SettingsRowsCompanion(shiftType: Value('night')));

      final cfg = await schedulingConfigFromDb(db, now: DateTime(2026, 9, 8));

      expect(cfg.shift, ShiftType.night);
    });

    test('an unknown shift name falls back rather than throwing', () async {
      await db.settingsDao
          .update(const SettingsRowsCompanion(shiftType: Value('nonsense')));

      final cfg = await schedulingConfigFromDb(db, now: DateTime(2026, 9, 8));

      expect(cfg.shift, ShiftType.morning);
    });

    test('every notification toggle reaches it', () async {
      await db.settingsDao.update(const SettingsRowsCompanion(
        notifyAdhan: Value(false),
        notifyIqama: Value(false),
        notifyAthkar: Value(false),
        notifyWird: Value(false),
        notifyFasting: Value(false),
        notifyWater: Value(false),
        notifyQiyam: Value(true),
      ));

      final cfg = await schedulingConfigFromDb(db, now: DateTime(2026, 9, 8));

      expect(cfg.notifyAdhan, isFalse);
      expect(cfg.notifyIqama, isFalse);
      expect(cfg.notifyAthkar, isFalse);
      expect(cfg.notifyWird, isFalse);
      expect(cfg.notifyFasting, isFalse);
      expect(cfg.notifyWater, isFalse);
      expect(cfg.notifyQiyam, isTrue);
    });

    test('the iqama offsets and the Hijri nudge reach it', () async {
      await db.settingsDao.update(const SettingsRowsCompanion(
        iqamaOffsetsJson: Value(
            '{"fajr":25,"dhuhr":15,"asr":15,"maghrib":10,"isha":15}'),
        hijriOffsetDays: Value(1),
      ));

      final cfg = await schedulingConfigFromDb(db, now: DateTime(2026, 9, 8));

      expect(cfg.iqamaOffsets['fajr'], 25);
      expect(cfg.hijriOffsetDays, 1);
    });

    test('a day marked as a fast reaches it', () async {
      await db.waterDao.setFasting(DateTime(2026, 9, 10), true);

      final cfg = await schedulingConfigFromDb(db, now: DateTime(2026, 9, 8));

      expect(cfg.fastingDays, contains(DateTime(2026, 9, 10)));
    });

    test('nothing budgeted means no budget note', () async {
      final cfg = await schedulingConfigFromDb(db, now: DateTime(2026, 9, 8));
      expect(cfg.budgetNote, isNull);
    });

    test('a category well ahead of pace produces one', () async {
      final month = DateTime(2026, 8, 25);
      await db.financeDao
          .setBudget(monthStart: month, category: 'food', limitFils: 100000);
      await db.financeDao.addExpense(
        date: DateTime(2026, 8, 26),
        category: 'food',
        amountFils: 80000,
      );

      final cfg = await schedulingConfigFromDb(db, now: DateTime(2026, 8, 28));

      expect(cfg.budgetNote, isNotNull);
    });
  });
}
