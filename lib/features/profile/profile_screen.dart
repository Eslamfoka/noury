import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/arabic_numerals.dart';
import '../../core/theme/nouri_colors.dart';
import '../../core/theme/nouri_theme.dart';
import '../../data/db/nouri_database.dart';
import 'build_plan_button.dart';
import 'custom_fields_section.dart';
import 'profile_photo.dart';
import 'profile_providers.dart';

/// الملف الشخصي — who Nouri is planning for.
///
/// From two screenshots the user wrote by hand: *«عايز ف البرنامج حاجة زي كده
/// بروفايل داش بورد من خلالها البرنامج يقدر يجمع المعلومات ويبعتها لل ai عشان
/// النتيجة تبقى خطة خاصة مش حاجة fixed للناس كلها»*.
///
/// **Every field says what it changes.** He asked for this in as many words —
/// *«ولو ف شرح مثلا المعلومة مثلا طالب ولا موظف تبقى مكتوبة عشان المستخدم
/// يفهم»* — and it is the honest thing besides. He is handing over his life in
/// a form; he is owed a plain statement of what each answer does. «طالب ولا
/// موظف» is not a demographic question here, it is the question that decides
/// whether his day is built around lectures or around shifts.
///
/// **Nothing is required.** Every field is nullable, the button works on an
/// empty profile, and no control is ever marked missing or wrong. A form that
/// has to be completed before the app is useful would be the exact stress
/// Nouri exists to remove.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final custom = ref.watch(profileCustomFieldsProvider);

    return Scaffold(
      backgroundColor: NouriColors.background,
      appBar: AppBar(
        backgroundColor: NouriColors.background,
        elevation: 0,
        title: Text('الملف الشخصي',
            style: cairo(size: 16, weight: FontWeight.w700)),
      ),
      body: profile.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: NouriColors.gold),
        ),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Text('مش قادر أقرا الملف دلوقتي.',
                style: cairo(size: 13, color: NouriColors.muted)),
          ),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.fromLTRB(15, 8, 15, 28),
          children: [
            _Intro(),
            const SizedBox(height: 16),
            _PhotoSlot(path: p.photoPath),
            const SizedBox(height: 18),

            _Group('مين انت', [
              _TextRow(
                label: 'الاسم',
                explain: 'نوري بينده عليك بيه.',
                value: p.name,
                onSave: (v) => _save(ref, ProfileRowsCompanion(name: Value(v))),
              ),
              _TextRow(
                label: 'النوع',
                explain: 'بيدخل في نبرة الكلام، ومش بيتبعت لحد.',
                value: p.gender,
                onSave: (v) =>
                    _save(ref, ProfileRowsCompanion(gender: Value(v))),
              ),
              _DateRow(
                label: 'تاريخ الميلاد',
                explain: 'السن بيغيّر النوم اللي جسمك محتاجه، والمجهود '
                    'اللي يناسبك.',
                value: p.birthDate,
                onSave: (v) =>
                    _save(ref, ProfileRowsCompanion(birthDate: Value(v))),
              ),
            ]),

            _Group('شغل ولا دراسة', [
              _ChoiceRow(
                label: 'انت إيه دلوقتي',
                explain: 'ده أهم سؤال هنا. لو موظف، يومك هيتبني حوالين '
                    'الورديات. لو طالب، هيتبني حوالين المحاضرات. لو '
                    'الاتنين، نوري هيحسب الوقت اللي فاضل بعدهم.',
                value: p.occupation,
                options: const {
                  'employee': 'موظف',
                  'student': 'طالب',
                  'both': 'الاتنين',
                },
                onSave: (v) =>
                    _save(ref, ProfileRowsCompanion(occupation: Value(v))),
              ),
              if (p.occupation == 'employee' || p.occupation == 'both') ...[
                _HoursRow(
                  value: p.dutyHours,
                  onSave: (v) =>
                      _save(ref, ProfileRowsCompanion(dutyHours: Value(v))),
                ),
                _TextRow(
                  label: 'شغل تاني',
                  explain: 'لو فيه شغل تاني، ساعاته بتتخصم من نفس اليوم — '
                      'فنوري لازم يعرفها قبل ما يوزّع.',
                  value: p.secondJob,
                  onSave: (v) =>
                      _save(ref, ProfileRowsCompanion(secondJob: Value(v))),
                ),
              ],
              if (p.occupation == 'student' || p.occupation == 'both') ...[
                _TextRow(
                  label: 'المرحلة الدراسية',
                  explain: 'اكتبها بكلامك — «تانية ثانوي»، «سنة تالتة '
                      'هندسة». بتفرق في شكل اليوم.',
                  value: p.studyStage,
                  onSave: (v) =>
                      _save(ref, ProfileRowsCompanion(studyStage: Value(v))),
                ),
                _NumberRow(
                  label: 'محاضرات في الأسبوع',
                  explain: 'عدد الحصص أو المحاضرات، عشان نوري يعرف الوقت '
                      'المحجوز قد إيه.',
                  value: p.weeklyLectures,
                  onSave: (v) => _save(
                      ref, ProfileRowsCompanion(weeklyLectures: Value(v))),
                ),
                _NumberRow(
                  label: 'دروس خصوصية في الأسبوع',
                  explain: 'محسوبة لوحدها عن المحاضرات، لأنها بتيجي في '
                      'أوقات تانية من اليوم.',
                  value: p.weeklyPrivateLessons,
                  onSave: (v) => _save(ref,
                      ProfileRowsCompanion(weeklyPrivateLessons: Value(v))),
                ),
              ],
            ]),

            _Group('نظامك', [
              _TextRow(
                label: 'الأكل والشرب',
                explain: 'بكلامك. نوري عارف نافذة الصيام وهدف المياه من '
                    'الإعدادات — ده المكان اللي تقول فيه الباقي، زي «بصوم '
                    'الاتنين والخميس».',
                value: p.eatingNotes,
                multiline: true,
                onSave: (v) =>
                    _save(ref, ProfileRowsCompanion(eatingNotes: Value(v))),
              ),
              _TextRow(
                label: 'النوم',
                explain: 'أي حاجة نوري لازم يعرفها عن نومك — «مبعرفش أنام '
                    'قبل الفجر»، «بنام ساعتين بالنهار».',
                value: p.sleepNotes,
                multiline: true,
                onSave: (v) =>
                    _save(ref, ProfileRowsCompanion(sleepNotes: Value(v))),
              ),
              _TextRow(
                label: 'اهتماماتك',
                explain: 'دي اللي الكتب هتترشّح على أساسها. اكتب المواضيع '
                    'اللي تحب تقرا فيها.',
                value: p.interests,
                multiline: true,
                onSave: (v) =>
                    _save(ref, ProfileRowsCompanion(interests: Value(v))),
              ),
            ]),

            CustomFieldsSection(fields: custom.value ?? const []),

            const SizedBox(height: 26),
            const BuildPlanButton(),
            const SizedBox(height: 14),
            Text(
              'نوري بيبعت الملخّص ده بس — مفيش أي حاجة من اللي بتسجّله '
              'يوميًا بتطلع من الجهاز: لا وجباتك، ولا مصاريفك، ولا صلواتك، '
              'ولا وزنك.',
              key: const ValueKey('profile-privacy-note'),
              textAlign: TextAlign.center,
              style: cairo(size: 11, color: NouriColors.muted, height: 1.8),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _save(WidgetRef ref, ProfileRowsCompanion patch) async {
    await ref.read(profileDaoProvider).update(patch);
    // The occupation field changes which other fields exist, so the screen
    // has to be told rather than left holding the answer it read on the way in.
    ref.invalidate(profileProvider);
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NouriColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'كل ما نوري يعرف عنك أكتر، الخطة تطلع أقرب ليك. مش لازم تملا '
          'كل حاجة — املا اللي تحبه دلوقتي، وزوّد بعدين.',
          style: cairo(size: 12, color: NouriColors.muted, height: 1.9),
        ),
      );
}

