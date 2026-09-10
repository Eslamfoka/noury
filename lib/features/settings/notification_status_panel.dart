import 'package:flutter/material.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/notifications/armed_window.dart';
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
    this.armed,
    this.today,
    required this.onRearm,
    required this.onRequestNotifications,
    required this.onRequestExactAlarms,
    required this.onRequestBattery,
    required this.onRequestDndBypass,
    required this.onSendTest,
    required this.onScheduleTestAdhan,
  });

  final NotificationStatus? status;

  /// What the device is actually holding, or null while it is being read.
  final ArmedWindow? armed;

  /// Passed in rather than read from the clock, so the row can be tested and
  /// so it agrees with the rest of the app about which day it is — this app
  /// turns over at midnight rather than at whenever it was last launched.
  final DateTime? today;

  /// Builds the window again. The remedy for a gap, and harmless otherwise:
  /// re-arming is idempotent by design.
  final VoidCallback onRearm;

  final VoidCallback onRequestNotifications;
  final VoidCallback onRequestExactAlarms;
  final VoidCallback onRequestBattery;

  /// Opens the system screen that lets the adhan through Do Not Disturb.
  final VoidCallback onRequestDndBypass;

  final VoidCallback onSendTest;

  /// Schedules a real alarm a couple of minutes out, so the user can close the
  /// app and confirm it still fires.
  final VoidCallback onScheduleTestAdhan;

  List<DateTime> get _gaps {
    final a = armed;
    final t = today;
    if (a == null || t == null) return const [];
    return a.gapsAfter(t);
  }

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
            _ArmedRow(armed: armed, today: today, onFix: onRearm),
            if (_gaps.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: NouriColors.background,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: NouriColors.attention),
                ),
                child: Text(
                  'فيه ${toArabicDigits('${_gaps.length}')} '
                  '${_gaps.length == 1 ? 'يوم' : 'أيام'} قدّامك من غير أذان — '
                  'أول واحد ${_arabicDay(_gaps.first)}. ده بيحصل لو نوري '
                  'اتقفل وهو لسه بيظبط التنبيهات. دوس «صلّح» ويرجع تاني.',
                  style: cairo(
                    size: 11.5,
                    color: NouriColors.muted,
                    height: 1.8,
                  ),
                ),
              ),
            ],
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

/// «التنبيهات متظبّطة لحد …» — the row that answers whether it actually
/// happened, rather than whether it was allowed to.
///
/// It shows the number even when everything is fine, because a count is the
/// one thing on this panel a person can sanity-check for themselves, and
/// because "273 alarms, through the 23rd" is a far more reassuring sentence
/// than a tick.
class _ArmedRow extends StatelessWidget {
  const _ArmedRow({
    required this.armed,
    required this.today,
    required this.onFix,
  });

  final ArmedWindow? armed;
  final DateTime? today;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final a = armed;
    final t = today;
    if (a == null || t == null) {
      return _StatusRow(
        label: 'التنبيهات المتظبّطة',
        ok: true,
        onFix: onFix,
        trailing: 'بيتحقق…',
      );
    }

    final gaps = a.gapsAfter(t);
    final through = a.coversThrough;

    // Nothing armed at all is not this row's story to tell — the permission
    // rows above already explain why nothing would be, and turning off every
    // notification is a thing the user is allowed to do.
    if (a.count == 0) {
      return _StatusRow(
        label: 'التنبيهات المتظبّطة',
        ok: true,
        onFix: onFix,
        trailing: 'مفيش',
      );
    }

    return _StatusRow(
      label: 'التنبيهات المتظبّطة',
      ok: gaps.isEmpty,
      onFix: onFix,
      fixLabel: 'صلّح',
      trailing: through == null
          ? toArabicDigits('${a.count}')
          : '${toArabicDigits('${a.count}')} — لحد ${_arabicDay(through)}',
    );
  }
}

String _arabicDay(DateTime d) =>
    '${toArabicDigits('${d.day}')} ${_months[d.month - 1]}';

const _months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.ok,
    required this.onFix,
    this.trailing,
    this.fixLabel,
  });

  final String label;
  final bool ok;
  final VoidCallback onFix;

  /// A number or a date shown beside the label, for the rows where the fact
  /// itself is worth reading rather than only its tick.
  final String? trailing;

  final String? fixLabel;

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
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                trailing!,
                style: cairo(size: 11.5, color: NouriColors.muted),
              ),
            ),
          if (!ok)
            TextButton(
              key: fixLabel == null ? null : ValueKey('fix-$label'),
              onPressed: onFix,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(fixLabel ?? 'اسمح',
                  style: cairo(size: 12, color: NouriColors.gold)),
            ),
        ],
      ),
    );
  }
}
