import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../home/home_providers.dart';
import '../shared/nouri_avatar.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// The seven parts of الإعدادات, each its own page.
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
        ],
    };
