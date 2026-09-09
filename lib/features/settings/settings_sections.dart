import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../app.dart';
import '../../core/notifications/adhan_sounds.dart';
import '../../core/notifications/task_alert.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import '../shared/nouri_avatar.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// The eight parts of الإعدادات, each its own page.
///
/// Reported from the phone on 8 September 2026:
///
///   «عايز الاعدادات دي متكنش كلها مع بعض — لا، عايز مثلا الاشعارات ادوس
///   عليها تفتح الخاص بالاشعارات، فرق وقت الإقامة ادوس عليها تيجي كده»
///
/// The seven groups already existed; they were simply stacked in one column
/// about twelve screens long, so reaching the iqama offsets meant scrolling
/// past every notification switch and the whole shift picker. **No setting
/// moved between groups in the split and no control changed behaviour** —
/// only the navigation did, which is why every existing per-control test
/// still means what it meant.
enum SettingsSection {
  notifications('الإشعارات', Icons.notifications_none),
  duty('الدوام', Icons.badge_outlined),
  body('البدن والمشي', Icons.directions_walk),
  prayerTimes('مواقيت الصلاة', Icons.schedule),
  iqamaOffsets('فرق وقت الإقامة', Icons.more_time),
  wird('الورد', Icons.menu_book_outlined),
  sounds('الأصوات', Icons.graphic_eq),
  about('عن نوري', Icons.info_outline);

  const SettingsSection(this.title, this.icon);

  final String title;
  final IconData icon;

  /// One line under the title on the index, so a row says what is inside it
  /// rather than making the user open it to find out.
  String get summary => switch (this) {
        SettingsSection.notifications => 'الأذان، الإقامة، الأذكار، المياه',
        SettingsSection.duty => 'ورديتك دلوقتي',
        SettingsSection.body => 'طول الخطوة والمشي',
        SettingsSection.prayerTimes => 'المدينة، طريقة الحساب، التاريخ الهجري',
        SettingsSection.iqamaOffsets => 'كام دقيقة بين الأذان والإقامة',
        SettingsSection.wird => 'هدف التسبيح وصفحات المصحف',
        SettingsSection.sounds => 'اسمع كل أذان وكل تنبيه قبل ميعاده',
        SettingsSection.about => 'نوري، وخصوصية بياناتك',
      };
}

const _methods = <String, String>{
  'kuwait': 'الكويت',
  'ummAlQura': 'أم القرى',
  'muslimWorldLeague': 'رابطة العالم الإسلامي',
  'egyptian': 'الهيئة المصرية',
  'qatar': 'قطر',
  'dubai': 'دبي',
};

String prayerLabel(String key) => switch (key) {
      'fajr' => 'الفجر',
      'dhuhr' => 'الظهر',
      'asr' => 'العصر',
      'maghrib' => 'المغرب',
      'isha' => 'العشاء',
      _ => key,
    };

