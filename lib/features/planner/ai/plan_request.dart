import '../../../data/db/nouri_database.dart';

/// What Nouri sends to Claude when the user presses «ابني خطتي».
///
/// **An aggregate, never rows.** The brief is explicit and it is a privacy
/// boundary rather than a cost optimisation: *"Send aggregated summaries only —
/// never raw meals/expenses/personal detail."* Claude is being asked to place
/// time; a meal's symptom, an expense's amount and a prayer's state are none of
/// them time, and none of them leaves the device.
///
/// `plan_request_test` asserts that directly — it writes a row into every
/// logging table, builds a request, and fails if any of those values appear in
/// the payload. That test is the promise; this comment is only its explanation.
///
/// The one thing that *is* sent freely is the profile, including the fields the
/// user added himself. That is the whole point of the feature: he wrote them so
/// that a plan could be built from them.
class PlanRequest {
  const PlanRequest({
    required this.profile,
    required this.customFields,
    required this.days,
    required this.shiftType,
    required this.prayerTimesByDay,
    required this.targetSleepHours,
    required this.eatingWindowStartHour,
    required this.eatingWindowHours,
    required this.waterTargetGlasses,
  });

  final ProfileRow profile;
  final List<ProfileFieldRow> customFields;

  /// The days to plan, midnight local, ascending.
  final List<DateTime> days;

  final String shiftType;

  /// `{date: {prayer: 'HH:mm'}}` — the fixed anchors every day is built round.
  final Map<DateTime, Map<String, String>> prayerTimesByDay;

  final double targetSleepHours;
  final int eatingWindowStartHour;
  final int eatingWindowHours;
  final int waterTargetGlasses;

  /// How Nouri describes itself to Claude.
  ///
  /// The voice rules are not decoration. §1 of the brief forbids guilt, forbids
  /// red, and asks for a calm direct register; a plan that came back scolding
  /// would be worse than no plan, because the user would stop opening the app.
  static const systemPrompt = '''
أنت «نوري» — رفيق يومي بيساعد المستخدم ينظّم يومه.
مهمتك: تبني خطة يوم واقعية من البيانات اللي جاية، وترجّعها JSON بس.

قواعد لازمة:
- الصلاة والنوم ثابتين. متحركش وقت صلاة، ومتقصّرش النوم عشان تزوّد مهام.
- لو اليوم مزحوم، أجّل الأخف — النوم آخر حاجة تتمس.
- المهام التقيلة (تمرين، قراءة كتاب) في البيت أو وقت فاضي حقيقي.
  المهام الخفيفة (أذكار، تسبيح، سماع محاضرة) تنفع في المواصلات أو بريك الشغل.
- متلومش المستخدم، ومتفترضش إنه فشل في حاجة. النبرة هادية ومباشرة.
- متخترعش مهام مالهاش معرّف من اللستة اللي اتبعتت لك.

رجّع JSON بالشكل ده بالظبط، من غير أي كلام قبله أو بعده:
{"days":[{"date":"YYYY-MM-DD","tasks":[{"id":"<من اللستة>","at":"HH:mm","minutes":<رقم>}]}],
 "books":[{"title":"<اسم الكتاب>","why":"<سطر واحد ليه ده يناسبه>"}],
 "note":"<سطرين على الأكثر، بصوت نوري>"}
''';

  /// The compact Arabic summary that becomes the user message.
  ///
  /// Arabic rather than English because the plan comes back in Arabic and the
  /// app is Arabic; a round trip through English would be one more place for
  /// «أذكار المساء» to come back as "evening remembrances".
  String toPrompt({required List<String> allowedTaskIds}) {
    final b = StringBuffer();

    b.writeln('# مين المستخدم');
    _line(b, 'الاسم', profile.name);
    _line(b, 'النوع', profile.gender);
    final age = _age();
    if (age != null) _line(b, 'السن', '$age سنة');
    _line(b, 'شغل ولا دراسة', _occupationLabel(profile.occupation));
    // The length of a shift, which is what decides how much of a day is left
    // once duty is taken out. The *type* goes in the الثوابت block below,
    // because it comes from settings rather than from the profile.
    _line(b, 'ساعات الوردية', profile.dutyHours == null
        ? null
        : '${profile.dutyHours} ساعة');
    _line(b, 'شغل تاني', profile.secondJob);
    _line(b, 'المرحلة الدراسية', profile.studyStage);
    _line(b, 'محاضرات في الأسبوع', profile.weeklyLectures?.toString());
    _line(b, 'دروس خصوصية في الأسبوع',
        profile.weeklyPrivateLessons?.toString());
    _line(b, 'الأكل والشرب', profile.eatingNotes);
    _line(b, 'النوم', profile.sleepNotes);
    _line(b, 'اهتماماته', profile.interests);

    if (customFields.isNotEmpty) {
      b.writeln();
      b.writeln('# حاجات المستخدم كتبها بنفسه');
      // Passed through verbatim. Reading an arbitrary sentence is what the
      // model is for; a keyword matcher here would be a worse version of it.
      for (final f in customFields) {
        b.writeln('- ${f.label}: ${f.value}');
      }
    }

    b.writeln();
    b.writeln('# الثوابت');
    _line(b, 'الدوام', _shiftLabel(shiftType));
    _line(b, 'النوم المطلوب', '$targetSleepHours ساعة');
    _line(b, 'نافذة الأكل',
        'من الساعة $eatingWindowStartHour لمدة $eatingWindowHours ساعة');
    _line(b, 'هدف المياه', '$waterTargetGlasses كوب');

    b.writeln();
    b.writeln('# الأيام ومواقيت الصلاة');
    for (final day in days) {
      final times = prayerTimesByDay[day];
      if (times == null) continue;
      final parts = times.entries.map((e) => '${e.key} ${e.value}').join(' · ');
      b.writeln('- ${_iso(day)}: $parts');
    }

    b.writeln();
    b.writeln('# المهام المسموح بيها (استخدم المعرّفات دي بس)');
    b.writeln(allowedTaskIds.join(', '));

    return b.toString();
  }

  int? _age() {
    final born = profile.birthDate;
    if (born == null) return null;
    final now = DateTime.now();
    // Constructed, never offset — the rule this project keeps re-learning.
    var years = now.year - born.year;
    final hadBirthday = now.month > born.month ||
        (now.month == born.month && now.day >= born.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? null : years;
  }

  static void _line(StringBuffer b, String label, String? value) {
    // Absent rather than «غير معروف»: a half-filled profile should read as a
    // shorter brief, not as a list of the user's omissions.
    if (value == null || value.trim().isEmpty) return;
    b.writeln('- $label: ${value.trim()}');
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String? _occupationLabel(String? occupation) => switch (occupation) {
        'employee' => 'موظف',
        'student' => 'طالب',
        'both' => 'موظف وطالب',
        _ => null,
      };

  static String _shiftLabel(String shift) => switch (shift) {
        'evening' => 'مسائي (٢ الضهر لحد ٩ بالليل)',
        'night' => 'ليلي (١٠ بالليل لحد ٧ الصبح)',
        'off' => 'إجازة',
        _ => 'صباحي (٧ الصبح لحد ٢ الضهر)',
      };
}