/// The photo the user asked for — *«ممكن كمان ازود صورة شخصية»*.
///
/// **The one field whose honest answer is "nothing".** Every other row on this
/// screen says what it changes, because the user is handing over his life in a
/// form and is owed that. This one changes no plan, is not in the payload sent
/// to Claude, and never leaves the phone. Saying so is better than letting a
/// screen full of "this shapes your plan" imply that the picture does too.
///
/// A missing file draws the empty circle rather than a broken box. The path is
/// in the database and the file is on disk, and the two can part company —
/// cleared app storage, a restore onto another phone — so the widget treats
/// the file as the truth and the row as a hint.
class _PhotoSlot extends ConsumerWidget {
  const _PhotoSlot({this.path});
  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `existsSync` rather than leaning on `Image.file`'s `errorBuilder`.
    //
    // The builder does fire for a missing file, but only after the decode has
    // been attempted and failed — so the user gets an empty circle first and
    // the placeholder a moment later. One `stat` on one path, on a screen that
    // does not scroll a list, is cheaper than that flicker. The `errorBuilder`
    // stays as the second line: a file can exist and still be unreadable.
    final stored = path == null ? null : File(path!);
    final file = (stored != null && stored.existsSync()) ? stored : null;

    return Row(
      children: [
        InkWell(
          key: const ValueKey('profile-photo'),
          customBorder: const CircleBorder(),
          onTap: () async {
            final stored = await ref.read(photoChooserProvider)();
            if (stored == null) return;
            await ProfileScreen._save(
                ref, ProfileRowsCompanion(photoPath: Value(stored)));
          },
          child: Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: NouriColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: NouriColors.border),
            ),
            child: file == null
                ? const Icon(Icons.person_outline,
                    color: NouriColors.muted, size: 30)
                : Image.file(
                    file,
                    fit: BoxFit.cover,
                    // The row said there was a photo and there is not. Draw
                    // the empty circle: an app that shows a broken image is
                    // telling the user something is wrong with *them*.
                    errorBuilder: (_, _, _) => const Icon(
                        Icons.person_outline,
                        color: NouriColors.muted,
                        size: 30),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            file == null
                ? 'دوس عشان تحط صورتك. مش بتروح لحد ومش بتغيّر الخطة — '
                    'دي ليك انت.'
                : 'الصورة محفوظة على تليفونك بس.',
            key: const ValueKey('profile-photo-explain'),
            style: cairo(size: 11.5, color: NouriColors.muted, height: 1.7),
          ),
        ),
        if (file != null)
          IconButton(
            key: const ValueKey('profile-photo-clear'),
            tooltip: 'شيل الصورة',
            icon: const Icon(Icons.close, size: 18, color: NouriColors.muted),
            onPressed: () async {
              await ref.read(photoRemoverProvider)();
              await ProfileScreen._save(
                  ref, const ProfileRowsCompanion(photoPath: Value(null)));
            },
          ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 2),
              child: Text(title,
                  style: cairo(size: 13, weight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: NouriColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(children: children),
            ),
          ],
        ),
      );
}

