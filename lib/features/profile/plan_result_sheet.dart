import 'package:flutter/material.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../core/time/date_formats.dart';
import '../planner/ai/build_plan.dart';
import '../shared/nouri_avatar.dart';

/// What came back from «ابني خطتي».
///
/// **Shown, not applied.** The days are listed as the model proposed them,
/// with the titles المهام uses; nothing is written into the plan, and the
/// sheet says so at the bottom. That is the reversible direction the
/// 9 September spec built toward, and the question — propose or overwrite —
/// is still the user's to answer. Until he does, this is a proposal he can
/// read and a day that stays as `planDay` built it.
///
/// A failure gets the same sheet with one sentence in it. Never a dialog
/// with a stack trace, never a snackbar that vanishes before it is read.
Future<void> showPlanResultSheet(BuildContext context, BuildPlanOutcome outcome) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NouriColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: outcome.ok ? _Built(outcome) : _Failed(outcome),
        ),
      ),
    ),
  );
}

class _Built extends StatelessWidget {
  const _Built(this.outcome);

  final BuildPlanOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final doc = outcome.document!;

    return Column(
      key: const ValueKey('plan-result-built'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const NouriAvatar(size: 30),
            const SizedBox(width: 10),
            Text('الخطة المقترحة',
                style: cairo(size: 15.5, weight: FontWeight.w700)),
          ],
        ),
        if (doc.note != null) ...[
          const SizedBox(height: 12),
          Text(
            doc.note!,
            key: const ValueKey('plan-result-note'),
            style: cairo(size: 13, height: 1.9),
          ),
        ],
        for (final day in doc.days) ...[
          const SizedBox(height: 16),
          Text(
            formatGregorianLong(day.date),
            style: cairo(size: 13, weight: FontWeight.w600, color: NouriColors.gold),
          ),
          const SizedBox(height: 6),
          for (final task in day.tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      formatClock(task.at),
                      style: cairo(size: 12, color: NouriColors.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      outcome.titleOf(task.id),
                      style: cairo(size: 13),
                    ),
                  ),
                  Text(
                    toArabicDigits('${task.minutes} د'),
                    style: cairo(size: 11, color: NouriColors.muted),
                  ),
                ],
              ),
            ),
        ],
        if (doc.books.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('كتب ممكن تعجبك',
              style: cairo(size: 13, weight: FontWeight.w600, color: NouriColors.gold)),
          const SizedBox(height: 6),
          for (final book in doc.books)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: cairo(size: 13, weight: FontWeight.w600)),
                  if (book.why != null)
                    Text(book.why!,
                        style: cairo(size: 11.5, color: NouriColors.muted, height: 1.7)),
                ],
              ),
            ),
        ],
        const Divider(color: NouriColors.border, height: 28),
        Text(
          // Said plainly: the plan is a proposal. Applying it to the day is
          // the open question, and until it is answered nothing here writes.
          'دي اقتراح — يومك لسه زي ما نوري رتّبه. لو عايز الخطة دي تتطبّق على '
          'المهام والتنبيهات، دي الخطوة الجاية.'
          '${outcome.model == null ? '' : '\nرد من ${outcome.model}.'}',
          style: cairo(size: 10.5, color: NouriColors.muted, height: 1.8),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('تمام', style: cairo(size: 13.5)),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed(this.outcome);

  final BuildPlanOutcome outcome;

  @override
  Widget build(BuildContext context) => Column(
        key: const ValueKey('plan-result-failed'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('مقدرتش أبني الخطة دلوقتي',
              style: cairo(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            outcome.failure ?? 'مش عارف إيه اللي حصل.',
            style: cairo(size: 12.5, color: NouriColors.muted, height: 1.9),
          ),
          const SizedBox(height: 8),
          Text(
            'يومك لسه زي ما هو، مفيش حاجة اتغيّرت.',
            style: cairo(size: 12.5, color: NouriColors.muted, height: 1.9),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('تمام', style: cairo(size: 13.5)),
          ),
        ],
      );
}
