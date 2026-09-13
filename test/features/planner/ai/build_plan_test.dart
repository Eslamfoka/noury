import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/task_alert.dart';
import 'package:nouri/core/time/prayer_times_service.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/ai/ai_client.dart';
import 'package:nouri/features/ai/ai_provider.dart';
import 'package:nouri/features/planner/ai/build_plan.dart';
import 'package:nouri/features/planner/ai/plan_request.dart';

/// «ابني خطتي», from press to outcome, with a service that answers what it
/// is told to. The wire is tested in `ai_http_client_test`; this is the
/// join: what is sent, what comes back, and that no failure throws.
void main() {
  late NouriDatabase db;
  late _FakeAiClient client;
  const prayerTimes = PrayerTimesService();
  final now = DateTime(2026, 9, 13, 10, 0);

  const connection = AiConnection(
    provider: AiProvider.anthropic,
    apiKey: 'sk-test',
  );

  setUp(() {
    db = NouriDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    client = _FakeAiClient();
  });

  Future<BuildPlanOutcome> press({AiConnection? conn = connection}) =>
      buildPlan(
        db: db,
        prayerTimes: prayerTimes,
        client: client,
        connection: conn,
        now: now,
      );

  group('the request', () {
    test('covers three days starting today, with every prayer time', () async {
      final request = await assemblePlanRequest(
        db: db,
        prayerTimes: prayerTimes,
        from: now,
      );

      expect(request.days, [
        DateTime(2026, 9, 13),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 15),
      ]);
      for (final day in request.days) {
        final times = request.prayerTimesByDay[day]!;
        expect(times.keys, ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']);
        expect(times['الفجر'], matches(RegExp(r'^\d\d:\d\d$')));
      }
    });

    test('carries the settings the planner is built around', () async {
      await db.settingsDao.update(const SettingsRowsCompanion(
        shiftType: Value('night'),
        eatingWindowStartHour: Value(14),
        waterTargetGlasses: Value(10),
      ));
      final request = await assemblePlanRequest(
        db: db,
        prayerTimes: prayerTimes,
        from: now,
      );
      expect(request.shiftType, 'night');
      expect(request.eatingWindowStartHour, 14);
      expect(request.eatingWindowHours, 8, reason: '16/8 is the base system');
      expect(request.waterTargetGlasses, 10);
      expect(request.targetSleepHours, 7);
    });

    test('is sent with Nouri\'s system prompt and every alarmable id', () async {
      client.reply = '{"days":[]}';
      await press();

      expect(client.system, PlanRequest.systemPrompt);
      for (final id in alarmableTaskIds) {
        expect(client.user, contains(id), reason: id);
      }
      expect(client.connection, same(connection));
    });
  });

  group('the outcome', () {
    test('no connection is said before anything is sent', () async {
      final outcome = await press(conn: null);
      expect(outcome.needsConnection, isTrue);
      expect(outcome.ok, isFalse);
      expect(client.user, isNull, reason: 'nothing left the phone');
    });

    test('a plan comes back with titles المهام would use', () async {
      client.reply = '''
```json
{"days":[{"date":"2026-09-13","tasks":[
  {"id":"walk","at":"16:30","minutes":30},
  {"id":"quran-wird","at":"20:00","minutes":15},
  {"id":"invented-task","at":"21:00","minutes":5}
]}],
 "books":[{"title":"كتاب","why":"عشان"}],
 "note":"يوم هادي."}
```''';

      final outcome = await press();

      expect(outcome.ok, isTrue, reason: outcome.failure);
      expect(outcome.document!.days.single.tasks.map((t) => t.id),
          ['walk', 'quran-wird'],
          reason: 'the invented id is dropped, never invented into a row');
      expect(outcome.droppedTaskIds, ['invented-task']);
      expect(outcome.titleOf('walk'), isNot('walk'),
          reason: 'the sheet reads «مشي», not the id');
      expect(outcome.titleOf('quran-wird'), contains('ورد'));
      expect(outcome.document!.books.single.title, 'كتاب');
      expect(outcome.document!.note, 'يوم هادي.');
      expect(outcome.model, 'claude-haiku-4-5');
    });

    test('a service failure is a sentence, with the service\'s words', () async {
      client.failure = const AiFailure(AiFailureKind.rateLimited, detail: 'quota');
      final outcome = await press();
      expect(outcome.ok, isFalse);
      expect(outcome.needsConnection, isFalse);
      expect(outcome.failure, contains('جرّب بعد شوية'));
      expect(outcome.failure, contains('quota'));
    });

    test('a reply that is not a plan is a sentence too', () async {
      client.reply = 'أهلاً! أنا نوري وده مش JSON';
      final outcome = await press();
      expect(outcome.ok, isFalse);
      expect(outcome.failure, isNotEmpty);
    });
  });
}

class _FakeAiClient implements AiClient {
  String reply = '{"days":[]}';
  AiFailure? failure;
  String? system;
  String? user;
  AiConnection? connection;

  @override
  Future<AiResult<List<AiModel>>> listModels(AiConnection connection) async =>
      const AiResult.ok([]);

  @override
  Future<AiResult<String>> complete(
    AiConnection connection, {
    required String system,
    required String user,
    int maxTokens = 4096,
  }) async {
    this.connection = connection;
    this.system = system;
    this.user = user;
    if (failure != null) return AiResult.failed(failure!);
    return AiResult.ok(reply);
  }
}
