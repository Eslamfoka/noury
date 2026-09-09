import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where «فكّرني بعد ٥ دقايق» is written down, so المهام can show the new time.
///
/// **A file rather than the database, deliberately.** A snooze is recorded by
/// the background isolate — the one Android spins up when the button is
/// pressed with the app closed — and that isolate has none of the app alive:
/// no providers, no open database, nothing. Opening a second Drift connection
/// to the same SQLite file from a second isolate invites exactly the locking
/// this project has already seen warned about in tests, and a snooze is not
/// worth that risk.
///
/// So: one small JSON object, `{taskId: iso8601}`, written whole and read
/// whole. It is keyed by task id, so it can never hold more entries than there
/// are kinds of task — a couple of dozen — which is why nothing here ever
/// needs to collect garbage to keep the file small.
///
/// The notification is still the thing that fires. This is only so the screen
/// can *say* where the task went — losing this file costs a label, never an
/// alarm.
class SnoozeStore {
  SnoozeStore(this.file);

  final File file;

  /// Entries older than this are hidden by [read].
  ///
  /// A snooze is a thing about today. Showing yesterday's would put a stale
  /// «مأجّلة» beside a task whose time has come round again.
  ///
  /// **This hides; it does not delete.** The distinction is the whole of the
  /// bug fixed on 9 September 2026: [record] and [clear] used to build their
  /// next file out of `read()`'s *filtered* view, so writing one key silently
  /// destroyed every other key the filter happened to be hiding at that
  /// moment. Snoozing a second task dropped the first. A display rule had been
  /// wired into the persistence path, where it decided what survived.
  static const _keepFor = Duration(hours: 20);

  /// What is currently snoozed, and until when — the view المهام draws.
  ///
  /// Never throws. A missing file is the ordinary case on a fresh install, and
  /// a corrupt one — a half-written file after a kill — is worth exactly as
  /// much as an empty one.
  Future<Map<String, DateTime>> read({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final all = await _readAll();
    return {
      for (final e in all.entries)
        if (at.difference(e.value) <= _keepFor) e.key: e.value,
    };
  }

  /// Every entry in the file, with no regard for the clock.
  ///
  /// The merge base for a write. Writers must never start from [read]: what a
  /// reader is not currently *shown* is not the same as what may be thrown
  /// away, and conflating the two is what lost a snooze.
  Future<Map<String, DateTime>> _readAll() async {
    try {
      if (!file.existsSync()) return const {};
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return const {};

      final out = <String, DateTime>{};
      for (final entry in raw.entries) {
        final when = DateTime.tryParse('${entry.value}');
        if (when == null) continue;
        out['${entry.key}'] = when;
      }
      return out;
    } catch (_) {
      // Unreadable is the same as empty. A snooze label is not worth a crash,
      // least of all one raised inside a background isolate.
      return const {};
    }
  }

  /// Records that [taskId] has been put off until [until].
  ///
  /// One entry per task: pressing snooze again replaces it, which is what
  /// "put it off another five minutes" means. Every other task is left exactly
  /// as it was — this takes no view about the time, because a writer that
  /// prunes on the ambient clock deletes things its caller never named.
  Future<void> record(String taskId, DateTime until) async {
    try {
      final current = Map<String, DateTime>.from(await _readAll());
      current[taskId] = until;
      await _write(current);
    } catch (_) {
      // Best-effort, like everything else on this path.
    }
  }

  /// Forgets a snooze — used when the task is done, so a stale «مأجّلة» does
  /// not sit beside something already finished.
  Future<void> clear(String taskId) async {
    try {
      final current = Map<String, DateTime>.from(await _readAll());
      if (current.remove(taskId) == null) return;
      await _write(current);
    } catch (_) {
      // As above.
    }
  }

  Future<void> _write(Map<String, DateTime> entries) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      for (final e in entries.entries) e.key: e.value.toIso8601String(),
    }));
  }
}


/// The store, at its real location on the device.
///
/// Resolved through `path_provider`, which is a plugin — so in the background
/// isolate the caller must have run `DartPluginRegistrant.ensureInitialized()`
/// first, or this throws and the snooze goes unrecorded. The alarm still
/// fires either way; only the label is lost.
Future<SnoozeStore> openSnoozeStore() async {
  final dir = await getApplicationSupportDirectory();
  return SnoozeStore(File('${dir.path}/snoozes.json'));
}
