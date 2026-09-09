import 'package:flutter/material.dart';

import '../../core/notifications/notification_status.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';

/// Shows plainly whether the adhan will actually arrive on time.
///
/// Nouri never claims a reliability it does not have: when exact alarms are
/// unavailable this says so and explains the consequence, rather than failing
/// silently. Nothing here is red — an ungranted permission is something to
/// fix, not a failure to be scolded for.
class NotificationStatusPanel extends StatelessWidget {
  const NotificationStatusPanel({
    super.key,
    required this.status,
    required this.onRequestNotifications,
    required this.onRequestExactAlarms,
    required this.onRequestBattery,
    required this.onRequestDndBypass,
    required this.onSendTest,
    required this.onScheduleTestAdhan,
  });

  final NotificationStatus? status;
  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestExactAlarms;
  final VoidCallback onRequestBattery;

  /// Opens the system screen that lets the adhan through Do Not Disturb.
  final VoidCallback onRequestDndBypass;

  final VoidCallback onSendTest;

  /// Schedules a real alarm a couple of minutes out, so the user can close the
  /// app and confirm it still fires.
  final VoidCallback onScheduleTestAdhan;

  @override
  Widget build(BuildContext context) {
    final s = status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NouriColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('حالة التنبيهات',
              style: cairo(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (s == null)
            Text('بيتحقق…', style: cairo(size: 12, color: NouriColors.muted))
          else ...[
            _StatusRow(
              label: 'الإشعارات مفعّلة',
              ok: s.notificationsEnabled,
              onFix: onRequestNotifications,
            ),
            _StatusRow(
              label: 'التنبيهات الدقيقة مسموحة',
              ok: s.exactAlarmsAllowed,
              onFix: onRequestExactAlarms,
            ),
            _StatusRow(
              label: 'مستثنى من توفير البطارية',
              ok: !s.batteryOptimised,
              onFix: onRequestBattery,
            ),
            _StatusRow(
              label: 'الأذان بيعدّي وضع «عدم الإزعاج»',
              ok: s.adhanBypassesDnd,
              onFix: onRequestDndBypass,
            ),
            if (!s.adhanBypassesDnd) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: NouriColors.background,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: NouriColors.border),
                ),
                child: Text(
                  'وانت نايم بالنهار بعد وردية ليل، لو «عدم الإزعاج» شغّال '
                  'الأذان هيوصل من غير صوت. الإذن ده بيتاخد من إعدادات '
                  'النظام — نوري ما يقدرش ياخده لوحده — ولما تديه، نوري '
                  'هيعيد بناء قنوات الأذان ويظبط التنبيهات من تاني.',
                  style: cairo(
                    size: 11.5,
                    color: NouriColors.muted,
                    height: 1.8,
                  ),
                ),
              ),
            ],
            if (s.mode == NotificationMode.inexact) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: NouriColors.background,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: NouriColors.attention),
                ),
                child: Text(
                  'التنبيهات الدقيقة مش متاحة على الجهاز ده، فالأذان ممكن '
                  'يوصل متأخر شوية عن وقته.',
                  style: cairo(
                    size: 11.5,
                    color: NouriColors.muted,
                    height: 1.75,
                  ),
                ),
              ),
            ],
            if (s.batteryOptimised) ...[
              const SizedBox(height: 10),
              Text(
                'لو التنبيهات وقفت وأنت قافل التطبيق: افتح إعدادات النظام → '
                'البطارية، وخلّي نوري «بدون قيود». في أجهزة كتير فيه كمان '
                'مدير طاقة منفصل لازم تسمح منه.',
                style: cairo(
                  size: 11.5,
                  color: NouriColors.muted,
                  height: 1.75,
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onSendTest,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: NouriColors.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: Text('إرسال إشعار تجريبي',
                style: cairo(size: 13.5, color: NouriColors.gold)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onScheduleTestAdhan,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: NouriColors.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: Text('جرّب الأذان بعد دقيقتين',
                style: cairo(size: 13.5, color: NouriColors.gold)),
          ),
          const SizedBox(height: 6),
          Text(
            'اقفل التطبيق بعد ما تدوس، وشوف الأذان هيوصلك ولا لأ.',
            textAlign: TextAlign.center,
            style: cairo(size: 11, color: NouriColors.muted),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.ok,
    required this.onFix,
  });

  final String label;
  final bool ok;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: ok ? NouriColors.success : NouriColors.attention,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(label, style: cairo(size: 13))),
          if (!ok)
            TextButton(
              onPressed: onFix,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('اسمح',
                  style: cairo(size: 12, color: NouriColors.gold)),
            ),
        ],
      ),
    );
  }
}
