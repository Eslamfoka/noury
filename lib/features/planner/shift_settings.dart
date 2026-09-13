import 'dart:convert';

import '../../data/db/nouri_database.dart';
import 'shift.dart';

/// The user's shift hours, as stored, and the one way to turn a settings row
/// into a [ShiftPattern].
///
/// **One resolver, four callers.** Home's plan, the alarm window, the
/// knowledge card and «ابني خطتي» all used to call `ShiftPattern.fromName`
/// on the type alone, which was fine while the hours were constants. Now the
/// hours are the user's — «عايز اختار وقت الدوام بيبدأ امتا وينتهي امتا» —
/// and a caller that still read the constants would plan a day the user
/// does not have. `scheduling_config_source_test` already holds that the
/// alarm config is built in one place; this is the same rule for the shift.
///
/// Stored as JSON keyed by type, `{"morning":{"start":"07:00","end":"14:00"},
/// ...}`, so each type keeps its own hours and switching type does not lose
/// them. Absent or unreadable entries fall back to the brief's defaults —
/// never to an error, never to a day with no shape.
class ShiftHours {
  const ShiftHours(this.start, this.end);

  final Clock start;
  final Clock end;

  static ShiftHours? defaults(ShiftType type) {
    final d = ShiftPattern.defaultHours(type);
    return d == null ? null : ShiftHours(d.$1, d.$2);
  }

  /// `{"morning":{"start":"07:00","end":"14:00"}, ...}` → per type.
  static Map<ShiftType, ShiftHours> decode(String json) {
    Object? raw;
    try {
      raw = jsonDecode(json);
    } catch (_) {
      raw = null;
    }
    final out = <ShiftType, ShiftHours>{};
    for (final type in ShiftType.values) {
      if (type == ShiftType.off) continue;
      ShiftHours? parsed;
      if (raw is Map && raw[type.name] is Map) {
        final m = raw[type.name] as Map;
        final s = _clock('${m['start']}');
        final e = _clock('${m['end']}');
        if (s != null && e != null) parsed = ShiftHours(s, e);
      }
      out[type] = parsed ?? defaults(type)!;
    }
    return out;
  }

  static String encode(Map<ShiftType, ShiftHours> hours) => jsonEncode({
        for (final e in hours.entries)
          if (e.key != ShiftType.off)
            e.key.name: {'start': '${e.value.start}', 'end': '${e.value.end}'},
      });

  static Clock? _clock(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return Clock(h, m);
  }
}

/// The type the row names, parsed the same way everywhere.
ShiftType shiftTypeOf(String name) => switch (name) {
      'evening' => ShiftType.evening,
      'night' => ShiftType.night,
      'off' => ShiftType.off,
      _ => ShiftType.morning,
    };

/// The pattern the user's settings describe: the current type, with its
/// stored hours and the commute either side.
ShiftPattern shiftPatternFromSettings(SettingsRow s) =>
    shiftPatternFor(
      type: shiftTypeOf(s.shiftType),
      hoursJson: s.shiftHoursJson,
      commuteBeforeMinutes: s.commuteBeforeMinutes,
      commuteAfterMinutes: s.commuteAfterMinutes,
    );

/// The same, from the pieces — for callers that hold a config rather than
/// a row.
ShiftPattern shiftPatternFor({
  required ShiftType type,
  required String hoursJson,
  required int commuteBeforeMinutes,
  required int commuteAfterMinutes,
}) {
  if (type == ShiftType.off) return ShiftPattern.dayOff;
  final hours = ShiftHours.decode(hoursJson)[type]!;
  return ShiftPattern.custom(
    type: type,
    workStart: hours.start,
    workEnd: hours.end,
    commuteBefore: Duration(minutes: commuteBeforeMinutes),
    commuteAfter: Duration(minutes: commuteAfterMinutes),
  );
}
