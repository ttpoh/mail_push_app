// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GUARD-FORCE';

  @override
  String get menuRulesLabel => 'Mail rules';

  @override
  String get menuAlarmSettings => 'Notification settings';

  @override
  String get menuLogout => 'Log out';

  @override
  String get waitingNewEmails => 'Waiting for new emails...';

  @override
  String get settingsOpenError => 'Unable to open settings screen.';

  @override
  String get alarmSettingsTitle => 'Notification settings';

  @override
  String get generalAlarmLabel => 'General alerts';

  @override
  String get generalAlarmSubtitle => 'Does not bypass Silent/Do Not Disturb';

  @override
  String get criticalAlarmLabel => 'Critical alerts (allow in Silent)';

  @override
  String get criticalAlarmSubtitle => 'May bypass Do Not Disturb if needed';

  @override
  String get criticalAlarmModeLabel => 'Critical alert mode';

  @override
  String get ringOnce => 'Ring once';

  @override
  String get ringUntilStopped => 'Ring until stopped';

  @override
  String get openAppNotificationSettings => 'Open app notification settings';

  @override
  String get close => 'Close';

  @override
  String get unknownSender => 'Unknown sender';

  @override
  String get noSubject => 'No subject';

  @override
  String get noLoggedInEmail => 'No logged-in user email.';

  @override
  String emailLoadFailed(String error) {
    return 'Failed to load emails: $error';
  }

  @override
  String logoutFailed(String error) {
    return 'Logout failed: $error';
  }

  @override
  String userLabel(String email) {
    return 'User: $email';
  }

  @override
  String get addRule => 'Add rule';

  @override
  String get reload => 'Reload';

  @override
  String get retry => 'Retry';

  @override
  String loadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get noRules => 'No rules registered. Tap + to add a new rule.';

  @override
  String get newRule => 'New rule';

  @override
  String ruleCreateFailed(String error) {
    return 'Failed to create rule: $error';
  }

  @override
  String ruleUpdateFailed(String error) {
    return 'Failed to update rule: $error';
  }

  @override
  String ruleDeleteFailed(String error) {
    return 'Failed to delete rule: $error';
  }

  @override
  String get ruleEdit => 'Edit';

  @override
  String get ruleDelete => 'Delete';

  @override
  String get none => 'None';

  @override
  String get ruleEditTitle => 'Edit rule';

  @override
  String get ruleCreateTitle => 'New rule';

  @override
  String get savingEllipsis => 'Saving...';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get conditions => 'Conditions';

  @override
  String get noConditionsHint => 'No conditions yet. Use \"Add condition\" below.';

  @override
  String get addCondition => 'Add condition';

  @override
  String get deleteCondition => 'Delete condition';

  @override
  String get conditionTypeSubjectContains => 'Subject contains';

  @override
  String get conditionTypeBodyContains => 'Body contains';

  @override
  String get conditionTypeFromSender => 'From';

  @override
  String get keywordHint => 'e.g., MTG';

  @override
  String get keywordAddLabel => 'Add keyword';

  @override
  String get add => 'Add';

  @override
  String get addAtLeastOneKeyword => 'Please add at least one keyword.';

  @override
  String get ruleNameLabel => 'Rule name';

  @override
  String get ruleNameRequired => 'Please enter a rule title.';

  @override
  String get needAtLeastOneCondition => 'Please add at least one condition.';

  @override
  String get needKeywordsInAllConditions => 'Every condition must contain keywords.';

  @override
  String get keywordInputHelper => 'You can enter multiple items using commas (,), semicolons (;), or new lines.';

  @override
  String get ruleSaveFailed => 'Failed to save rule. Please try again.';

  @override
  String get stopFurtherRules => 'Stop processing after this rule';

  @override
  String get criticalMustBeOnForUntilStopped => 'Critical must be ON to use ‘Until Stopped’ mode.';

  @override
  String get stopEmergencyAlarm => 'Stop Emergency Alarm';

  @override
  String get keywordLogicLabel => 'Keyword Logic';

  @override
  String get logicAnd => 'AND (must match all)';

  @override
  String get logicOr => 'OR (match any)';

  @override
  String get needLogicForConditions => 'Please choose keyword logic (AND / OR) for each condition.';

  @override
  String get enterSoundOrTts => 'Please set at least one sound or TTS message.';

  @override
  String get soundLabel => 'sound';

  @override
  String get selectSoundHint => 'Please select the sound.';

  @override
  String get ttsMessageLabel => 'TTS message';

  @override
  String get ttsMessageHint => 'Example: Emergency mail has arrived.';

  @override
  String get loginTitle => 'Login';

  @override
  String get langKorean => '한국어';

  @override
  String get langEnglish => 'English';

  @override
  String get langJapanese => '日本語';

  @override
  String get changeLanguageUnavailable => 'Language change is unavailable.';

  @override
  String tokenRegisterFailed(String service) {
    return 'Token registration failed for $service';
  }

  @override
  String get fcmTokenFetchFailed => 'Failed to get FCM token';

  @override
  String loginFailed(String service) {
    return 'Login failed for $service';
  }

  @override
  String loginError(String error) {
    return 'Login error: $error';
  }
}
