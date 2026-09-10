import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import 'reminder.dart';
import 'reminder_scheduler.dart';

/// Anything that can arm reminder alarms.
///
/// An interface rather than the concrete [ReminderScheduler] for the same
/// reason [SchedulerPort] is one: widget tests have no platform channel, and a
/// screen that could only be built next to a live notification plugin could
/// not be tested at all.
abstract class ReminderSchedulerPort {
  Future<void> arm(List<Reminder> reminders);
  Future<void> cancelFor(int rowId);
}

class LiveReminderSchedulerPort implements ReminderSchedulerPort {
  LiveReminderSchedulerPort(this._scheduler);
  final ReminderScheduler _scheduler;

  @override
  Future<void> arm(List<Reminder> reminders) => _scheduler.arm(reminders);

  @override
  Future<void> cancelFor(int rowId) => _scheduler.cancelFor(rowId);
}

/// Waits for the real scheduler rather than dropping the work.
///
/// The notification plugin is warmed up off the startup path, so a reminder
/// added in the first seconds after launch would otherwise be saved and never
/// armed — the worst possible failure, because the row is visibly there.
class DeferredReminderSchedulerPort implements ReminderSchedulerPort {
  DeferredReminderSchedulerPort(this._ready);
  final Future<ReminderSchedulerPort?> _ready;

  @override
  Future<void> arm(List<Reminder> reminders) async =>
      (await _ready)?.arm(reminders);

  @override
  Future<void> cancelFor(int rowId) async => (await _ready)?.cancelFor(rowId);
}

/// Overridden in main() with the real scheduler; a no-op in tests.
final reminderSchedulerPortProvider =
    Provider<ReminderSchedulerPort>((ref) => _NoopReminderScheduler());

class _NoopReminderScheduler implements ReminderSchedulerPort {
  @override
  Future<void> arm(List<Reminder> reminders) async {}
  @override
  Future<void> cancelFor(int rowId) async {}
}

/// Every reminder whose own day falls in the given month.
///
/// Repeats are **not** expanded here. A weekly reminder created in March still
/// occurs in September, and the calendar decides that per cell with
/// [occursOn] — which is why this provider also hands back the repeats that
/// started earlier, via [allRemindersProvider].
final remindersForMonthProvider =
    FutureProvider.family<List<Reminder>, (int, int)>((ref, ym) async {
  final (year, month) = ym;
  return ref
      .watch(databaseProvider)
      .reminderDao
      .between(DateTime(year, month, 1), DateTime(year, month + 1, 0));
});

/// Everything, so a repeat that began months ago can still show a dot today.
final allRemindersProvider = FutureProvider<List<Reminder>>(
  (ref) => ref.watch(databaseProvider).reminderDao.all(),
);

/// The reminders that actually come round on [day], repeats included, in time
/// order.
final remindersOnDayProvider =
    FutureProvider.family<List<Reminder>, DateTime>((ref, day) async {
  final all = await ref.watch(allRemindersProvider.future);
  final on = all.where((r) => occursOn(r, day)).toList()
    ..sort((a, b) => a.minutes.compareTo(b.minutes));
  return on;
});

/// Writes reminders and keeps their alarms in step.
///
/// Every write re-arms from the full active set rather than arming the single
/// row that changed: arming is idempotent because the id is derived, and
/// re-arming everything means a reminder can never be left behind by a code
/// path that forgot it.
class ReminderController {
  ReminderController(this._ref);
  final Ref _ref;

  NouriDatabase get _db => _ref.read(databaseProvider);

  Future<void> add({
    required DateTime onDate,
    required int minutes,
    required String title,
    required ReminderRepeat repeat,
    String? note,
  }) async {
    await _db.reminderDao.add(
      onDate: onDate,
      minutes: minutes,
      title: title,
      repeat: repeat,
      note: note,
    );
    await _refresh();
  }

  Future<void> edit({
    required int id,
    required DateTime onDate,
    required int minutes,
    required String title,
    required ReminderRepeat repeat,
    String? note,
  }) async {
    await _db.reminderDao.edit(
      id: id,
      onDate: onDate,
      minutes: minutes,
      title: title,
      repeat: repeat,
      note: note,
    );
    await _refresh();
  }

  Future<void> setDone(int id, bool done) async {
    await _db.reminderDao.setDone(id, done);
    // A reminder marked done must stop asking, and the re-arm below only ever
    // adds -- it never cancels what is already pending. So cancel explicitly.
    if (done) await _ref.read(reminderSchedulerPortProvider).cancelFor(id);
    await _refresh();
  }

  Future<void> delete(int id) async {
    await _db.reminderDao.delete(id);
    await _ref.read(reminderSchedulerPortProvider).cancelFor(id);
    await _refresh();
  }

  Future<void> _refresh() async {
    _ref
      ..invalidate(allRemindersProvider)
      ..invalidate(remindersForMonthProvider)
      ..invalidate(remindersOnDayProvider);

    final active = await _db.reminderDao.allActive();
    await _ref.read(reminderSchedulerPortProvider).arm(active);
  }
}

final reminderControllerProvider =
    Provider<ReminderController>(ReminderController.new);
