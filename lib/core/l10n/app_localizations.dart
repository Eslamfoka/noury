import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'نوري'**
  String get appName;

  /// No description provided for @tabToday.
  ///
  /// In ar, this message translates to:
  /// **'النهاردة'**
  String get tabToday;

  /// No description provided for @tabAthkar.
  ///
  /// In ar, this message translates to:
  /// **'الأذكار'**
  String get tabAthkar;

  /// No description provided for @tabReports.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get tabReports;

  /// No description provided for @tabFinance.
  ///
  /// In ar, this message translates to:
  /// **'المالية'**
  String get tabFinance;

  /// No description provided for @tabSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get tabSettings;

  /// No description provided for @labelNextPrayer.
  ///
  /// In ar, this message translates to:
  /// **'الصلاة القادمة'**
  String get labelNextPrayer;

  /// No description provided for @labelIqama.
  ///
  /// In ar, this message translates to:
  /// **'الإقامة'**
  String get labelIqama;

  /// No description provided for @labelTodayPrayers.
  ///
  /// In ar, this message translates to:
  /// **'صلوات اليوم'**
  String get labelTodayPrayers;

  /// No description provided for @labelDailyWird.
  ///
  /// In ar, this message translates to:
  /// **'الورد اليومي'**
  String get labelDailyWird;

  /// No description provided for @labelMorningAthkar.
  ///
  /// In ar, this message translates to:
  /// **'أذكار الصباح'**
  String get labelMorningAthkar;

  /// No description provided for @labelEveningAthkar.
  ///
  /// In ar, this message translates to:
  /// **'أذكار المساء'**
  String get labelEveningAthkar;

  /// No description provided for @labelSleepAthkar.
  ///
  /// In ar, this message translates to:
  /// **'أذكار النوم'**
  String get labelSleepAthkar;

  /// No description provided for @labelTasbeeh.
  ///
  /// In ar, this message translates to:
  /// **'التسبيح'**
  String get labelTasbeeh;

  /// No description provided for @labelQuranWird.
  ///
  /// In ar, this message translates to:
  /// **'ورد القرآن'**
  String get labelQuranWird;

  /// No description provided for @labelSource.
  ///
  /// In ar, this message translates to:
  /// **'المصدر'**
  String get labelSource;

  /// No description provided for @labelVirtue.
  ///
  /// In ar, this message translates to:
  /// **'الفضل'**
  String get labelVirtue;

  /// No description provided for @stateMosque.
  ///
  /// In ar, this message translates to:
  /// **'في المسجد'**
  String get stateMosque;

  /// No description provided for @stateCongregation.
  ///
  /// In ar, this message translates to:
  /// **'جماعة'**
  String get stateCongregation;

  /// No description provided for @stateOnTime.
  ///
  /// In ar, this message translates to:
  /// **'في الوقت'**
  String get stateOnTime;

  /// No description provided for @stateLate.
  ///
  /// In ar, this message translates to:
  /// **'متأخرة'**
  String get stateLate;

  /// No description provided for @stateNotYet.
  ///
  /// In ar, this message translates to:
  /// **'لسه'**
  String get stateNotYet;

  /// No description provided for @prayerFajr.
  ///
  /// In ar, this message translates to:
  /// **'الفجر'**
  String get prayerFajr;

  /// No description provided for @prayerDhuhr.
  ///
  /// In ar, this message translates to:
  /// **'الظهر'**
  String get prayerDhuhr;

  /// No description provided for @prayerAsr.
  ///
  /// In ar, this message translates to:
  /// **'العصر'**
  String get prayerAsr;

  /// No description provided for @prayerMaghrib.
  ///
  /// In ar, this message translates to:
  /// **'المغرب'**
  String get prayerMaghrib;

  /// No description provided for @prayerIsha.
  ///
  /// In ar, this message translates to:
  /// **'العشاء'**
  String get prayerIsha;

  /// No description provided for @nouriRemainingOnAdhan.
  ///
  /// In ar, this message translates to:
  /// **'باقي على الأذان'**
  String get nouriRemainingOnAdhan;

  /// No description provided for @nouriPrayedAction.
  ///
  /// In ar, this message translates to:
  /// **'صليت'**
  String get nouriPrayedAction;

  /// No description provided for @nouriComingSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريباً إن شاء الله'**
  String get nouriComingSoon;

  /// No description provided for @nouriFinancePlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'الجزء ده لسه في الطريق. لما يجهز هتلاقي هنا مصاريفك وميزانيتك.'**
  String get nouriFinancePlaceholder;

  /// No description provided for @nouriTargetAdjustable.
  ///
  /// In ar, this message translates to:
  /// **'تقدر تزوّده'**
  String get nouriTargetAdjustable;

  /// No description provided for @nouriDidYouPray.
  ///
  /// In ar, this message translates to:
  /// **'صليت {prayer}؟'**
  String nouriDidYouPray(String prayer);

  /// No description provided for @nouriProgress.
  ///
  /// In ar, this message translates to:
  /// **'خلّصت {done} من {total}'**
  String nouriProgress(String done, String total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
