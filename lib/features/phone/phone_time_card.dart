import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import 'phone_budget.dart';

final todayPhoneProvider = FutureProvider<List<PhoneSession>>(
  (ref) => ref
      .watch(databaseProvider)
      .phoneDao
      .forDate(ref.watch(currentDayProvider)),
);

/// وقت الموبايل — the slot §5.5 asks Nouri to reserve, and the cap on it.
///
/// **The time is reported, not measured.** Reading real device usage needs
/// PACKAGE_USAGE_STATS, a special-access permission granted through a system
/// settings page, and it would make Nouri infer where every other pillar asks:
/// a fasting day is the user's word, a prayer is logged rather than detected.
/// So this card takes what the user says, the way the knowledge card does.
///
/// Sittings rather than a running timer, for now. It is the same shape as وقت
/// المعرفة, which keeps the two cards legible together, and a live session
/// wants the machinery the walk screen already needed. A timer would slot in
/// behind this same card without changing the table or the cap.
///
/// "Hard-ish cap" is honoured by *saying*, never by blocking. Nouri cannot
/// stop anyone using their phone and would not be right to pretend it can — so
/// passing the cap is a stated number, and nothing here is red.
class PhoneTimeCard extends ConsumerWidget {
  const PhoneTimeCard({super.key});

  static const _choices = [15, 30, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(todayPhoneProvider).value ?? const [];
    final minutes = logs.fold<int>(0, (a, r) => a + r.minutes);
    final cap = ref.watch(settingsProvider).value?.phoneCapMinutes ?? 60;

    final budget = PhoneBudget(cap: Duration(minutes: cap));
    final spent = Duration(minutes: minutes);
    final state = budget.stateFor(spent);

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
              const Icon(Icons.smartphone,
                  size: 18, color: NouriColors.gold),
              const SizedBox(width: 8),
              Text('وقت الموبايل',
                  style: cairo(size: 13.5, weight: FontWeight.w600)),
              const Spacer(),
              // Flexible, and a counter rather than a sentence: a sentence
              // here overflowed this row by 32px once the day passed 90
              // minutes, which draws the yellow-and-black stripe on a real
              // screen. The sentence lives on the line below.
              Flexible(
                child: Text(
                  minutes == 0 ? '—' : budget.counterFor(spent),
                  key: const ValueKey('phone-minutes'),
                  textAlign: TextAlign.end,
                  style: cairo(
                    size: 13,
                    // Gold when past the cap, not red. Nothing in Nouri is
                    // ever red, and an hour on the phone is not a failure.
                    color: state == PhoneBudgetState.within
                        ? NouriColors.success
                        : NouriColors.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: budget.fractionOf(spent),
              minHeight: 5,
              backgroundColor: NouriColors.surfaceActive,
              valueColor: const AlwaysStoppedAnimation(NouriColors.gold),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            budget.noteFor(spent),
            key: const ValueKey('phone-note'),
            style: cairo(size: 11.5, color: NouriColors.muted, height: 1.75),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _choices)
                GestureDetector(
                  key: ValueKey('phone-add-$m'),
                  onTap: () async {
                    final db = ref.read(databaseProvider);
                    await db.phoneDao.log(
                      date: ref.read(currentDayProvider),
                      minutes: m,
                    );
                    try {
                      ref.invalidate(todayPhoneProvider);
                    } catch (_) {
                      // Card gone; the row is already written.
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: NouriColors.surfaceActive,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: NouriColors.border),
                    ),
                    child: Text(toArabicDigits('$m د'),
                        style: cairo(size: 12)),
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
                      child: Text('قعدة',
                          style:
                              cairo(size: 11.5, color: NouriColors.muted)),
                    ),
                    Text(
                      toArabicDigits('${l.minutes} د'),
                      style: cairo(size: 11.5, color: NouriColors.muted),
                    ),
                    IconButton(
                      key: ValueKey('phone-delete-${l.id}'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final db = ref.read(databaseProvider);
                        await db.phoneDao.delete(l.id);
                        try {
                          ref.invalidate(todayPhoneProvider);
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
}
