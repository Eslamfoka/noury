// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'نوري';

  @override
  String get tabToday => 'النهاردة';

  @override
  String get tabAthkar => 'الأذكار';

  @override
  String get tabReports => 'التقارير';

  @override
  String get tabFinance => 'المالية';

  @override
  String get tabSettings => 'الإعدادات';

  @override
  String get labelNextPrayer => 'الصلاة القادمة';

  @override
  String get labelIqama => 'الإقامة';

  @override
  String get labelTodayPrayers => 'صلوات اليوم';

  @override
  String get labelDailyWird => 'الورد اليومي';

  @override
  String get labelMorningAthkar => 'أذكار الصباح';

  @override
  String get labelEveningAthkar => 'أذكار المساء';

  @override
  String get labelSleepAthkar => 'أذكار النوم';

  @override
  String get labelTasbeeh => 'التسبيح';

  @override
  String get labelQuranWird => 'ورد القرآن';

  @override
  String get labelSource => 'المصدر';

  @override
  String get labelVirtue => 'الفضل';

  @override
  String get stateMosque => 'في المسجد';

  @override
  String get stateCongregation => 'جماعة';

  @override
  String get stateOnTime => 'في الوقت';

  @override
  String get stateLate => 'متأخرة';

  @override
  String get stateNotYet => 'لسه';

  @override
  String get prayerFajr => 'الفجر';

  @override
  String get prayerDhuhr => 'الظهر';

  @override
  String get prayerAsr => 'العصر';

  @override
  String get prayerMaghrib => 'المغرب';

  @override
  String get prayerIsha => 'العشاء';

  @override
  String get nouriRemainingOnAdhan => 'باقي على الأذان';

  @override
  String get nouriPrayedAction => 'صليت';

  @override
  String get nouriComingSoon => 'قريباً إن شاء الله';

  @override
  String get nouriFinancePlaceholder =>
      'الجزء ده لسه في الطريق. لما يجهز هتلاقي هنا مصاريفك وميزانيتك.';

  @override
  String get nouriTargetAdjustable => 'تقدر تزوّده';

  @override
  String nouriDidYouPray(String prayer) {
    return 'صليت $prayer؟';
  }

  @override
  String nouriProgress(String done, String total) {
    return 'خلّصت $done من $total';
  }
}
