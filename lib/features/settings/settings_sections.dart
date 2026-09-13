import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../app.dart';
import '../../core/notifications/adhan_sounds.dart';
import '../../core/notifications/task_alert.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import '../ai/ai_connection_panel.dart';
import '../home/home_providers.dart';
import '../planner/shift.dart';
import '../planner/shift_settings.dart';
import '../shared/nouri_avatar.dart';
import 'settings_controller.dart';
import 'settings_widgets.dart';

/// The nine parts of الإعدادات, each its own page.
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
  ai('الذكاء الاصطناعي', Icons.auto_awesome),
  sounds('الأصوات', Icons.graphic_eq),
  about('عن نوري', Icons.info_outline);

  const SettingsSection(this.title, this.icon);

  final String title;
  final IconData icon;

  /// One line under the title on the index, so a row says what is inside it
  /// rather than making the user open it to find out.
  String get summary => switch (this) {
        SettingsSection.notifications =>
          'الأذان، الإقامة، الأذكار، فكّرني تاني، الصامت وقت الصلاة',
        SettingsSection.duty => 'ورديتك دلوقتي، ساعاتها، والمواصلات',
        SettingsSection.body => 'طول الخطوة والمشي',
        SettingsSection.prayerTimes => 'المدينة، طريقة الحساب، التاريخ الهجري',
        SettingsSection.iqamaOffsets => 'كام دقيقة بين الأذان والإقامة',
        SettingsSection.wird => 'هدف التسبيح وصفحات المصحف',
        SettingsSection.ai => 'مفتاح API بتاعك، وزرار CONNECT',
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
          // «فكّرني تاني» — 13 September 2026: «لو مش عملته تفضل تذكرني كل
          // فترة مثلا كل ٥ دقايق او ١٠ دقايق زي ما انا اختار». Chips rather
          // than a stepper: five choices, and «بلاش» has to be one of them.
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text('فكّرني تاني لو معملتهاش',
                style: cairo(size: 13, weight: FontWeight.w600)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                0: 'بلاش',
                5: 'كل ٥ د',
                10: 'كل ١٠ د',
                15: 'كل ١٥ د',
                30: 'كل ٣٠ د',
              }.entries)
                _Chip(
                  key: ValueKey('nag-${entry.key}'),
                  label: entry.value,
                  selected: s.nagIntervalMinutes == entry.key,
                  onTap: () async {
                    await controller.updateNagInterval(entry.key);
                    ref.invalidate(settingsProvider);
                  },
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 2, bottom: 4),
            child: Text(
              'بعد تنبيه المهمة، لو ما اتسجّلتش، نوري بيسأل تاني كل الفترة دي '
              'لحد ما تيجي المهمة اللي بعدها — ولما تيجي بيقول لك إن اللي '
              'قبلها فاتتك. الخمس دقايق بتشتغل والموبايل صاحي؛ وهو نايم في '
              'الجيب أندرويد مش بيصحّي التطبيق أكتر من مرة كل ٩ دقايق.',
              style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
            ),
          ),
          // «الصامت وقت الصلاة» — same day: «من الاذان للأقامة ومثلا ١٠
          // دقايق صلاه وبعدين يرجع تاني عام». Needs the same policy access
          // the adhan's DND bypass needs; the panel on the index has the row.
          SwitchRow(
            key: const ValueKey('silence-during-prayer'),
            label: 'الصامت وقت الصلاة',
            value: s.silenceDuringPrayer,
            onChanged: (v) async {
              await controller.setSilenceDuringPrayer(v);
              ref.invalidate(settingsProvider);
            },
          ),
          StepperRow(
            key: const ValueKey('prayer-silence-minutes'),
            label: 'مدة الصلاة بعد الإقامة',
            value: toArabicDigits('${s.prayerSilenceMinutes} د'),
            onDecrement: () async {
              await controller
                  .updatePrayerSilenceMinutes(s.prayerSilenceMinutes - 5);
              ref.invalidate(settingsProvider);
            },
            onIncrement: () async {
              await controller
                  .updatePrayerSilenceMinutes(s.prayerSilenceMinutes + 5);
              ref.invalidate(settingsProvider);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 2, bottom: 4),
            child: Text(
              'من الأذان لحد الإقامة زائد المدة دي، الموبايل بيبقى على '
              '«المنبّهات بس»: المكالمات والإشعارات ساكتة، والأذان والإقامة '
              'والتنبيهات بتوصل. وبعدها يرجع عادي. محتاج إذن «عدم الإزعاج» '
              'من أول الصفحة، ولو الموبايل أصلًا على عدم الإزعاج نوري '
              'مش بيلمسه.',
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
          // The hours and the commute, 13 September 2026: «عايز اختار وقت
          // الدوام بيبدأ امتا وينتهي امتا مثلا الصبح من 7 am الي 2 pm وتحط
          // ساعتين مواصلات ساعة قبل الدوام وساعة بعد». Shown for the type
          // that is selected; each type keeps its own hours.
          if (shiftTypeOf(s.shiftType) != ShiftType.off) ...[
            const SizedBox(height: 14),
            Text('ساعات ${shiftTypeOf(s.shiftType).arabicLabel}',
                style: cairo(size: 13, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            _ShiftHourRow(
              key: const ValueKey('shift-start'),
              label: 'بداية الدوام',
              value: ShiftHours.decode(s.shiftHoursJson)[shiftTypeOf(s.shiftType)]!.start,
              onPicked: (picked) async {
                final hours = ShiftHours.decode(s.shiftHoursJson)[shiftTypeOf(s.shiftType)]!;
                await controller.updateShiftHours(
                  shiftTypeOf(s.shiftType),
                  start: picked,
                  end: hours.end,
                );
                ref.invalidate(settingsProvider);
              },
            ),
            _ShiftHourRow(
              key: const ValueKey('shift-end'),
              label: 'نهاية الدوام',
              value: ShiftHours.decode(s.shiftHoursJson)[shiftTypeOf(s.shiftType)]!.end,
              onPicked: (picked) async {
                final hours = ShiftHours.decode(s.shiftHoursJson)[shiftTypeOf(s.shiftType)]!;
                await controller.updateShiftHours(
                  shiftTypeOf(s.shiftType),
                  start: hours.start,
                  end: picked,
                );
                ref.invalidate(settingsProvider);
              },
            ),
            StepperRow(
              key: const ValueKey('commute-before'),
              label: 'مواصلات قبل الدوام',
              value: toArabicDigits('${s.commuteBeforeMinutes} د'),
              onDecrement: () async {
                await controller.updateCommute(
                    beforeMinutes: s.commuteBeforeMinutes - 15);
                ref.invalidate(settingsProvider);
              },
              onIncrement: () async {
                await controller.updateCommute(
                    beforeMinutes: s.commuteBeforeMinutes + 15);
                ref.invalidate(settingsProvider);
              },
            ),
            StepperRow(
              key: const ValueKey('commute-after'),
              label: 'مواصلات بعد الدوام',
              value: toArabicDigits('${s.commuteAfterMinutes} د'),
              onDecrement: () async {
                await controller.updateCommute(
                    afterMinutes: s.commuteAfterMinutes - 15);
                ref.invalidate(settingsProvider);
              },
              onIncrement: () async {
                await controller.updateCommute(
                    afterMinutes: s.commuteAfterMinutes + 15);
                ref.invalidate(settingsProvider);
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 2),
              child: Text(
                _dutyLine(s),
                key: const ValueKey('duty-summary'),
                style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
              ),
            ),
          ],
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
      // The ninth section, added 13 September 2026. Its whole body is one
      // widget of its own, because unlike every other section it holds
      // state — a key being typed, a request in flight, a list that came
      // back — and a stateless builder over a settings row cannot.
      SettingsSection.ai => [AiConnectionPanel(settings: s)],
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
            'كل مهمة ليها نغمة لوحدها، عشان تعرفها من صوتها من غير ما تبص. '
            'اللي مكتوب تحتها «تسجيلك» هي اللي انت بعتّها.',
            style: cairo(size: 11, color: NouriColors.muted, height: 1.7),
          ),
          for (final kind in TaskAlertKind.values)
            _SoundRow(
              key: ValueKey('preview-${kind.name}'),
              label: kind.soundName,
              // Says whose it is. Eleven are his own recordings since 13
              // September 2026; the rest are still Nouri's, and a row that
              // did not say which would leave him auditioning a tone to find
              // out whether it was the one he sent.
              note: kind.recorded ? 'تسجيلك' : '',
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
            'أصوات التنبيهات: إحدى عشر منها تسجيلات اخترتها انت، والباقي من '
            'صنع نوري نفسه.',
            style: cairo(size: 10.5, color: NouriColors.muted, height: 1.7),
          ),
        ],
    };

/// A selectable chip, in the shape the shift picker already uses.
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? NouriColors.gold : NouriColors.surfaceActive,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: NouriColors.border),
          ),
          child: Text(
            label,
            style: cairo(
              size: 12.5,
              weight: selected ? FontWeight.w700 : FontWeight.w400,
              color: selected ? NouriColors.background : NouriColors.text,
            ),
          ),
        ),
      );
}

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

  /// The licence credit on the adhans, «تسجيلك» on the tones the user
  /// recorded himself, empty on the ones Nouri synthesised.
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


