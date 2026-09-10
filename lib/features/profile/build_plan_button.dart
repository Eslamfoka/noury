import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import 'profile_providers.dart';

/// «ابني خطتي» — the button from the second screenshot.
///
/// His words: *«وتحت أو فوق أو في اي مكان يبقى ف زي زر او حاجة معناها ابني
/// الخطة يلا نبدأ حاجة زي كده لو داس عليها ai يحللها ويبعت الخطة»*.
///
/// **It is the only thing in Nouri that will ever open a network connection**,
/// and only when pressed. Never on a tap elsewhere, never on a screen opening,
/// never on a schedule — the brief is explicit that a call costs the user money
/// and must happen at deliberate moments only.
///
/// Right now it cannot call anything: there is no API key and no client bound.
/// So it says so, in the one place the user would press it, rather than
/// appearing to work and quietly doing nothing. That is the same rule the walk
/// screen follows about the step permission — a control that does nothing is
/// worse than a control that explains itself.
class BuildPlanButton extends ConsumerWidget {
  const BuildPlanButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filled = ref.watch(profileCompletenessProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: NouriColors.gold,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const ValueKey('build-my-plan'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => _explainNotReady(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome,
                      color: NouriColors.background, size: 19),
                  const SizedBox(width: 9),
                  Text(
                    'ابني خطتي',
                    style: cairo(
                      size: 15,
                      weight: FontWeight.w700,
                      color: NouriColors.background,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          _hint(filled),
          key: const ValueKey('build-plan-hint'),
          textAlign: TextAlign.center,
          style: cairo(size: 11.5, color: NouriColors.muted, height: 1.8),
        ),
      ],
    );
  }

  /// What a fuller profile would buy him — never a mark out of ten.
  ///
  /// A percentage here would be a score for how well he has filled in a form
  /// about his own life, which is the self-blame the brief forbids outright.
  /// So the sentence names the *benefit* of adding more and never the shortfall.
  static String _hint(double filled) {
    if (filled >= 0.75) {
      return 'نوري عارف عنك كفاية عشان يبني خطة قريبة منك.';
    }
    if (filled >= 0.35) {
      return 'كل ما تزوّد حاجة فوق، الخطة تطلع أقرب ليك.';
    }
    return 'تقدر تدوس دلوقتي — بس لو كمّلت اللي فوق، الخطة هتبقى على مقاسك '
        'أكتر بكتير.';
  }

  void _explainNotReady(BuildContext context) {
    // Deliberately a sheet rather than a snackbar: this is an explanation with
    // two paragraphs and a next step, not a passing note.
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: NouriColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('لسه ناقص حاجة واحدة',
                key: const ValueKey('build-plan-not-ready'),
                style: cairo(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text(
              'بناء الخطة بيحصل عن طريق Claude، وده محتاج مفتاح API بتاعك '
              'انت — نوري مش بيبعت حاجة على حسابه، والحساب بيبقى عندك.',
              style: cairo(size: 12.5, color: NouriColors.muted, height: 1.9),
            ),
            const SizedBox(height: 10),
            Text(
              'لما تحطه في الإعدادات، الزرار ده هيشتغل: هيبعت الملخّص اللي '
              'فوق بس، ويرجّعلك خطة موزّعة على مهام بموعيدها.',
              style: cairo(size: 12.5, color: NouriColors.muted, height: 1.9),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('تمام', style: cairo(size: 13.5)),
            ),
          ],
        ),
      ),
    );
  }
}
