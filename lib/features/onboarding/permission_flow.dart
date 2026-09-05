import 'package:flutter/material.dart';

import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../shared/nouri_avatar.dart';

/// A permission step: what Nouri needs, and one plain sentence of why.
class PermissionStep {
  const PermissionStep({
    required this.title,
    required this.why,
    required this.action,
    required this.onRequest,
  });

  final String title;
  final String why;
  final String action;
  final Future<void> Function() onRequest;
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

/// The three steps, in the order the spec sets: notifications, then battery,
/// then location.
///
/// Each `why` is one plain colloquial sentence — Nouri explains itself rather
/// than demanding.
List<PermissionStep> defaultPermissionSteps({
  required Future<void> Function() requestNotifications,
  required Future<void> Function() requestBattery,
  required Future<void> Function() requestLocation,
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
    ];
