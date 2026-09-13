import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../ai/ai_providers.dart';
import '../home/home_providers.dart';
import '../planner/ai/build_plan.dart';
import '../settings/settings_section_screen.dart';
import '../settings/settings_sections.dart';
import 'plan_result_sheet.dart';
import 'profile_providers.dart';

/// «ابني خطتي» — the button from the second screenshot.
///
/// His words: *«وتحت أو فوق أو في اي مكان يبقى ف زي زر او حاجة معناها ابني
/// الخطة يلا نبدأ حاجة زي كده لو داس عليها ai يحللها ويبعت الخطة»*.
///
/// **It is the only thing in Nouri that opens a network connection**, and
/// only when pressed. Never on a tap elsewhere, never on a screen opening,
/// never on a schedule — the brief is explicit that a call costs the user
/// money and must happen at deliberate moments only. (CONNECT in الإعدادات
/// opens one too, but that one is free: it lists models and spends nothing.)
///
/// Since 13 September 2026 it works: with a key connected in الإعدادات →
/// الذكاء الاصطناعي it assembles the summary, makes the one call, and shows
/// what came back. Without a key it still says so, in the one place the
/// user would press it, and now offers the way to the settings page —
/// a control that does nothing is worse than a control that explains
/// itself, and one that explains and then points is better still.
class BuildPlanButton extends ConsumerStatefulWidget {
  const BuildPlanButton({super.key});

  @override
  ConsumerState<BuildPlanButton> createState() => _BuildPlanButtonState();
}

class _BuildPlanButtonState extends ConsumerState<BuildPlanButton> {
  bool _busy = false;

  Future<void> _press() async {
    if (_busy) return;

    // Everything off `ref` before the first await.
    final connection = ref.read(aiConnectionProvider).value;
    final db = ref.read(databaseProvider);
    final prayerTimes = ref.read(prayerTimesServiceProvider);
    final client = ref.read(aiClientProvider);

    if (connection == null) {
      _explainNotReady(context);
      return;
    }

    setState(() => _busy = true);
    final outcome = await buildPlan(
      db: db,
      prayerTimes: prayerTimes,
      client: client,
      connection: connection,
      now: DateTime.now(),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    await showPlanResultSheet(context, outcome);
  }

  @override
  Widget build(BuildContext context) {
    final filled = ref.watch(profileCompletenessProvider);
    // Watched so the hint under the button can say whether a key is there,
    // and so a key connected a moment ago is seen without leaving the screen.
    final connected = ref.watch(aiConnectionProvider).value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: _busy ? NouriColors.surfaceActive : NouriColors.gold,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const ValueKey('build-my-plan'),
            borderRadius: BorderRadius.circular(14),
            onTap: _busy ? null : _press,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_busy)
                    const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: NouriColors.gold),
                    )
                  else
                    const Icon(Icons.auto_awesome,
                        color: NouriColors.background, size: 19),
                  const SizedBox(width: 9),
                  Text(
                    _busy ? 'نوري بيفكّر…' : 'ابني خطتي',
                    style: cairo(
                      size: 15,
                      weight: FontWeight.w700,
                      color: _busy ? NouriColors.muted : NouriColors.background,
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
        if (!connected)
          Text(
            'محتاج مفتاح من الإعدادات → الذكاء الاصطناعي الأول.',
            key: const ValueKey('build-plan-needs-key'),
            textAlign: TextAlign.center,
            style: cairo(size: 11, color: NouriColors.muted, height: 1.8),
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
      builder: (ctx) => Padding(
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
              'بناء الخطة بيحصل عن طريق خدمة ذكاء اصطناعي — Claude أو غيرها — '
              'وده محتاج مفتاح API بتاعك انت. نوري مش بيبعت حاجة على حسابه، '
              'والحساب بيبقى عندك.',
              style: cairo(size: 12.5, color: NouriColors.muted, height: 1.9),
            ),
            const SizedBox(height: 10),
            Text(
              'لما تحطه وتدوس CONNECT، الزرار ده هيشتغل: هيبعت الملخّص اللي '
              'فوق بس، ويرجّعلك خطة موزّعة على مهام بموعيدها.',
              style: cairo(size: 12.5, color: NouriColors.muted, height: 1.9),
            ),
            const SizedBox(height: 18),
            Material(
              color: NouriColors.gold,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: const ValueKey('build-plan-open-ai-settings'),
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsSectionScreen(
                        section: SettingsSection.ai,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'افتح إعدادات الذكاء الاصطناعي',
                    textAlign: TextAlign.center,
                    style: cairo(
                      size: 13.5,
                      weight: FontWeight.w700,
                      color: NouriColors.background,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('تمام', style: cairo(size: 13.5)),
            ),
          ],
        ),
      ),
    );
  }
}
