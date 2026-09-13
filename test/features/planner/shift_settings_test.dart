import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/planner/shift.dart';
import 'package:nouri/features/planner/shift_settings.dart';

/// The shift hours as the user's, not the brief's constants.
///
///   «عايز اختار وقت الدوام بيبدأ امتا وينتهي امتا مثلا الصبح من 7 am الي
///    2 pm وتحط ساعتين مواصلات ساعة قبل الدوام وساعة بعد يعني من 6 الي 3»
void main() {
  group('ShiftPattern.custom', () {
    test('his example: 7 to 2, an hour each way, is 6 to 3', () {
      final p = ShiftPattern.custom(
        type: ShiftType.morning,
        workStart: const Clock(7, 0),
        workEnd: const Clock(14, 0),
      );
      expect(p.workStart, const Clock(7, 0));
      expect(p.workEnd, const Clock(14, 0));
      expect(p.leaveHome, const Clock(6, 0));
      expect(p.homeAgain, const Clock(15, 0));
      expect(p.wake, const Clock(5, 0), reason: 'an hour before leaving');
      expect(p.crossesMidnight, isFalse);
    });

    test('the defaults reproduce the brief\'s morning and evening', () {
      for (final type in [ShiftType.morning, ShiftType.evening]) {
        final (start, end) = ShiftPattern.defaultHours(type)!;
        final custom = ShiftPattern.custom(type: type, workStart: start, workEnd: end);
        final brief = ShiftPattern.forType(type);
        expect(custom.workStart, brief.workStart, reason: type.name);
        expect(custom.workEnd, brief.workEnd, reason: type.name);
        expect(custom.leaveHome, brief.leaveHome, reason: type.name);
        expect(custom.wake, brief.wake, reason: type.name);
      }
    });

    test('a commute of forty-five minutes moves the edges by forty-five', () {
      final p = ShiftPattern.custom(
        type: ShiftType.morning,
        workStart: const Clock(8, 30),
        workEnd: const Clock(17, 0),
        commuteBefore: const Duration(minutes: 45),
        commuteAfter: const Duration(minutes: 30),
      );
      expect(p.leaveHome, const Clock(7, 45));
      expect(p.homeAgain, const Clock(17, 30));
      expect(p.wake, const Clock(6, 45));
    });

    test('the night shift keeps its shape and crosses midnight', () {
      final p = ShiftPattern.custom(
        type: ShiftType.night,
        workStart: const Clock(22, 0),
        workEnd: const Clock(7, 0),
      );
      expect(p.type, ShiftType.night);
      expect(p.crossesMidnight, isTrue);
      expect(p.homeAgain, const Clock(8, 0));
      expect(p.wake, isNull, reason: 'sleep is sized from the next duty');
    });

    test('an end not after the start is a night, whatever it was called', () {
      final p = ShiftPattern.custom(
        type: ShiftType.evening,
        workStart: const Clock(20, 0),
        workEnd: const Clock(4, 0),
      );
      expect(p.crossesMidnight, isTrue);
      expect(p.type, ShiftType.night);
    });

    test('a day off ignores the hours', () {
      final p = ShiftPattern.custom(
        type: ShiftType.off,
        workStart: const Clock(7, 0),
        workEnd: const Clock(14, 0),
      );
      expect(p.workStart, isNull);
      expect(p.isWorking, isFalse);
    });

    test('a leave before midnight wraps rather than going negative', () {
      final p = ShiftPattern.custom(
        type: ShiftType.morning,
        workStart: const Clock(0, 30),
        workEnd: const Clock(6, 0),
      );
      expect(p.leaveHome, const Clock(23, 30));
    });
  });

  group('ShiftHours', () {
    test('decodes what is stored and falls back per type', () {
      final hours = ShiftHours.decode('{"morning":{"start":"08:00","end":"16:00"}}');
      expect(hours[ShiftType.morning]!.start, const Clock(8, 0));
      expect(hours[ShiftType.morning]!.end, const Clock(16, 0));
      expect(hours[ShiftType.evening]!.start, const Clock(14, 0),
          reason: 'absent: the brief\'s');
      expect(hours[ShiftType.night]!.end, const Clock(7, 0));
    });

    test('a corrupt value is the defaults, never a throw', () {
      final hours = ShiftHours.decode('{nope');
      expect(hours[ShiftType.morning]!.start, const Clock(7, 0));
      final bad = ShiftHours.decode('{"morning":{"start":"25:99","end":"x"}}');
      expect(bad[ShiftType.morning]!.start, const Clock(7, 0));
    });

    test('round-trips', () {
      final hours = ShiftHours.decode('{}')..[ShiftType.evening] = const ShiftHours(Clock(15, 0), Clock(23, 0));
      final back = ShiftHours.decode(ShiftHours.encode(hours));
      expect(back[ShiftType.evening]!.start, const Clock(15, 0));
      expect(back[ShiftType.morning]!.start, const Clock(7, 0));
    });
  });

  group('from the settings row', () {
    late NouriDatabase db;
    setUp(() {
      db = NouriDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
    });

    test('a fresh row is the brief\'s morning', () async {
      final p = shiftPatternFromSettings(await db.settingsDao.get());
      expect(p.type, ShiftType.morning);
      expect(p.workStart, const Clock(7, 0));
      expect(p.leaveHome, const Clock(6, 0));
      expect(p.homeAgain, const Clock(15, 0));
    });

    test('the user\'s hours and commute win', () async {
      await db.settingsDao.update(const SettingsRowsCompanion(
        shiftType: Value('evening'),
        shiftHoursJson: Value('{"evening":{"start":"15:00","end":"23:00"}}'),
        commuteBeforeMinutes: Value(30),
        commuteAfterMinutes: Value(90),
      ));
      final p = shiftPatternFromSettings(await db.settingsDao.get());
      expect(p.type, ShiftType.evening);
      expect(p.workStart, const Clock(15, 0));
      expect(p.leaveHome, const Clock(14, 30));
      expect(p.homeAgain, const Clock(0, 30));
    });
  });
}
