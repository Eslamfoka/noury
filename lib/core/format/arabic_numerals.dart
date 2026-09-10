const _arabicZero = 0x0660;
const _westernZero = 0x30;

/// Rewrites western digits as Arabic-Indic, leaving everything else alone.
///
/// Every user-facing number in the Arabic locale goes through here — Nouri
/// never renders a raw `toString()` into the UI.
String toArabicDigits(String input) => input.replaceAllMapped(
      RegExp(r'[0-9]'),
      (m) => String.fromCharCode(
        m.group(0)!.codeUnitAt(0) - _westernZero + _arabicZero,
      ),
    );

/// `h:mm:ss`, clamped at zero — a passed prayer shows ٠:٠٠:٠٠, never a minus.
String formatCountdown(Duration d) {
  final safe = d.isNegative ? Duration.zero : d;
  final h = safe.inHours;
  final m = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return toArabicDigits('$h:$m:$s');
}

/// 12-hour clock without the am/pm marker — the surrounding UI carries it.
String formatClock(DateTime t, {bool arabic = true}) {
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final raw = '$hour12:${t.minute.toString().padLeft(2, '0')}';
  return arabic ? toArabicDigits(raw) : raw;
}
