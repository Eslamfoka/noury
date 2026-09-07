import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/format/arabic_numerals.dart';
import '../../core/notifications/notification_status.dart';
import '../../core/time/location_service.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import '../shared/nouri_avatar.dart';
import 'notification_status_panel.dart';
import 'settings_controller.dart';

/// Live device notification state. Never cached — the panel must show what is
/// true right now, not what was true at launch.
final notificationStatusProvider =
    FutureProvider<NotificationStatus?>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  if (service == null) return null;
  return service.readStatus();
});

final settingsControllerProvider = Provider<SettingsController>((ref) {
  return SettingsController(
    db: ref.watch(databaseProvider),
    scheduler: ref.watch(schedulerPortProvider),
    location: ref.watch(locationPortProvider),
  );
});

/// Overridden in main() with the real geolocator port; null in tests, where
/// there is no platform channel to ask.
final locationPortProvider = Provider<LocationPort?>((ref) => null);

/// Overridden in main() with the real scheduler; a no-op in tests.
final schedulerPortProvider = Provider<SchedulerPort>((ref) => _NoopScheduler());

class _NoopScheduler implements SchedulerPort {
  @override
  Future<void> rearm(config) async {}
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _methods = <String, String>{
    'kuwait': 'الكويت',
    'ummAlQura': 'أم القرى',
    'muslimWorldLeague': 'رابطة العالم الإسلامي',
    'egyptian': 'الهيئة المصرية',
    'qatar': 'قطر',
    'dubai': 'دبي',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final status = ref.watch(notificationStatusProvider);
    final controller = ref.read(settingsControllerProvider);
    final service = ref.read(notificationServiceProvider);

    return settings.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: NouriColors.gold),
      ),
      error: (e, _) => Center(
        child: Text('مش قادر أفتح الإعدادات دلوقتي.',
            style: cairo(size: 14, color: NouriColors.muted)),
      ),
      data: (s) => ListView(
        padding: const EdgeInsets.fromLTRB(15, 18, 15, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإعدادات',
                  style: cairo(size: 17, weight: FontWeight.w700)),
              const NouriAvatar(size: 36),
            ],
          ),
          const SizedBox(height: 18),

          NotificationStatusPanel(
            status: status.value,
            onRequestNotifications: () async {
              await service?.requestNotificationPermission();
              ref.invalidate(notificationStatusProvider);
            },
            onRequestExactAlarms: () async {
              await service?.requestExactAlarmPermission();
              ref.invalidate(notificationStatusProvider);
            },
            onRequestBattery: () async {
              await service?.requestBatteryExemption();
              ref.invalidate(notificationStatusProvider);
            },
            onSendTest: () => service?.sendTestNotification(),
            onScheduleTestAdhan: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              final when = await service?.scheduleTestAdhan();
              if (when == null) return;
              messenger?.showSnackBar(SnackBar(
                duration: const Duration(seconds: 6),
                backgroundColor: NouriColors.surfaceActive,
                content: Text(
                  'الأذان التجريبي هيجي ${formatClock(when)}. '
                  'اقفل التطبيق دلوقتي.',
                  style: cairo(size: 13),
                ),
              ));
            },
          ),
          const SizedBox(height: 20),

          _Section(title: 'الإشعارات', children: [
            _SwitchRow(
              label: 'الأذان',
              value: s.notifyAdhan,
              onChanged: (v) async {
                await controller.toggleChannel('adhan', v);
                ref.invalidate(settingsProvider);
              },
            ),
            _SwitchRow(
              label: 'الإقامة',
              value: s.notifyIqama,
              onChanged: (v) async {
                await controller.toggleChannel('iqama', v);
                ref.invalidate(settingsProvider);
              },
            ),
            _SwitchRow(
              label: 'الأذكار',
              value: s.notifyAthkar,
              onChanged: (v) async {
                await controller.toggleChannel('athkar', v);
                ref.invalidate(settingsProvider);
              },
            ),
            _SwitchRow(
              label: 'ورد القرآن',
              value: s.notifyWird,
              onChanged: (v) async {
                await controller.toggleChannel('wird', v);
                ref.invalidate(settingsProvider);
              },
            ),
            _SwitchRow(
              key: const ValueKey('notify-water'),
              label: 'تنبيه المياه بعد الصلاة',
              value: s.notifyWater,
              onChanged: (v) async {
                await controller.toggleChannel('water', v);
                ref.invalidate(settingsProvider);
              },
            ),
            _SwitchRow(
              key: const ValueKey('notify-fasting'),
              label: 'صيام الاتنين والخميس والأيام البيض',
              value: s.notifyFasting,
              onChanged: (v) async {
                await controller.toggleChannel('fasting', v);
                ref.invalidate(settingsProvider);
              },
            ),
          ]),
          const SizedBox(height: 16),

          _Section(title: 'الدوام', children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'نوري بيرتّب يومك حوالين ورديتك. غيّرها لما تتغيّر.',
                style: cairo(size: 11, color: NouriColors.muted, height: 1.7),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  'morning': 'صباحي',
                  'evening': 'مسائي',
                  'night': 'ليلي',
                  'off': 'راحة',
                }.entries)
                  GestureDetector(
                    key: ValueKey('shift-${entry.key}'),
                    onTap: () async {
                      await controller.updateShift(entry.key);
                      ref.invalidate(settingsProvider);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: s.shiftType == entry.key
                            ? NouriColors.gold
                            : NouriColors.surfaceActive,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: NouriColors.border),
                      ),
                      child: Text(
                        entry.value,
                        style: cairo(
                          size: 12.5,
                          weight: s.shiftType == entry.key
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: s.shiftType == entry.key
                              ? NouriColors.background
                              : NouriColors.text,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ]),
          const SizedBox(height: 16),

          _Section(title: 'البدن والمشي', children: [
            _ActionRow(
              label: 'طول الخطوة',
              value: toArabicDigits('${s.strideCm} سم'),
              action: 'غيّر',
              onTap: () async {
                final cm = await _askStride(context, s.strideCm);
                if (cm == null) return;
                await controller.updateStrideCm(cm);
                ref.invalidate(settingsProvider);
              },
            ),
            _SwitchRow(
              key: const ValueKey('allow-simulated-steps'),
              label: 'خطوات تجريبية (للتجربة بس)',
              value: s.allowSimulatedSteps,
              onChanged: (v) async {
                await controller.setAllowSimulatedSteps(v);
                ref.invalidate(settingsProvider);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'المسافة محسوبة من طول خطوتك، فكل ما يكون مضبوط تكون '
                'المسافة أقرب للحقيقة.',
                style: cairo(size: 11, color: NouriColors.muted, height: 1.7),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          _Section(title: 'مواقيت الصلاة', children: [
            _ActionRow(
              label: 'المدينة',
              value: s.cityLabel,
              action: 'حدّد',
              onTap: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final result = await controller.detectLocation();
                ref.invalidate(settingsProvider);
                // Says plainly what happened. A refusal is not an error, and
                // the app keeps working on the coordinates it already has.
                messenger?.showSnackBar(SnackBar(
                  backgroundColor: NouriColors.surfaceActive,
                  content: Text(
                    result.isFallback
                        ? 'مقدرتش أوصل لموقعك. هفضل على اللي متسجّل.'
                        : 'اتحدّث الموقع. المواقيت اتظبطت عليه.',
                    style: cairo(size: 13),
                  ),
                ));
              },
            ),
            _ChoiceRow(
              label: 'طريقة الحساب',
              value: _methods[s.calculationMethod] ?? s.calculationMethod,
              options: _methods,
              onSelected: (key) async {
                await controller.updateMethod(key);
                ref.invalidate(settingsProvider);
              },
            ),
            _ChoiceRow(
              label: 'حساب العصر',
              value: s.madhab == 'hanafi' ? 'حنفي' : 'شافعي',
              options: const {'shafi': 'شافعي', 'hanafi': 'حنفي'},
              onSelected: (key) async {
                await controller.updateMadhab(key);
                ref.invalidate(settingsProvider);
              },
            ),
            _StepperRow(
              label: 'فرق التاريخ الهجري',
              value: toArabicDigits('${s.hijriOffsetDays}'),
              onDecrement: () async {
                await controller.updateHijriOffset(s.hijriOffsetDays - 1);
                ref.invalidate(settingsProvider);
              },
              onIncrement: () async {
                await controller.updateHijriOffset(s.hijriOffsetDays + 1);
                ref.invalidate(settingsProvider);
              },
            ),
          ]),
          const SizedBox(height: 16),

          // Named distinctly from the «الإقامة» notification toggle above,
          // so the two are never mistaken for each other.
          _Section(title: 'فرق وقت الإقامة', children: [
            for (final entry
                in decodeIqamaOffsets(s.iqamaOffsetsJson).entries)
              _StepperRow(
                label: _prayerLabel(entry.key),
                value: toArabicDigits('${entry.value} د'),
                onDecrement: () async {
                  await controller.updateIqamaOffset(
                      entry.key, entry.value - 5);
                  ref.invalidate(settingsProvider);
                },
                onIncrement: () async {
                  await controller.updateIqamaOffset(
                      entry.key, entry.value + 5);
                  ref.invalidate(settingsProvider);
                },
              ),
          ]),
          const SizedBox(height: 16),

          _Section(title: 'الورد', children: [
            _StepperRow(
              label: 'هدف التسبيح',
              value: toArabicDigits('${s.tasbeehTarget}'),
              onDecrement: () async {
                await controller.updateTasbeehTarget(s.tasbeehTarget - 33);
                ref.invalidate(settingsProvider);
              },
              onIncrement: () async {
                await controller.updateTasbeehTarget(s.tasbeehTarget + 33);
                ref.invalidate(settingsProvider);
              },
            ),
            _ValueRow(
              label: 'صفحات المصحف',
              value: toArabicDigits('${s.khatmaTotalPages}'),
            ),
          ]),
          const SizedBox(height: 20),

          _Section(title: 'عن نوري', children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const NouriAvatar(size: 54),
                  const SizedBox(height: 14),
                  // The slogan lives here rather than on a splash screen: a
                  // splash would cost ~2s of held screen on every launch to
                  // show something the user reads once.
                  Text(
                    'نوري — من الفجر للعشاء: صلاة، حركة، وبركة',
                    textAlign: TextAlign.center,
                    style: cairo(size: 13.5, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'رفيقك اليومي في الديني والبدني والمالي.',
                    textAlign: TextAlign.center,
                    style:
                        cairo(size: 12, color: NouriColors.muted, height: 1.7),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),

          Text(
            'كل بياناتك متخزّنة على الجهاز ده بس. نوري مش بيبعت حاجة لأي '
            'مكان في المرحلة دي.',
            style: cairo(size: 11.5, color: NouriColors.muted, height: 1.8),
          ),
        ],
      ),
    );
  }

  static String _prayerLabel(String key) => switch (key) {
        'fajr' => 'الفجر',
        'dhuhr' => 'الظهر',
        'asr' => 'العصر',
        'maghrib' => 'المغرب',
        'isha' => 'العشاء',
        _ => key,
      };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 2),
            child:
                Text(title, style: cairo(size: 14, weight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: NouriColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: cairo(size: 13.5))),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: NouriColors.gold,
              inactiveThumbColor: NouriColors.muted,
            ),
          ],
        ),
      );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: cairo(size: 13.5)),
            Text(value, style: cairo(size: 13, color: NouriColors.muted)),
          ],
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.value,
    required this.action,
    required this.onTap,
  });

  final String label;
  final String value;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label, style: cairo(size: 13.5))),
            Text(value, style: cairo(size: 13, color: NouriColors.muted)),
            const SizedBox(width: 6),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action,
                  style: cairo(size: 12.5, color: NouriColors.gold)),
            ),
          ],
        ),
      );
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final chosen = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: NouriColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 16),
                    Text(label,
                        style: cairo(size: 15, weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final e in options.entries)
                      ListTile(
                        title: Text(e.value, style: cairo(size: 14)),
                        onTap: () => Navigator.of(ctx).pop(e.key),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
          if (chosen != null) onSelected(chosen);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: cairo(size: 13.5)),
              Row(
                children: [
                  Text(value,
                      style: cairo(size: 13, color: NouriColors.muted)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left,
                      size: 18, color: NouriColors.muted),
                ],
              ),
            ],
          ),
        ),
      );
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final String value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: cairo(size: 13.5))),
            IconButton(
              onPressed: onDecrement,
              icon: const Icon(Icons.remove, size: 18),
              color: NouriColors.muted,
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(
              width: 52,
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: cairo(size: 13.5, weight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: onIncrement,
              icon: const Icon(Icons.add, size: 18),
              color: NouriColors.gold,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
}

/// Asks for a stride in centimetres.
///
/// A plain number field rather than a slider: the user is copying a figure
/// they measured, not exploring a range.
Future<int?> _askStride(BuildContext context, int current) async {
  final controller = TextEditingController(text: '$current');
  final value = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: NouriColors.surface,
      title: Text('طول الخطوة بالسنتيمتر',
          style: cairo(size: 15, weight: FontWeight.w700)),
      content: TextField(
        key: const ValueKey('stride-field'),
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: cairo(size: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('إلغاء', style: cairo(size: 13)),
        ),
        TextButton(
          key: const ValueKey('stride-save'),
          onPressed: () =>
              Navigator.of(ctx).pop(int.tryParse(controller.text.trim())),
          child: Text('احفظ',
              style: cairo(size: 13, color: NouriColors.gold)),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}
