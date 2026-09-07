import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import 'reminder_providers.dart';

/// Write what you want to be reminded of, on the day you picked.
///
/// The title is the only required field. A reminder nobody can be bothered to
/// fill in is a reminder that never gets written, and the whole feature is
/// worth less than the friction it costs.
Future<void> showReminderEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  required DateTime day,
  Reminder? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NouriColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _ReminderEditor(parentRef: ref, day: day, existing: existing),
    ),
  );
}

class _ReminderEditor extends StatefulWidget {
  const _ReminderEditor({
    required this.parentRef,
    required this.day,
    this.existing,
  });

  final WidgetRef parentRef;
  final DateTime day;
  final Reminder? existing;

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late int _minutes;
  late ReminderRepeat _repeat;

  static const _repeatLabels = {
    ReminderRepeat.once: 'مرة واحدة',
    ReminderRepeat.daily: 'كل يوم',
    ReminderRepeat.weekly: 'كل أسبوع',
    ReminderRepeat.monthly: 'كل شهر',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    // 09:00 is a defensible default: early enough to be useful, late enough
    // not to land in the middle of fajr.
    _minutes = e?.minutes ?? 9 * 60;
    _repeat = e?.repeat ?? ReminderRepeat.once;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: NouriColors.gold,
            surface: NouriColors.surface,
            onPrimary: NouriColors.background,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _minutes = picked.hour * 60 + picked.minute);
    }
  }

  /// Guards the save against running twice.
  ///
  /// `_save` awaits the database and only then pops the sheet, so a second tap
  /// on «احفظ» during that await would insert the same reminder again — and
  /// `add` is an insert, so there is no unique key to catch it. The widget
  /// test happens to pass without this, because an in-memory write completes
  /// inside the same batch as the taps; on a real device it does not.
  bool _saving = false;

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    if (_saving) return;
    _saving = true;

    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final controller = widget.parentRef.read(reminderControllerProvider);
    final e = widget.existing;

    if (e == null) {
      await controller.add(
        onDate: widget.day,
        minutes: _minutes,
        title: title,
        repeat: _repeat,
        note: note,
      );
    } else {
      await controller.edit(
        id: e.id,
        onDate: widget.day,
        minutes: _minutes,
        title: title,
        repeat: _repeat,
        note: note,
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
    } else {
      // The sheet went away under us; let a retry through rather than
      // leaving the editor permanently unable to save.
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = toArabicDigits(
      '${widget.day.day}/${widget.day.month}/${widget.day.year}',
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: NouriColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null ? 'تذكير جديد' : 'تعديل التذكير',
              style: cairo(size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(dayLabel, style: cairo(size: 11.5, color: NouriColors.muted)),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('reminder-title'),
              controller: _title,
              autofocus: widget.existing == null,
              style: cairo(size: 14),
              decoration: _fieldDecoration('تفكّرني بإيه؟'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('reminder-note'),
              controller: _note,
              style: cairo(size: 13),
              maxLines: 2,
              minLines: 1,
              decoration: _fieldDecoration('تفاصيل زيادة (اختياري)'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('الساعة',
                    style: cairo(size: 12.5, color: NouriColors.muted)),
                const SizedBox(width: 10),
                InkWell(
                  key: const ValueKey('reminder-time'),
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: NouriColors.surfaceActive,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NouriColors.border),
                    ),
                    child: Text(
                      toArabicDigits(
                        '${_minutes ~/ 60}:'
                        '${(_minutes % 60).toString().padLeft(2, '0')}',
                      ),
                      style: cairo(size: 13.5, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in ReminderRepeat.values)
                  GestureDetector(
                    key: ValueKey('repeat-${r.name}'),
                    onTap: () => setState(() => _repeat = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _repeat == r
                            ? NouriColors.gold
                            : NouriColors.surfaceActive,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NouriColors.border),
                      ),
                      child: Text(
                        _repeatLabels[r]!,
                        style: cairo(
                          size: 12,
                          weight: _repeat == r
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: _repeat == r
                              ? NouriColors.background
                              : NouriColors.text,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('reminder-save'),
              style: FilledButton.styleFrom(
                backgroundColor: NouriColors.gold,
                foregroundColor: NouriColors.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _save,
              child: Text(
                'احفظ',
                style: cairo(
                  size: 15,
                  weight: FontWeight.w700,
                  color: NouriColors.background,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: cairo(size: 13, color: NouriColors.muted),
        filled: true,
        fillColor: NouriColors.surfaceActive,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NouriColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NouriColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: NouriColors.gold),
        ),
      );
}
