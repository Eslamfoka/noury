import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import '../planner/daily_tasks.dart';
import '../planner/shift.dart';

/// The minimum the brief asks for: ten minutes a day.
const kKnowledgeMinimumMinutes = 10;

final todayKnowledgeProvider = FutureProvider<List<KnowledgeLog>>(
  (ref) => ref
      .watch(databaseProvider)
      .knowledgeDao
      .forDate(ref.watch(currentDayProvider)),
);

const kKnowledgeLabels = <KnowledgeKind, String>{
  KnowledgeKind.reading: 'قراءة',
  KnowledgeKind.skill: 'مهارة',
  KnowledgeKind.religiousContent: 'محتوى ديني',
};

/// وقت المعرفة — the self-development pillar.
///
/// One flexible block, not three daily items: the brief is explicit that
/// reading, skill learning and religious content rotate, and the planner
/// already picks which face today wears. This is where that time is recorded.
///
/// What Nouri does **not** do here is recommend. The brief wants it to suggest
/// books and propose a learning path, and that is AI work belonging with
/// Slice 5 — so the card asks what you did rather than telling you what to do,
/// and does not pretend to a library it has not got.
class KnowledgeCard extends ConsumerWidget {
  const KnowledgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(todayKnowledgeProvider).value ?? const [];
    final minutes = logs.fold<int>(0, (a, r) => a + r.minutes);
    final settings = ref.watch(settingsProvider).value;

    // What the planner put in today's knowledge block, so the card and the
    // plan cannot disagree about which face today wears.
    final suggested = knowledgeTaskFor(
      DateTime.now(),
      ShiftPattern.fromName(settings?.shiftType ?? 'morning'),
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_outlined,
                  size: 18, color: NouriColors.gold),
              const SizedBox(width: 8),
              Text('وقت المعرفة',
                  style: cairo(size: 13.5, weight: FontWeight.w600)),
              const Spacer(),
              Text(
                minutes == 0
                    ? '—'
                    : toArabicDigits('$minutes دقيقة'),
                key: const ValueKey('knowledge-minutes'),
                style: cairo(
                  size: 13,
                  color: minutes >= kKnowledgeMinimumMinutes
                      ? NouriColors.success
                      : NouriColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            minutes >= kKnowledgeMinimumMinutes
                ? 'كفاية النهاردة. زوّد لو ناوي.'
                : toArabicDigits(
                    'النهاردة: ${suggested.title}. '
                    'أقل حاجة $kKnowledgeMinimumMinutes دقايق.',
                  ),
            key: const ValueKey('knowledge-note'),
            style: cairo(size: 11.5, color: NouriColors.muted, height: 1.75),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in kKnowledgeLabels.entries)
                GestureDetector(
                  key: ValueKey('knowledge-log-${entry.key.name}'),
                  onTap: () => _log(context, ref, entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: NouriColors.surfaceActive,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NouriColors.border),
                    ),
                    child: Text(entry.value, style: cairo(size: 12)),
                  ),
                ),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 11),
            for (final l in logs)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.note?.trim().isNotEmpty ?? false
                            ? '${kKnowledgeLabels[l.kind]} — ${l.note}'
                            : kKnowledgeLabels[l.kind]!,
                        style: cairo(size: 11.5, color: NouriColors.muted),
                      ),
                    ),
                    Text(
                      toArabicDigits('${l.minutes} د'),
                      style: cairo(size: 11.5, color: NouriColors.muted),
                    ),
                    IconButton(
                      key: ValueKey('knowledge-delete-${l.id}'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        await db.knowledgeDao.delete(l.id);
                        try {
                          ref.invalidate(todayKnowledgeProvider);
                        } catch (_) {
                          // Card gone; the row is already deleted.
                        }
                      },
                      icon: const Icon(Icons.close,
                          size: 15, color: NouriColors.muted),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _log(
    BuildContext context,
    WidgetRef ref,
    KnowledgeKind kind,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: NouriColors.surface,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _LogKnowledge(parentRef: ref, kind: kind),
        ),
      );
}

class _LogKnowledge extends StatefulWidget {
  const _LogKnowledge({required this.parentRef, required this.kind});

  final WidgetRef parentRef;
  final KnowledgeKind kind;

  @override
  State<_LogKnowledge> createState() => _LogKnowledgeState();
}

class _LogKnowledgeState extends State<_LogKnowledge> {
  final _note = TextEditingController();
  int _minutes = 30;
  bool _saving = false;

  static const _choices = [10, 20, 30, 45, 60];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Guarded before the first await, like every other save in the app: a
    // second tap during the write would log the same session twice.
    if (_saving) return;
    _saving = true;

    final db = widget.parentRef.read(databaseProvider);
    await db.knowledgeDao.add(
      date: DateTime.now(),
      kind: widget.kind,
      minutes: _minutes,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    try {
      widget.parentRef.invalidate(todayKnowledgeProvider);
    } catch (_) {
      // The card behind the sheet went away. The session is recorded.
    }

    if (mounted) {
      Navigator.of(context).pop();
    } else {
      _saving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              kKnowledgeLabels[widget.kind]!,
              style: cairo(size: 16, weight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Text('قد إيه؟', style: cairo(size: 12, color: NouriColors.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _choices)
                  GestureDetector(
                    key: ValueKey('knowledge-minutes-$m'),
                    onTap: () => setState(() => _minutes = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: _minutes == m
                            ? NouriColors.gold
                            : NouriColors.surfaceActive,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NouriColors.border),
                      ),
                      child: Text(
                        toArabicDigits('$m'),
                        style: cairo(
                          size: 13,
                          weight: _minutes == m
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: _minutes == m
                              ? NouriColors.background
                              : NouriColors.text,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('knowledge-note-field'),
              controller: _note,
              style: cairo(size: 13),
              decoration: InputDecoration(
                hintText: 'قريت إيه؟ (اختياري)',
                hintStyle: cairo(size: 12.5, color: NouriColors.muted),
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
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('knowledge-save'),
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
                'سجّل',
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
}
