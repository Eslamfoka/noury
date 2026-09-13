import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'nag_plan.dart';

/// The two files behind «فكّرني تاني»: what the day holds, and what is done.
///
/// Files rather than the database, for the reason `snooze_store.dart` gives:
/// the tick runs in a background isolate with nothing of the app alive, and
/// this project does not open a second connection to the SQLite file from a
/// second isolate. Both files are small — a day is a dozen tasks — written
/// whole and read whole, and neither is ever the thing that matters most:
/// losing `nag_plan.json` costs the nags until the next launch, losing
/// `nag_done.json` costs one extra question. The alarms themselves are
/// untouched by either.
class NagStore {
  NagStore({required this.planFile, required this.doneFile});

  final File planFile;
  final File doneFile;

  /// Days older than this fall out of the done file on the next write. The
  /// plan covers three days; keeping yesterday lets a tick just after
  /// midnight on a night shift still see the evening's completions.
  static const _keepDays = 2;

  Future<void> writePlan(NagPlan plan) async {
    try {
      await planFile.writeAsString(jsonEncode(plan.toJson()), flush: true);
    } catch (_) {
      // The nags go quiet until the next re-arm. The alarms do not.
    }
  }

  /// Null when there is no plan, or none that can be read.
  Future<NagPlan?> readPlan() async {
    try {
      if (!planFile.existsSync()) return null;
      return NagPlan.fromJson(jsonDecode(await planFile.readAsString()));
    } catch (_) {
      return null;
    }
  }

  /// The task ids done on [day].
  Future<Set<String>> readDone(DateTime day) async {
    final all = await _readAllDone();
    return all[NagPlan.dateKey(day)] ?? const {};
  }

  /// Adds [ids] to [day]'s done set. Merges — a write site knows only the
  /// task it just logged, not the whole day.
  Future<void> markDone(DateTime day, Iterable<String> ids) async {
    final all = await _readAllDone();
    final key = NagPlan.dateKey(day);
    all[key] = {...?all[key], ...ids};
    await _writeAllDone(all, keepFrom: day);
  }

  /// Replaces [day]'s done set outright — the re-arm's view, derived from
  /// the logs, which is the truth the merges above approximate between
  /// launches. This is also how a cleared completion (the wird toggled back
  /// off) stops being "done" here: the next re-arm rewrites the set.
  Future<void> replaceDone(DateTime day, Set<String> ids) async {
    final all = await _readAllDone();
    all[NagPlan.dateKey(day)] = ids;
    await _writeAllDone(all, keepFrom: day);
  }

  Future<Map<String, Set<String>>> _readAllDone() async {
    try {
      if (!doneFile.existsSync()) return {};
      final raw = jsonDecode(await doneFile.readAsString());
      if (raw is! Map) return {};
      return {
        for (final e in raw.entries)
          if (e.value is List)
            '${e.key}': {for (final id in e.value as List) '$id'},
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeAllDone(
    Map<String, Set<String>> all, {
    required DateTime keepFrom,
  }) async {
    // Prune by key, which sorts as a date. Constructed rather than offset,
    // as every day arithmetic in this project is.
    final floor = NagPlan.dateKey(
      DateTime(keepFrom.year, keepFrom.month, keepFrom.day - _keepDays),
    );
    final kept = {
      for (final e in all.entries)
        if (e.key.compareTo(floor) >= 0) e.key: e.value.toList()..sort(),
    };
    try {
      await doneFile.writeAsString(jsonEncode(kept), flush: true);
    } catch (_) {
      // One extra question, at most.
    }
  }
}

Future<NagStore> openNagStore() async {
  final dir = await getApplicationSupportDirectory();
  return NagStore(
    planFile: File('${dir.path}/nag_plan.json'),
    doneFile: File('${dir.path}/nag_done.json'),
  );
}

/// What the window hands the nag on every re-arm.
///
/// An interface so the scheduler's pure tests pass nothing; the real one,
/// [FileNagPlanSink] in `nag_tick.dart`, writes the files and starts or stops
/// the chain of ticks.
abstract interface class NagPlanSink {
  Future<void> publish(
    NagPlan plan, {
    required DateTime today,
    required Set<String> doneToday,
  });
}