/// «من ٦ لـ ٣»: the whole span the shift takes out of the day, in one line,
/// so the user sees what the plan will treat as locked before he leaves the
/// page.
String _dutyLine(SettingsRow s) {
  final pattern = shiftPatternFromSettings(s);
  final leave = pattern.leaveHome;
  final home = pattern.homeAgain;
  if (pattern.workStart == null || pattern.workEnd == null) return '';
  final span = leave != null && home != null
      ? 'من ${_hhmm(leave)} لحد ${_hhmm(home)} بالمواصلات'
      : 'من ${_hhmm(pattern.workStart!)} لحد ${_hhmm(pattern.workEnd!)}';
  return toArabicDigits(
    'اليوم بيتخطّط حوالين ده: $span — الخطة والتنبيهات مش بتحط حاجة تقيلة '
    'فيهم، والنوم بيتحسب من ميعاد الصحيان اللي بعده.',
  );
}

String _hhmm(Clock c) => c.toString();

/// One row that opens the system time picker.
class _ShiftHourRow extends StatelessWidget {
  const _ShiftHourRow({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
  });

  final String label;
  final Clock value;
  final Future<void> Function(Clock) onPicked;

  @override
  Widget build(BuildContext context) => ActionRow(
        label: label,
        value: toArabicDigits(value.toString()),
        action: 'غيّر',
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
            helpText: label,
          );
          if (picked == null) return;
          await onPicked(Clock(picked.hour, picked.minute));
        },
      );
}
