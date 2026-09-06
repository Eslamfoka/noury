// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nouri';

  @override
  String get tabToday => 'Today';

  @override
  String get tabAthkar => 'Athkar';

  @override
  String get tabReports => 'Reports';

  @override
  String get tabFinance => 'Finance';

  @override
  String get tabBody => 'Body';

  @override
  String get tabSettings => 'Settings';

  @override
  String get labelNextPrayer => 'Next prayer';

  @override
  String get labelIqama => 'Iqama';

  @override
  String get labelTodayPrayers => 'Today\'s prayers';

  @override
  String get labelDailyWird => 'Daily wird';

  @override
  String get labelMorningAthkar => 'Morning athkar';

  @override
  String get labelEveningAthkar => 'Evening athkar';

  @override
  String get labelSleepAthkar => 'Before-sleep athkar';

  @override
  String get labelTasbeeh => 'Tasbeeh';

  @override
  String get labelQuranWird => 'Qur\'an wird';

  @override
  String get labelSource => 'Source';

  @override
  String get labelVirtue => 'Virtue';

  @override
  String get stateMosque => 'In the mosque';

  @override
  String get stateCongregation => 'In congregation';

  @override
  String get stateOnTime => 'On time';

  @override
  String get stateLate => 'Late';

  @override
  String get stateNotYet => 'Not yet';

  @override
  String get prayerFajr => 'Fajr';

  @override
  String get prayerDhuhr => 'Dhuhr';

  @override
  String get prayerAsr => 'Asr';

  @override
  String get prayerMaghrib => 'Maghrib';

  @override
  String get prayerIsha => 'Isha';

  @override
  String get nouriRemainingOnAdhan => 'until the adhan';

  @override
  String get nouriPrayedAction => 'Prayed';

  @override
  String get nouriComingSoon => 'Coming soon';

  @override
  String get nouriFinancePlaceholder =>
      'This part is on its way. Your expenses and budget will live here.';

  @override
  String get nouriTargetAdjustable => 'you can raise it';

  @override
  String nouriDidYouPray(String prayer) {
    return 'Did you pray $prayer?';
  }

  @override
  String nouriProgress(String done, String total) {
    return 'You\'ve done $done of $total';
  }
}
