import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GUARD-FORCE'**
  String get appTitle;

  /// No description provided for @menuRulesLabel.
  ///
  /// In en, this message translates to:
  /// **'Mail rules'**
  String get menuRulesLabel;

  /// No description provided for @menuAlarmSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get menuAlarmSettings;

  /// No description provided for @menuLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get menuLogout;

  /// No description provided for @waitingNewEmails.
  ///
  /// In en, this message translates to:
  /// **'Waiting for new emails...'**
  String get waitingNewEmails;

  /// No description provided for @settingsOpenError.
  ///
  /// In en, this message translates to:
  /// **'Unable to open settings screen.'**
  String get settingsOpenError;

  /// No description provided for @alarmSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get alarmSettingsTitle;

  /// No description provided for @generalAlarmLabel.
  ///
  /// In en, this message translates to:
  /// **'General alerts'**
  String get generalAlarmLabel;

  /// No description provided for @generalAlarmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Does not bypass Silent/Do Not Disturb'**
  String get generalAlarmSubtitle;

  /// No description provided for @criticalAlarmLabel.
  ///
  /// In en, this message translates to:
  /// **'Critical alerts (allow in Silent)'**
  String get criticalAlarmLabel;

  /// No description provided for @criticalAlarmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'May bypass Do Not Disturb if needed'**
  String get criticalAlarmSubtitle;

  /// No description provided for @criticalAlarmModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Critical alert mode'**
  String get criticalAlarmModeLabel;

  /// No description provided for @ringOnce.
  ///
  /// In en, this message translates to:
  /// **'Ring once'**
  String get ringOnce;

  /// No description provided for @ringUntilStopped.
  ///
  /// In en, this message translates to:
  /// **'Ring until stopped'**
  String get ringUntilStopped;

  /// No description provided for @openAppNotificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app notification settings'**
  String get openAppNotificationSettings;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @unknownSender.
  ///
  /// In en, this message translates to:
  /// **'Unknown sender'**
  String get unknownSender;

  /// No description provided for @noSubject.
  ///
  /// In en, this message translates to:
  /// **'No subject'**
  String get noSubject;

  /// No description provided for @noLoggedInEmail.
  ///
  /// In en, this message translates to:
  /// **'No logged-in user email.'**
  String get noLoggedInEmail;

  /// No description provided for @emailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load emails: {error}'**
  String emailLoadFailed(String error);

  /// No description provided for @logoutFailed.
  ///
  /// In en, this message translates to:
  /// **'Logout failed: {error}'**
  String logoutFailed(String error);

  /// No description provided for @userLabel.
  ///
  /// In en, this message translates to:
  /// **'User: {email}'**
  String userLabel(String email);

  /// No description provided for @addRule.
  ///
  /// In en, this message translates to:
  /// **'Add rule'**
  String get addRule;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String loadFailed(String error);

  /// No description provided for @noRules.
  ///
  /// In en, this message translates to:
  /// **'No rules registered. Tap + to add a new rule.'**
  String get noRules;

  /// No description provided for @newRule.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get newRule;

  /// No description provided for @ruleCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create rule: {error}'**
  String ruleCreateFailed(String error);

  /// No description provided for @ruleUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update rule: {error}'**
  String ruleUpdateFailed(String error);

  /// No description provided for @ruleDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete rule: {error}'**
  String ruleDeleteFailed(String error);

  /// No description provided for @ruleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get ruleEdit;

  /// No description provided for @ruleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get ruleDelete;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @ruleEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit rule'**
  String get ruleEditTitle;

  /// No description provided for @ruleCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'New rule'**
  String get ruleCreateTitle;

  /// No description provided for @savingEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingEllipsis;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @conditions.
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// No description provided for @noConditionsHint.
  ///
  /// In en, this message translates to:
  /// **'No conditions yet. Use \"Add condition\" below.'**
  String get noConditionsHint;

  /// No description provided for @addCondition.
  ///
  /// In en, this message translates to:
  /// **'Add condition'**
  String get addCondition;

  /// No description provided for @deleteCondition.
  ///
  /// In en, this message translates to:
  /// **'Delete condition'**
  String get deleteCondition;

  /// No description provided for @conditionTypeSubjectContains.
  ///
  /// In en, this message translates to:
  /// **'Subject contains'**
  String get conditionTypeSubjectContains;

  /// No description provided for @conditionTypeBodyContains.
  ///
  /// In en, this message translates to:
  /// **'Body contains'**
  String get conditionTypeBodyContains;

  /// No description provided for @conditionTypeFromSender.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get conditionTypeFromSender;

  /// No description provided for @keywordHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., MTG'**
  String get keywordHint;

  /// No description provided for @keywordAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add keyword'**
  String get keywordAddLabel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addAtLeastOneKeyword.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one keyword.'**
  String get addAtLeastOneKeyword;

  /// No description provided for @ruleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Rule name'**
  String get ruleNameLabel;

  /// No description provided for @ruleNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a rule title.'**
  String get ruleNameRequired;

  /// No description provided for @needAtLeastOneCondition.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one condition.'**
  String get needAtLeastOneCondition;

  /// No description provided for @needKeywordsInAllConditions.
  ///
  /// In en, this message translates to:
  /// **'Every condition must contain keywords.'**
  String get needKeywordsInAllConditions;

  /// No description provided for @ruleSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save rule. Please try again.'**
  String get ruleSaveFailed;

  /// No description provided for @stopFurtherRules.
  ///
  /// In en, this message translates to:
  /// **'Stop processing after this rule'**
  String get stopFurtherRules;

  /// Shown when user enables 'Until Stopped' while critical is off.
  ///
  /// In en, this message translates to:
  /// **'Critical must be ON to use ‘Until Stopped’ mode.'**
  String get criticalMustBeOnForUntilStopped;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @langKorean.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get langKorean;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langJapanese.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get langJapanese;

  /// No description provided for @changeLanguageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Language change is unavailable.'**
  String get changeLanguageUnavailable;

  /// No description provided for @tokenRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Token registration failed for {service}'**
  String tokenRegisterFailed(String service);

  /// No description provided for @fcmTokenFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to get FCM token'**
  String get fcmTokenFetchFailed;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed for {service}'**
  String loginFailed(String service);

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Login error: {error}'**
  String loginError(String error);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
    case 'ko': return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