/// The controls belonging to one section.
///
/// Moved here verbatim from the single scrolling column. Each body is the same
/// code it was, with the same keys, so the tests that tap them still tap the
/// same widgets.
List<Widget> settingsSectionChildren(
  SettingsSection section,
  BuildContext context,
  WidgetRef ref,
  SettingsRow s,
  SettingsController controller,
) =>
    switch (section) {
      SettingsSection.notifications => [
          SwitchRow(
            label: 'الأذان',
            value: s.notifyAdhan,
            onChanged: (v) async {
              await controller.toggleChannel('adhan', v);
              ref.invalidate(settingsProvider);
            },
          ),
          SwitchRow(
            label: 'الإقامة',
            value: s.notifyIqama,
            onChanged: (v) async {
              await controller.toggleChannel('iqama', v);
              ref.invalidate(settingsProvider);
            },
          ),
          SwitchRow(
            label: 'الأذكار',
            value: s.notifyAthkar,
            onChanged: (v) async {
              await controller.toggleChannel('athkar', v);
              ref.invalidate(settingsProvider);
            },
          ),
          SwitchRow(
            label: 'ورد القرآن',
            value: s.notifyWird,
            onChanged: (v) async {
              await controller.toggleChannel('wird', v);
              ref.invalidate(settingsProvider);
            },
          ),
          SwitchRow(
            key: const ValueKey('notify-water'),
            label: 'تنبيه المياه بعد الصلاة',
            value: s.notifyWater,
            onChanged: (v) async {
              await controller.toggleChannel('water', v);
              ref.invalidate(settingsProvider);
            },
          ),
          SwitchRow(
            key: const ValueKey('notify-tasks'),
            label: 'تنبيهات مهام اليوم',
            value: s.notifyTasks,
            onChanged: (v) async {
              await controller.toggleChannel('tasks', v);
              ref.invalidate(settingsProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 4),
            child: Text(
              'كل مهمة في خطة يومك ليها تنبيه في وقتها، وصوت مختلف تعرفها '
              'منه من غير ما تفتح التطبيق. الأذان مالوش دعوة بالمفتاح ده.',
              style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
            ),
          ),
          SwitchRow(
            key: const ValueKey('notify-qiyam'),
            label: 'قيام الليل',
            value: s.notifyQiyam,
            onChanged: (v) async {
              await controller.toggleChannel('qiyam', v);
              ref.invalidate(settingsProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 4),
            child: Text(
              'في الثلث الأخير من الليل. بيسكت لوحده في وردية الليل، '
              'عشان الوقت ده كله دوام.',
              style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
            ),
          ),
          SwitchRow(
            key: const ValueKey('notify-fasting'),
            label: 'صيام الاتنين والخميس والأيام البيض',
            value: s.notifyFasting,
            onChanged: (v) async {
              await controller.toggleChannel('fasting', v);
              ref.invalidate(settingsProvider);
            },
          ),
        ],
      SettingsSection.duty => [
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
        ],
      SettingsSection.body => [
          ActionRow(
            label: 'طول الخطوة',
            value: toArabicDigits('${s.strideCm} سم'),
            action: 'غيّر',
            onTap: () async {
              final cm = await askStride(context, s.strideCm);
              if (cm == null) return;
              await controller.updateStrideCm(cm);
              ref.invalidate(settingsProvider);
            },
          ),
          SwitchRow(
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
          const SizedBox(height: 6),
          StepperRow(
            key: const ValueKey('phone-cap'),
            label: 'حد وقت الموبايل',
            value: toArabicDigits('${s.phoneCapMinutes} د'),
            onDecrement: () async {
              await controller.updatePhoneCap(s.phoneCapMinutes - 15);
              ref.invalidate(settingsProvider);
            },
            onIncrement: () async {
              await controller.updatePhoneCap(s.phoneCapMinutes + 15);
              ref.invalidate(settingsProvider);
            },
          ),
        ],
      SettingsSection.prayerTimes => [
          ActionRow(
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
          ChoiceRow(
            label: 'طريقة الحساب',
            value: _methods[s.calculationMethod] ?? s.calculationMethod,
            options: _methods,
            onSelected: (key) async {
              await controller.updateMethod(key);
              ref.invalidate(settingsProvider);
            },
          ),
          ChoiceRow(
            label: 'حساب العصر',
            value: s.madhab == 'hanafi' ? 'حنفي' : 'شافعي',
            options: const {'shafi': 'شافعي', 'hanafi': 'حنفي'},
            onSelected: (key) async {
              await controller.updateMadhab(key);
              ref.invalidate(settingsProvider);
            },
          ),
          StepperRow(
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
        ],
      // Named distinctly from the «الإقامة» notification switch, so the two
      // are never mistaken for each other.
      SettingsSection.iqamaOffsets => [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'الفرق بين الأذان والإقامة في جامعك. كل ضغطة خمس دقايق.',
              style: cairo(size: 11, color: NouriColors.muted, height: 1.7),
            ),
          ),
          for (final entry in decodeIqamaOffsets(s.iqamaOffsetsJson).entries)
            StepperRow(
              key: ValueKey('iqama-${entry.key}'),
              label: prayerLabel(entry.key),
              value: toArabicDigits('${entry.value} د'),
              // A step, not a target. Sending `entry.value ± 5` was only
              // correct while the row on screen was current, and it was not:
              // the previous tap held the old value there for the length of a
              // window re-arm, so the next tap wrote the same number again.
              // Four presses, one move.
              onDecrement: () async {
                await controller.stepIqamaOffset(entry.key, -5);
                ref.invalidate(settingsProvider);
              },
              onIncrement: () async {
                await controller.stepIqamaOffset(entry.key, 5);
                ref.invalidate(settingsProvider);
              },
            ),
        ],
      SettingsSection.wird => [
          StepperRow(
            key: const ValueKey('tasbeeh-target'),
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
          ValueRow(
            label: 'صفحات المصحف',
            value: toArabicDigits('${s.khatmaTotalPages}'),
          ),
        ],
      SettingsSection.sounds => [
          Text(
            'دوس «شغّل» عشان تسمع الصوت اللي هييجي في وقته بالظبط — '
            'نفس النغمة ونفس مستوى الصوت.',
            style: cairo(size: 11.5, color: NouriColors.muted, height: 1.8),
          ),
          const SizedBox(height: 4),
          const Divider(color: NouriColors.border, height: 22),
          Row(
            children: [
              Text('الأذان', style: cairo(size: 13, weight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('adhan-temporary-badge'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: NouriColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: NouriColors.border),
                ),
                child: Text('مؤقت',
                    style: cairo(size: 10, color: NouriColors.muted)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'التسجيلات دي مؤقتة لحد ما تبعت الخمسة اللي انت عايزها. '
            'اسمعهم وقول لو واحد فيهم مش مظبوط — وخصوصًا أذان الفجر، '
            'لازم يكون فيه «الصلاة خير من النوم».',
            key: const ValueKey('adhan-temporary-note'),
            style: cairo(size: 11, color: NouriColors.muted, height: 1.7),
          ),
          const SizedBox(height: 6),
          for (final prayer in adhanPrayers)
            _SoundRow(
              key: ValueKey('preview-adhan-$prayer'),
              label: prayerLabel(prayer),
              note: adhanCredits[prayer] ?? '',
              channelId: adhanChannelFor(prayer),
              title: 'نوري — ${prayerLabel(prayer)}',
              body: 'تجربة أذان ${prayerLabel(prayer)}',
            ),
          const Divider(color: NouriColors.border, height: 26),
          Text('تنبيهات المهام',
              style: cairo(size: 13, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            'كل مهمة ليها نغمة لوحدها، عشان تعرفها من صوتها من غير ما تبص.',
            style: cairo(size: 11, color: NouriColors.muted, height: 1.7),
          ),
          for (final kind in TaskAlertKind.values)
            _SoundRow(
              key: ValueKey('preview-${kind.name}'),
              label: kind.soundName,
              note: '',
              channelId: kind.channelId,
              title: kind.title,
              body: kind.body,
            ),
        ],
      SettingsSection.about => [
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
                  style: cairo(size: 12, color: NouriColors.muted, height: 1.7),
                ),
              ],
            ),
          ),
          const Divider(color: NouriColors.border, height: 26),
          // **Required, not a courtesy.** Four of the five adhan recordings
          // are CC BY or CC BY-SA, and both licences make attribution a
          // condition of use. Printing it here is what makes using them
          // legitimate.
          Text('الأذان', style: cairo(size: 13, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'تسجيلات الأذان من ويكيميديا كومنز، برخص حرة:',
            style: cairo(size: 11, color: NouriColors.muted, height: 1.7),
          ),
          const SizedBox(height: 6),
          for (final prayer in adhanPrayers)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${prayerLabel(prayer)} — ${adhanCredits[prayer]}',
                style: cairo(size: 10.5, color: NouriColors.muted),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'أصوات التنبيهات التانية من صنع نوري نفسه.',
            style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
          ),
        ],
    };

/// One audition row: what it is, who made it where that matters, and «شغّل».
///
/// A `ConsumerWidget` rather than an `ActionRow` with a callback because the
/// notification service is read at press time — reading it when the list is
/// built would capture whatever was there before `_ensureReady` had run.
class _SoundRow extends ConsumerWidget {
  const _SoundRow({
    super.key,
    required this.label,
    required this.note,
    required this.channelId,
    required this.title,
    required this.body,
  });

  final String label;

  /// The licence credit, on the adhans. Empty on the generated tones, which
  /// are Nouri's own.
  final String note;

  final String channelId;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: cairo(size: 13.5)),
                  if (note.isNotEmpty)
                    Text(note,
                        style: cairo(size: 10, color: NouriColors.muted)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => ref
                  .read(notificationServiceProvider)
                  ?.previewSound(channelId, title: title, body: body),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.play_arrow_rounded,
                  size: 18, color: NouriColors.gold),
              label: Text('شغّل',
                  style: cairo(size: 12.5, color: NouriColors.gold)),
            ),
          ],
        ),
      );
}