/// A label, the explanation of what it changes, and the value.
class _FieldFrame extends StatelessWidget {
  const _FieldFrame({
    required this.label,
    required this.explain,
    required this.child,
  });

  final String label;
  final String explain;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: cairo(size: 13.5)),
            const SizedBox(height: 3),
            Text(explain,
                style:
                    cairo(size: 10.5, color: NouriColors.muted, height: 1.7)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _TextRow extends StatefulWidget {
  const _TextRow({
    required this.label,
    required this.explain,
    required this.value,
    required this.onSave,
    this.multiline = false,
  });

  final String label;
  final String explain;
  final String? value;
  final bool multiline;
  final ValueChanged<String?> onSave;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  late final _controller = TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FieldFrame(
        label: widget.label,
        explain: widget.explain,
        child: TextField(
          key: ValueKey('profile-field-${widget.label}'),
          controller: _controller,
          maxLines: widget.multiline ? 3 : 1,
          minLines: 1,
          style: cairo(size: 13),
          decoration: _fieldDecoration(),
          // Saved on losing focus rather than on every keystroke: a write per
          // character would be a write per character.
          onTapOutside: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
            _commit();
          },
          onSubmitted: (_) => _commit(),
        ),
      );

  void _commit() {
    final text = _controller.text.trim();
    widget.onSave(text.isEmpty ? null : text);
  }
}

class _NumberRow extends StatefulWidget {
  const _NumberRow({
    required this.label,
    required this.explain,
    required this.value,
    required this.onSave,
  });

  final String label;
  final String explain;
  final int? value;
  final ValueChanged<int?> onSave;

