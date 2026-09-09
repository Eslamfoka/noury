import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/planner/ai/plan_request.dart';

import 'package:drift/native.dart';

/// What leaves the phone when the user presses «ابني خطتي».
///
/// The brief's rule is one sentence — *"Send aggregated summaries only, never
/// raw meals/expenses/personal detail"* — and it is the only rule in this
/// project that cannot be checked by looking at a screen. So it is checked
/// here, by writing a row into every logging table and then failing if any of
/// those values can be found in the payload.
///
/// This is deliberately a *negative* test over real data rather than a review
/// of the assembler's source. Someone adding a helpful line to `toPrompt` a
/// year from now will not re-read the brief; they will run the suite.
void main() {
  late NouriDatabase db;

  PlanRequest requestFrom(ProfileRow profile,
          {List<ProfileFieldRow> custom = const []}) =>
      PlanRequest(
        profile: profile,
        customFields: custom,
        days: [DateTime(2026, 9, 10), DateTime(2026, 9, 11)],
        shiftType: 'night',
        prayerTimesByDay: {
          DateTime(2026, 9, 10): {'الفجر': '04:12', 'الظهر': '11:47'},
          DateTime(2026, 9, 11): {'الفجر': '04:13', 'الظهر': '11:46'},
        },
        targetSleepHours: 7,
        eatingWindowStartHour: 12,
        eatingWindowHours: 8,
        waterTargetGlasses: 8,
      );

  setUp(() {
    db = NouriDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
  });

  group('nothing private leaves the device', () {
    test('no logged row appears in the payload, whatever the table', () async {
      // Every value below is deliberately a distinctive string or number, so a
      // match in the payload cannot be a coincidence.
      await db.bodyDao.addMeal(
        at: DateTime(2026, 9, 9, 13),
        description: 'كشري بالدقة الحارة',
        feeling: MealFeeling.pain,
      );
      await db.financeDao.addExpense(
        date: DateTime(2026, 9, 9),
        category: 'مواصلات',
        amountFils: 4317,
      );
      await db.prayerDao.upsertLog(
        date: DateTime(2026, 9, 9),
        prayer: 'fajr',
        scheduledTime: DateTime(2026, 9, 9, 4, 12),
        state: PrayerState.late_,
      );
      await db.bodyDao.addWeight(
        at: DateTime(2026, 9, 9),
        grams: 87450,
      );

      final profile = await db.profileDao.get();
      final payload = requestFrom(profile).toPrompt(allowedTaskIds: ['walk']);

      // The meal, its symptom, the amount, the weight, the prayer state.
      expect(payload, isNot(contains('كشري')));
      expect(payload, isNot(contains('4317')));
      expect(payload, isNot(contains('87450')));
      expect(payload, isNot(contains('87.4')));
      expect(payload.toLowerCase(), isNot(contains('pain')));
      expect(payload.toLowerCase(), isNot(contains('late')));
    });

    test('the profile itself does go — that is the whole feature', () async {
      await db.profileDao.update(const ProfileRowsCompanion(
        name: Value('إسلام'),
        occupation: Value('employee'),
        interests: Value('تاريخ وبرمجة'),
      ));
      await db.profileDao.addCustomField(
        label: 'النادي',
        value: 'الجمعة بعد العصر',
      );

      final payload = requestFrom(
        await db.profileDao.get(),
        custom: await db.profileDao.customFields(),
      ).toPrompt(allowedTaskIds: ['walk']);

      expect(payload, contains('إسلام'));
      expect(payload, contains('موظف'));
      expect(payload, contains('تاريخ وبرمجة'));
      expect(payload, contains('النادي'));
      expect(payload, contains('الجمعة بعد العصر'));
    });
  });

  group('the brief Claude actually receives', () {
    test('names only the task ids Nouri can actually ring', () async {
      // A plan containing a task with no alert is a task that never fires, and
      // a silent row in المهام looks like a promise Nouri did not keep.
      final payload = requestFrom(await db.profileDao.get())
          .toPrompt(allowedTaskIds: ['walk', 'first-meal', 'tasbeeh']);

      expect(payload, contains('walk, first-meal, tasbeeh'));
    });

    test('carries the days and their prayer anchors', () async {
      final payload = requestFrom(await db.profileDao.get())
          .toPrompt(allowedTaskIds: ['walk']);

      expect(payload, contains('2026-09-10'));
      expect(payload, contains('الفجر 04:12'));
      expect(payload, contains('2026-09-11'));
    });

    test('an empty profile reads as a short brief, not a list of gaps',
        () async {
      // «غير معروف» eleven times over would be Nouri telling the user, through
      // the model, everything he has not filled in. A missing field is simply
      // absent.
      final payload = requestFrom(await db.profileDao.get())
          .toPrompt(allowedTaskIds: ['walk']);

      expect(payload, isNot(contains('غير معروف')));
      expect(payload, isNot(contains('null')));
      expect(payload, contains('# الثوابت'),
          reason: 'the fixed anchors are known even when the profile is not');
    });

    test('the length of a shift is sent, not just its kind', () async {
      // Knowing someone works nights says when their duty falls; it says
      // nothing about whether that is eight hours or sixteen, and the plan
      // has to place everything in what is left.
      await db.profileDao
          .update(const ProfileRowsCompanion(dutyHours: Value(12)));

      final payload = requestFrom(await db.profileDao.get())
          .toPrompt(allowedTaskIds: ['walk']);

      expect(payload, contains('ساعات الوردية: 12 ساعة'));
    });

    test('an unanswered shift length is simply absent', () async {
      final payload = requestFrom(await db.profileDao.get())
          .toPrompt(allowedTaskIds: ['walk']);
      expect(payload, isNot(contains('ساعات الوردية')));
    });

    test('the shift is spelled out, not passed as a code word', () async {
      final payload = requestFrom(await db.profileDao.get())
          .toPrompt(allowedTaskIds: ['walk']);

      expect(payload, contains('ليلي'));
      expect(payload, isNot(contains('shiftType')));
    });
  });

  group("the voice Nouri asks for", () {
    test('the system prompt forbids blame and forbids inventing tasks', () {
      // §1.2 of the brief. A plan that came back scolding would be worse than
      // no plan, because he would stop opening the app.
      expect(PlanRequest.systemPrompt, contains('متلومش'));
      expect(PlanRequest.systemPrompt, contains('متخترعش'));
      expect(PlanRequest.systemPrompt, contains('النوم'));
    });

    test('it asks for JSON and nothing either side of it', () {
      expect(PlanRequest.systemPrompt, contains('JSON'));
      expect(PlanRequest.systemPrompt, contains('من غير أي كلام'));
    });
  });
}
