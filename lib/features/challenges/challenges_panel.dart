import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import 'challenge.dart';
import 'challenge_providers.dart';

/// التحديات — inside التقارير rather than behind a seventh bottom tab.
///
/// A challenge is a way of reading your own record over weeks, which is what
/// this tab is for. It also keeps the shell at six destinations while the tab
/// structure is still an open Slice 2 question.
class ChallengesPanel extends ConsumerWidget {
  const ChallengesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeChallengesProvider);
    final available = ref.watch(availableChallengesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('التحديات', style: cairo(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        ...active.when(
          loading: () => const [
            Center(child: CircularProgressIndicator(color: NouriColors.gold)),
          ],
          error: (_, _) => [
            Text(
              'مش قادر أحسب التحديات دلوقتي.',
              style: cairo(size: 12, color: NouriColors.muted),
            ),
          ],
          data: (rows) => [
            for (final a in rows) ...[
              _ActiveCard(challenge: a),
              const SizedBox(height: 9),
            ],
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'لسه مادخلتش أي تحدي. اختار واحد تحت وابدأ من النهاردة.',
                  key: const ValueKey('no-active-challenges'),
                  style:
                      cairo(size: 12, color: NouriColors.muted, height: 1.8),
                ),
              ),
          ],
        ),
        ...available.when(
          loading: () => const <Widget>[],
          error: (_, _) => const <Widget>[],
          data: (rows) => [
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'تحديات تقدر تبدأها',
                style: cairo(size: 12.5, color: NouriColors.muted),
              ),
              const SizedBox(height: 8),
              for (final c in rows) ...[
                _AvailableCard(def: c),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ],
    );
  }
}

class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.challenge});

  final ActiveChallenge challenge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = challenge.progress;
    final def = challenge.def;

    return Container(
      key: ValueKey('challenge-active-${def.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: p.isComplete ? NouriColors.success : NouriColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(def.nameAr,
                    style: cairo(size: 14, weight: FontWeight.w700)),
              ),
              Text(
                toArabicDigits('${p.daysDone} من ${p.targetDays} يوم'),
                key: ValueKey('challenge-progress-${def.id}'),
                style: cairo(size: 12, color: NouriColors.gold),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: p.fraction,
              minHeight: 5,
              backgroundColor: NouriColors.surfaceActive,
              valueColor: AlwaysStoppedAnimation(
                p.isComplete ? NouriColors.success : NouriColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            _statusLine(def, p),
            key: ValueKey('challenge-status-${def.id}'),
            style: cairo(size: 11.5, color: NouriColors.muted, height: 1.7),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: ValueKey('challenge-leave-${challenge.enrollmentId}'),
              onPressed: () => ref
                  .read(challengeControllerProvider)
                  .leave(challenge.enrollmentId),
              child: Text('سيب التحدي',
                  style: cairo(size: 11.5, color: NouriColors.muted)),
            ),
          ),
        ],
      ),
    );
  }

  /// The encouraging half of the feature.
  ///
  /// A broken streak is a fact about the challenge — forty days in the mosque
  /// means forty in a row — but it is never reported as a failure, never in
  /// red, and never without a way forward. There is no failure colour in the
  /// palette to reach for even if this wanted one.
  static String _statusLine(ChallengeDef def, ChallengeProgress p) {
    if (p.isComplete) return 'خلّصت التحدي. تقبّل الله منك.';

    if (def.mode == ChallengeMode.streak) {
      if (p.currentStreak == 0 && p.bestStreak > 0) {
        return toArabicDigits(
          'ابدأ من تاني — اللي فات مش ضايع. أطول مرة وصلت '
          '${p.bestStreak} يوم.',
        );
      }
      if (p.completedToday) {
        return toArabicDigits('النهاردة تمام. فاضل ${p.remaining} يوم.');
      }
      return toArabicDigits('فاضل ${p.remaining} يوم.');
    }

    if (p.completedToday) {
      return toArabicDigits('النهاردة اتحسب. فاضل ${p.remaining} يوم.');
    }
    return toArabicDigits('فاضل ${p.remaining} يوم — مش لازم ورا بعض.');
  }
}

class _AvailableCard extends ConsumerWidget {
  const _AvailableCard({required this.def});

  final ChallengeDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: ValueKey('challenge-available-${def.id}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(def.nameAr,
                    style: cairo(size: 13, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(def.descriptionAr,
                    style: cairo(size: 11, color: NouriColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            key: ValueKey('challenge-join-${def.id}'),
            style: FilledButton.styleFrom(
              backgroundColor: NouriColors.gold,
              foregroundColor: NouriColors.background,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () =>
                ref.read(challengeControllerProvider).join(def.id),
            child: Text(
              'ابدأ',
              style: cairo(
                size: 12,
                weight: FontWeight.w700,
                color: NouriColors.background,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