  @override
  State<_NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<_NumberRow> {
  late final _controller =
      TextEditingController(text: widget.value?.toString() ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FieldFrame(
        label: widget.label,
        explain: widget.explain,
        child: TextField(
          key: ValueKey('profile-field-${widget.label}'),
          controller: _controller,
          keyboardType: TextInputType.number,
          style: cairo(size: 13),
          decoration: _fieldDecoration(),
          onTapOutside: (_) {
            FocusManager.instance.primaryFocus?.unfocus();
            widget.onSave(int.tryParse(_controller.text.trim()));
          },
          onSubmitted: (v) => widget.onSave(int.tryParse(v.trim())),
        ),
      );
}

/// «ساعات الوردية» — how long one shift runs.
///
/// The other half of what the user asked for: *«نوع دوامك ايه وعدد ساعاتك
/// دوامك ايه»*. The **type** already lives in الإعدادات → الدوام and is not
/// duplicated here — one setting, one place. This is the **length**, which
/// nothing in Nouri knew, and it is what decides how much of a day is left
/// once duty is taken out.
///
/// Chips for the four common answers he named, and a free field beside them,
/// because his own shifts are seven and nine hours and a closed list would
/// have had no room for the person it was built for.
class _HoursRow extends StatefulWidget {
  const _HoursRow({required this.value, required this.onSave});

  final int? value;
  final ValueChanged<int?> onSave;

  @override
  State<_HoursRow> createState() => _HoursRowState();
}

class _HoursRowState extends State<_HoursRow> {
  static const _common = [8, 12, 16, 24];

  late final TextEditingController _controller = TextEditingController(
    text: _isCommon(widget.value) ? '' : (widget.value?.toString() ?? ''),
  );

  static bool _isCommon(int? v) => v != null && _common.contains(v);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _FieldFrame(
        label: 'ساعات الوردية',
        explain: 'الوردية الواحدة بتاخد كام ساعة. ده اللي بيحدّد الوقت '
            'اللي فاضل في يومك بعد الشغل.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final h in _common)
                  ChoiceChip(
                    key: ValueKey('duty-hours-$h'),
                    label: Text(toArabicDigits('$h'), style: cairo(size: 12)),
                    selected: widget.value == h,
                    showCheckmark: false,
                    backgroundColor: NouriColors.background,
                    selectedColor: NouriColors.surfaceActive,
                    side: BorderSide(
                      color: widget.value == h
                          ? NouriColors.gold
                          : NouriColors.border,
                    ),
                    // Tapping the chosen one clears it, as everywhere else on
                    // this screen — an answer given by mistake must be
                    // reversible without wiping the profile.
                    onSelected: (on) {
                      if (on) _controller.clear();
                      widget.onSave(on ? h : null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('duty-hours-other'),
              controller: _controller,
              keyboardType: TextInputType.number,
              style: cairo(size: 13),
              decoration: _fieldDecoration()
                  .copyWith(hintText: 'أو اكتب عدد تاني — ٧، ٩…'),
              onTapOutside: (_) {
                FocusManager.instance.primaryFocus?.unfocus();
                _commitOther();
              },
              onSubmitted: (_) => _commitOther(),
            ),
          ],
        ),
      );

  void _commitOther() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final parsed = int.tryParse(text);
    // Silently ignored rather than shown as an error: a stray character in a
    // field nobody is required to fill is not worth a red line.
    if (parsed == null || parsed <= 0 || parsed > 24) return;
    widget.onSave(parsed);
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.explain,
    required this.value,
    required this.options,
    required this.onSave,
  });

  final String label;
  final String explain;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onSave;

  @override
  Widget build(BuildContext context) => _FieldFrame(
        label: label,
        explain: explain,
        child: Wrap(
          spacing: 8,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                key: ValueKey('profile-choice-${entry.key}'),
                label: Text(entry.value, style: cairo(size: 12)),
                selected: value == entry.key,
                showCheckmark: false,
                backgroundColor: NouriColors.background,
                selectedColor: NouriColors.surfaceActive,
                side: BorderSide(
                  color: value == entry.key
                      ? NouriColors.gold
                      : NouriColors.border,
                ),
                // Tapping the selected chip clears it: a question answered by
                // mistake must be un-answerable without wiping the profile.
                onSelected: (on) => onSave(on ? entry.key : null),
              ),
          ],
        ),
      );
}

/// A date, with a way back out of it.
///
/// **The clear button is not a nicety.** A picker has no "none", so before it
/// existed a date could only ever be *replaced* — and a date set by accident
/// was therefore permanent. That is not hypothetical: on 9 September 2026 a
/// stray gesture on the real phone opened this picker and confirmed its own
/// default, writing 2001/1/1 into the profile with no way to take it back.
///
/// It matters more than a wrong string would, because the age computed from
/// this is sent to Claude and shapes what it says about sleep and effort. A
/// wrong birth date is a wrong plan, quietly.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.explain,
    required this.value,
    required this.onSave,
  });

  final String label;
  final String explain;
  final DateTime? value;
  final ValueChanged<DateTime?> onSave;

  @override
  Widget build(BuildContext context) => _FieldFrame(
        label: label,
        explain: explain,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: const ValueKey('profile-birthdate'),
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value ?? DateTime(now.year - 25, 1, 1),
                    firstDate: DateTime(now.year - 90, 1, 1),
                    lastDate: now,
                  );
                  if (picked != null) onSave(picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: NouriColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: NouriColors.border),
                  ),
                  child: Text(
                    value == null
                        ? 'اختار التاريخ'
                        : '${value!.year}/${value!.month}/${value!.day}',
                    style: cairo(
                      size: 13,
                      color:
                          value == null ? NouriColors.muted : NouriColors.text,
                    ),
                  ),
                ),
              ),
            ),
            if (value != null)
              IconButton(
                key: const ValueKey('profile-birthdate-clear'),
                tooltip: 'امسح التاريخ',
                icon: const Icon(Icons.close,
                    size: 18, color: NouriColors.muted),
                onPressed: () => onSave(null),
              ),
          ],
        ),
      );
}

InputDecoration _fieldDecoration() => InputDecoration(
      isDense: true,
      filled: true,
      fillColor: NouriColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NouriColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NouriColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: NouriColors.gold),
      ),
    );
