import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/format/arabic_numerals.dart';
import '../../core/notifications/armed_window.dart';
import '../../core/notifications/notification_status.dart';
import '../../core/time/location_service.dart';
import '../../core/theme/nouri_colors.dart';
import '../profile/profile_screen.dart';
import '../../core/theme/nouri_theme.dart';
import '../home/home_providers.dart';
import '../shared/nouri_avatar.dart';
import 'notification_status_panel.dart';
import 'settings_controller.dart';
import 'settings_section_screen.dart';
import 'settings_sections.dart';

/// Live device notification state. Never cached — the panel must show what is
/// true right now, not what was true at launch.
final notificationStatusProvider =
    FutureProvider<NotificationStatus?>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  if (service == null) return null;
  return service.readStatus();
});

/// What the device is actually holding, read back on every settings open.
///
/// Deliberately not cached and deliberately not derived from what the
/// scheduler believes it armed. The whole point is that those two can differ:
/// on 10 September 2026 they did, by four days, and nothing said so.
final armedWindowProvider = FutureProvider<ArmedWindow?>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  if (service == null) return null;
  return service.readArmedWindow();
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

/// الإعدادات — an index, not a wall.
///
/// It used to be one column holding all seven groups, about twelve screens
/// long, so reaching the iqama offsets meant scrolling past every notification
/// switch and the whole shift picker. The user asked for the obvious thing:
/// tap الإشعارات and get the notification settings, tap فرق وقت الإقامة and
/// get that.
///
/// Two things stay on the index rather than moving into a section. The
/// notification-status panel is a warning surface — an ungranted permission
/// means the adhan will not fire, and that belongs where it is seen on the way
/// in, not two taps deep. And the privacy line stays at the bottom, because it
/// is a statement about the whole app rather than about any one setting.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Re-reads the device when the user comes back from a system screen.
  ///
  /// Three of the four rows in the panel send the user out of Nouri to grant
  /// something, and Android gives no callback when they return. Without this
  /// the panel would go on saying «مش مفعّل» about a permission the user just
  /// granted, until the next cold launch.
  ///
  /// Do Not Disturb needs more than a re-read: a channel's bypass is fixed at
  /// creation, so granting the access means building the adhan channels again
  /// on the bypassing variant and re-arming the fortnight onto them. That is
  /// the standing rule of this project — any setting that can change an alarm
  /// must re-arm — reached by a slightly unusual road.
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _onResume() async {
    final service = ref.read(notificationServiceProvider);
    if (service == null) return;

    await service.refreshAdhanChannels();
    if (!mounted) return;
    ref.read(settingsControllerProvider).rearmAfterExternalChange();
    ref.invalidate(notificationStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(notificationStatusProvider);
    final armed = ref.watch(armedWindowProvider);
    final service = ref.read(notificationServiceProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('الإعدادات', style: cairo(size: 17, weight: FontWeight.w700)),
            const NouriAvatar(size: 36),
          ],
        ),
        const SizedBox(height: 18),

        NotificationStatusPanel(
          status: status.value,
          armed: armed.value,
          today: ref.watch(currentDayProvider),
          onRearm: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            ref.read(settingsControllerProvider).rearmAfterExternalChange();
            messenger?.showSnackBar(SnackBar(
              duration: const Duration(seconds: 4),
              backgroundColor: NouriColors.surface,
              content: Text(
                'بظبّط التنبيهات تاني — سيبه ثواني وارجع اقرا الرقم.',
                style: cairo(size: 12.5),
              ),
            ));
            // The re-arm runs off the UI thread and takes a few seconds, so
            // re-reading immediately would show the old number and look like
            // the button did nothing.
            await Future<void>.delayed(const Duration(seconds: 12));
            ref.invalidate(armedWindowProvider);
          },
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
          onRequestDndBypass: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final opened = await service?.openDndSettings() ?? false;
            if (!opened) {
              messenger?.showSnackBar(SnackBar(
                duration: const Duration(seconds: 6),
                backgroundColor: NouriColors.surfaceActive,
                content: Text(
                  'الجهاز ده مش فاتح شاشة إذن «عدم الإزعاج». ادخل إعدادات '
                  'النظام → الإشعارات → عدم الإزعاج، وادِّي نوري إذن الوصول.',
                  style: cairo(size: 13),
                ),
              ));
            }
            // Nothing is applied here. The user is now on a system screen, and
            // whatever they choose there takes effect when they come back —
            // see _onResume, which rebuilds the channels and re-arms.
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

        // الملف الشخصي sits above the settings sections rather than among
        // them, because it is not a setting. Settings are how Nouri behaves;
        // this is who it is behaving for, and it is the one row here that
        // leads somewhere the user is meant to *finish* something.
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ProfileRow(),
        ),

        for (final section in SettingsSection.values) ...[
          _SectionRow(section: section),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 10),
        Text(
          'كل بياناتك متخزّنة على الجهاز ده بس. نوري مش بيبعت حاجة لأي '
          'مكان في المرحلة دي.',
          style: cairo(size: 11.5, color: NouriColors.muted, height: 1.8),
        ),
      ],
    );
  }
}

/// One tappable row on the index.
/// The way into الملف الشخصي and «ابني خطتي».
class _ProfileRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const ValueKey('open-profile'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            color: NouriColors.surfaceActive,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NouriColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: NouriColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الملف الشخصي',
                        style: cairo(size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('بياناتك، وزرار «ابني خطتي»',
                        style:
                            cairo(size: 11.5, color: NouriColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: NouriColors.muted),
            ],
          ),
        ),
      );
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: ValueKey('settings-section-${section.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsSectionScreen(section: section),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: NouriColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(section.icon, size: 20, color: NouriColors.gold),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.title,
                        style: cairo(size: 14, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      section.summary,
                      style: cairo(size: 11, color: NouriColors.muted),
                    ),
                  ],
                ),
              ),
              // Points the way the language reads.
              const Icon(Icons.chevron_left,
                  size: 20, color: NouriColors.muted),
            ],
          ),
        ),
      );
}
