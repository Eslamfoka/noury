import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/core/notifications/notification_service.dart';
import 'package:nouri/core/notifications/task_alarm_ids.dart';
import 'package:nouri/features/tasks/task_done.dart';

/// Silencing a task's reminder once it has been done.
///
/// The contract that matters is not "it cancels" — that is one line — but the
/// three ways it must refuse to make things worse.
void main() {
  test('no service is a no-op, not a crash', () async {
    // Widget tests and any build without notifications have none. Nouri
    // degrades rather than refusing to record a walk.
    await expectLater(
      silenceTaskAlarms(null, const ['walk']),
      completes,
    );
  });

  test('a failing cancel never propagates', () async {
    // Best-effort by design. The row is already written; a failed cancel costs
    // one redundant question, and letting it throw would make «did my walk get
    // recorded» depend on «did the platform acknowledge the cancel».
    final service = _ThrowingService();
    await expectLater(
      silenceTaskAlarms(service, const ['walk']),
      completes,
    );
    expect(service.attempts, greaterThan(0),
        reason: 'it should have tried before swallowing');
  });

  test('it cancels both the alert and the question', () async {
    final service = _RecordingService();
    final on = DateTime(2026, 9, 8);

    await silenceTaskAlarms(service, const ['walk'], on: on);

    expect(service.cancelled, containsAll([
      taskAlarmId(on, 'walk'),
      taskAlarmId(on, 'walk', ask: true),
    ]));
  });

  test('an unknown task cancels nothing rather than guessing an id', () async {
    // An id from a future version of the app must not collide with something
    // real and silence it.
    final service = _RecordingService();
    await silenceTaskAlarms(service, const ['nonsense-from-2025']);
    expect(service.cancelled, isEmpty);
  });

  test('the three knowledge faces are silenced together', () async {
    // The planner rotates them and treats them as one block, so logging any
    // one answers all three.
    final service = _RecordingService();
    final on = DateTime(2026, 9, 8);

    await silenceTaskAlarms(service, knowledgeTaskIds, on: on);

    for (final id in knowledgeTaskIds) {
      expect(service.cancelled, contains(taskAlarmId(on, id)), reason: id);
    }
  });
}

class _RecordingService implements NotificationService {
  final cancelled = <int>[];

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ThrowingService implements NotificationService {
  int attempts = 0;

  @override
  Future<void> cancel(int id) async {
    attempts++;
    throw StateError('the platform channel went away');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
