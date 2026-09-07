import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import 'calendar_month.dart';
import 'reminder.dart';
import 'reminder_editor_sheet.dart';
import 'reminder_providers.dart';

/// The calendar: pick a day, see what is on it, write what you want reminding
/// of.
///
/// A full screen rather than a tab. The shell already carries six destinations,
/// one past Material's recommendation, and the tab structure is an open
/// question for Slice 2 — so this opens from the Home header instead, which
/// costs nothing and keeps every answer to that question available.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.initialDay});

  /// Where to open. Used when a tapped reminder notification brings the user
  /// straight here.
  final DateTime? initialDay;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _selected;
  late MonthGrid _grid;

  @override
  void initState() {
    super.initState();
    final start = widget.initialDay ?? DateTime.now();
    _selected = DateTime(start.year, start.month, start.day);
    _grid = MonthGrid.of(start.year, start.month);
  }

  void _page(MonthGrid to) => setState(() => _grid = to);

  void _select(DateTime day) => setState(() => _selected = day);

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allRemindersProvider);
    final onDay = ref.watch(remindersOnDayProvider(_selected));

    return Scaffold(
      backgroundColor: NouriColors.background,
      appBar: AppBar(
        backgroundColor: NouriColors.background,
        elevation: 0,
        title: Text('التقويم', style: cairo(size: 16, weight: FontWeight.w700)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('add-reminder'),
        backgroundColor: NouriColors.gold,
        foregroundColor: NouriColors.background,
        onPressed: () => showReminderEditorSheet(context, ref, day: _selected),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MonthBar(
              grid: _grid,
              onPrevious: () => _page(_grid.previous),
              onNext: () => _page(_grid.next),
            ),
            const SizedBox(height: 8),
            _WeekdayHeadings(),
            _Grid(
              grid: _grid,
              selected: _selected,
              reminders: all.value ?? const [],
              onSelect: _select,
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: NouriColors.border),
            Expanded(
              child: onDay.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: NouriColors.gold),
                ),
                error: (_, _) => Center(
                  child: Text(
                    'مش قادر أفتح تذكيرات اليوم ده.',
                    style: cairo(size: 13, color: NouriColors.muted),
                  ),
                ),
                data: (rows) => _DayList(day: _selected, reminders: rows),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.grid,
    required this.onPrevious,
    required this.onNext,
  });

  final MonthGrid grid;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // In an RTL layout the leading arrow points right and moves back in
          // time, which is what an Arabic reader expects.
          IconButton(
            key: const ValueKey('month-previous'),
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_right, color: NouriColors.muted),
          ),
          Text(
            toArabicDigits(grid.label),
            style: cairo(size: 15, weight: FontWeight.w700),
          ),
          IconButton(
            key: const ValueKey('month-next'),
            onPressed: onNext,
            icon: const Icon(Icons.chevron_left, color: NouriColors.muted),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeadings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final h in arabicWeekdayHeadings)
            Expanded(
              child: Text(
                h,
                textAlign: TextAlign.center,
                style: cairo(size: 11, color: NouriColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({
    required this.grid,
    required this.selected,
    required this.reminders,
    required this.onSelect,
  });

  final MonthGrid grid;
  final DateTime selected;
  final List<Reminder> reminders;
  final ValueChanged<DateTime> onSelect;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  bool _hasReminder(DateTime day) => reminders.any((r) => occursOn(r, day));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        children: [
          for (var row = 0; row < MonthGrid.rows; row++)
            Row(
              children: [
                for (var col = 0; col < MonthGrid.columns; col++)
                  Expanded(
                    child: _Cell(
                      day: grid.cells[row * MonthGrid.columns + col],
                      isToday: grid.cells[row * MonthGrid.columns + col] ==
                          today,
                      isSelected: grid.cells[row * MonthGrid.columns + col] ==
                          selected,
                      hasReminder: () {
                        final d = grid.cells[row * MonthGrid.columns + col];
                        return d != null && _hasReminder(d);
                      }(),
                      onTap: onSelect,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasReminder,
    required this.onTap,
  });

  final DateTime? day;
  final bool isToday;
  final bool isSelected;
  final bool hasReminder;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final d = day;
    if (d == null) return const SizedBox(height: 44);

    return GestureDetector(
      onTap: () => onTap(d),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? NouriColors.gold : Colors.transparent,
                border: isToday && !isSelected
                    ? Border.all(color: NouriColors.gold, width: 1.2)
                    : null,
              ),
              child: Text(
                toArabicDigits('${d.day}'),
                style: cairo(
                  size: 12.5,
                  weight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: isSelected ? NouriColors.background : NouriColors.text,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 4,
              child: hasReminder
                  ? Container(
                      key: ValueKey('day-dot-${_Grid.dayKey(d)}'),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: NouriColors.gold,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DayList extends ConsumerWidget {
  const _DayList({required this.day, required this.reminders});

  final DateTime day;
  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reminders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'مفيش حاجة على اليوم ده.\nدوس ＋ لو عايز تفكّر نفسك بحاجة.',
            textAlign: TextAlign.center,
            style: cairo(size: 12.5, color: NouriColors.muted, height: 1.8),
          ),
        ),
      );
    }

    final controller = ref.read(reminderControllerProvider);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
      itemCount: reminders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = reminders[i];
        return Dismissible(
          key: ValueKey('reminder-${r.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: NouriColors.surfaceActive,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.delete_outline, color: NouriColors.muted),
          ),
          onDismissed: (_) => controller.delete(r.id),
          child: _ReminderTile(reminder: r),
        );
      },
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder});

  final Reminder reminder;

  static const _repeatLabels = {
    ReminderRepeat.once: 'مرة واحدة',
    ReminderRepeat.daily: 'كل يوم',
    ReminderRepeat.weekly: 'كل أسبوع',
    ReminderRepeat.monthly: 'كل شهر',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reminder;
    final done = r.done;

    return Material(
      color: NouriColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showReminderEditorSheet(
          context,
          ref,
          day: r.onDate,
          existing: r,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              // A done reminder goes muted, never struck through and never
              // red. Nothing in Nouri is marked as a failure.
              IconButton(
                key: ValueKey('reminder-done-${r.id}'),
                onPressed: () =>
                    ref.read(reminderControllerProvider).setDone(r.id, !done),
                icon: Icon(
                  done ? Icons.check_circle : Icons.circle_outlined,
                  color: done ? NouriColors.success : NouriColors.muted,
                  size: 22,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      r.title,
                      style: cairo(
                        size: 14,
                        weight: FontWeight.w600,
                        color: done ? NouriColors.muted : NouriColors.text,
                      ),
                    ),
                    if (r.note != null && r.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        r.note!,
                        style: cairo(size: 11.5, color: NouriColors.muted),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${formatClock(reminderFireTime(r))} · '
                      '${_repeatLabels[r.repeat]}',
                      style: cairo(size: 11, color: NouriColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
