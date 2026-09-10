import 'package:flutter/material.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../shared/nouri_avatar.dart';

/// One thing Nouri offers to pick up on the way in, and one plain sentence of
/// why.
///
/// Usually a permission. It can also be a **choice** — [choices] non-empty —
/// for the one thing Nouri cannot work out for itself and cannot sensibly
/// guess: which shift the user works. Everything else it can default. Getting
/// the shift wrong means the whole planned day is wrong on first run, which is
/// a poor way to meet someone.
class PermissionStep {
  const PermissionStep({
    required this.title,
    required this.why,
    required this.action,
    required this.onRequest,
    this.choices = const [],
    this.onChoose,
  });

  final String title;
  final String why;

  /// The label on the accept button. Ignored for a choice step, which has a
  /// button per option instead.
  final String action;

  final Future<void> Function() onRequest;

  /// When non-empty this is a choice rather than a permission.
  final List<StepChoice> choices;

  /// Called with the chosen value. Skipping leaves the default in place.
  final Future<void> Function(String)? onChoose;

  bool get isChoice => choices.isNotEmpty;
}

/// One option on a choice step.
class StepChoice {
  const StepChoice({required this.label, required this.value});

  final String label;

  /// What gets stored — the settings value, not the Arabic label.
  final String value;
}

/// First-launch permission flow.
///
/// Every step is skippable and nothing blocks progress: without location Nouri
/// uses Kuwait, and without notifications it still tracks everything in-app.
/// The app degrades; it never refuses to work.
class PermissionFlow extends StatefulWidget {
  const PermissionFlow({
    super.key,
    required this.steps,
    required this.onDone,
  });

  final List<PermissionStep> steps;
  final VoidCallback onDone;

  @override
  State<PermissionFlow> createState() => _PermissionFlowState();
}

class _PermissionFlowState extends State<PermissionFlow> {
  int _index = 0;

  void _advance() {
    if (_index < widget.steps.length - 1) {
      setState(() => _index++);
    } else {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const NouriAvatar(size: 72),
              const SizedBox(height: 26),
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: cairo(size: 20, weight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              Text(
                step.why,
                textAlign: TextAlign.center,
                style: cairo(
                  size: 14,
                  color: NouriColors.muted,
                  height: 1.9,
                ),
              ),
              if (step.isChoice) ...[
                const SizedBox(height: 26),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in step.choices)
                      GestureDetector(
                        key: ValueKey('onboarding-choice-${c.value}'),
                        onTap: () async {
                          await step.onChoose?.call(c.value);
                          if (mounted) _advance();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 13),
                          decoration: BoxDecoration(
                            color: NouriColors.surfaceActive,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: NouriColors.border),
                          ),
                          child: Text(c.label,
                              style: cairo(
                                  size: 14, weight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              ],
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: i == _index ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i == _index
                              ? NouriColors.gold
                              : NouriColors.surfaceActive,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              // A choice step has its options above; a single accept button
              // under them would be a second, ambiguous way to answer.
              if (!step.isChoice)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: NouriColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  onPressed: () async {
                    await step.onRequest();
                    if (mounted) _advance();
                  },
                  child: Text(
                    step.action,
                    style: cairo(
                      size: 16,
                      weight: FontWeight.w700,
                      color: NouriColors.background,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _advance,
                child: Text(
                  'تخطّي',
                  style: cairo(size: 13, color: NouriColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four steps: notifications, battery, location, then the shift.
///
/// The permissions come first because they are what the spec sets, and the
/// shift last because it is the only one that is a question rather than a
/// request — a better note to finish on than a third permission prompt.
///
/// Each `why` is one plain colloquial sentence — Nouri explains itself rather
/// than demanding.
List<PermissionStep> defaultPermissionSteps({
  required Future<void> Function() requestNotifications,
  required Future<void> Function() requestBattery,
  required Future<void> Function() requestLocation,
  Future<void> Function(String)? chooseShift,
}) =>
    [
      PermissionStep(
        title: 'الإشعارات',
        why: 'عشان أقدر أنبّهك بالأذان والإقامة والأذكار في وقتها.',
        action: 'اسمح بالإشعارات',
        onRequest: requestNotifications,
      ),
      PermissionStep(
        title: 'البطارية',
        why: 'عشان التنبيهات توصلك حتى لو التطبيق مقفول.',
        action: 'استثنِ نوري',
        onRequest: requestBattery,
      ),
      PermissionStep(
        title: 'الموقع',
        why: 'عشان أحسب مواقيت الصلاة بدقة. من غيره هستخدم الكويت.',
        action: 'اسمح بالموقع',
        onRequest: requestLocation,
      ),
      PermissionStep(
        title: 'ورديتك',
        // The one thing Nouri cannot work out and should not guess. Skipping
        // leaves the morning shift, which is the commonest and is changeable
        // any time in الإعدادات.
        why: 'عشان أرتّب يومك حوالين شغلك. تقدر تغيّرها في أي وقت.',
        action: 'تخطّي',
        onRequest: () async {},
        choices: const [
          StepChoice(label: 'صباحي', value: 'morning'),
          StepChoice(label: 'مسائي', value: 'evening'),
          StepChoice(label: 'ليلي', value: 'night'),
          StepChoice(label: 'راحة', value: 'off'),
        ],
        onChoose: chooseShift,
      ),
    ];
