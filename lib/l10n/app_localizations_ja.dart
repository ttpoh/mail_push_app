// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'ガードフォース';

  @override
  String get menuRulesLabel => 'メールのルール';

  @override
  String get menuAlarmSettings => '通知設定';

  @override
  String get menuLogout => 'ログアウト';

  @override
  String get waitingNewEmails => '新しいメールの受信待ち...';

  @override
  String get settingsOpenError => '設定画面を開けませんでした。';

  @override
  String get alarmSettingsTitle => '通知設定';

  @override
  String get generalAlarmLabel => 'アラーム';

  @override
  String get generalAlarmSubtitle => 'サイレント/おやすみモードは迂回しません';

  @override
  String get criticalAlarmLabel => '緊急アラーム（サイレント中も許可）';

  @override
  String get criticalAlarmSubtitle => '必要に応じておやすみモードも迂回します';

  @override
  String get criticalAlarmModeLabel => '緊急アラームモード';

  @override
  String get ringOnce => '1回だけ鳴動';

  @override
  String get ringUntilStopped => '止めるまで鳴動';

  @override
  String get openAppNotificationSettings => 'アプリの通知設定を開く';

  @override
  String get close => '閉じる';

  @override
  String get unknownSender => '差出人不明';

  @override
  String get noSubject => '件名なし';

  @override
  String get noLoggedInEmail => 'ログイン中のユーザーのメールがありません。';

  @override
  String emailLoadFailed(String error) {
    return 'メールの読み込みに失敗しました: $error';
  }

  @override
  String logoutFailed(String error) {
    return 'ログアウト失敗: $error';
  }

  @override
  String userLabel(String email) {
    return 'ユーザー: $email';
  }

  @override
  String get addRule => '新規ルール';

  @override
  String get reload => 'リロード';

  @override
  String get retry => '再試行';

  @override
  String loadFailed(String error) {
    return '読み込み失敗: $error';
  }

  @override
  String get noRules => '登録されたルールはありません。＋ボタンで新しいルールを追加してください。';

  @override
  String get newRule => '新規ルール';

  @override
  String ruleCreateFailed(String error) {
    return 'ルール作成失敗: $error';
  }

  @override
  String ruleUpdateFailed(String error) {
    return '修正失敗: $error';
  }

  @override
  String ruleDeleteFailed(String error) {
    return '削除失敗: $error';
  }

  @override
  String get ruleEdit => '修正';

  @override
  String get ruleDelete => '削除';

  @override
  String get none => 'なし';

  @override
  String get ruleEditTitle => '規則修正';

  @override
  String get ruleCreateTitle => '新規則';

  @override
  String get savingEllipsis => '保存中...';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get conditions => '条件';

  @override
  String get noConditionsHint => '条件がありません。下の「条件追加」で追加してください。';

  @override
  String get addCondition => '条件追加';

  @override
  String get deleteCondition => '条件削除';

  @override
  String get conditionTypeSubjectContains => '件名に含まれる';

  @override
  String get conditionTypeBodyContains => '本文に含まれる';

  @override
  String get conditionTypeFromSender => '差出人';

  @override
  String get keywordHint => '例: MTG';

  @override
  String get keywordAddLabel => 'キーワード追加';

  @override
  String get add => '追加';

  @override
  String get addAtLeastOneKeyword => 'キーワードを1つ以上追加してください。';

  @override
  String get ruleNameLabel => 'ルール名';

  @override
  String get ruleNameRequired => 'ルールのタイトルを入力してください。';

  @override
  String get needAtLeastOneCondition => '条件を1つ以上追加してください。';

  @override
  String get needKeywordsInAllConditions => 'すべての条件にキーワードを入れてください。';

  @override
  String get keywordInputHelper => 'カンマ（,）・セミコロン（;）・改行で複数入力できます。';

  @override
  String get ruleSaveFailed => 'ルールの保存に失敗しました。もう一度お試しください。';

  @override
  String get stopFurtherRules => 'このルール以降の処理を停止';

  @override
  String get criticalMustBeOnForUntilStopped => '停止するまで鳴動を使うには、緊急通知をONにしてください。';

  @override
  String get stopEmergencyAlarm => '緊急アラームを停止';

  @override
  String get keywordLogicLabel => 'キーワードロジック';

  @override
  String get logicAnd => 'AND（すべて一致）';

  @override
  String get logicOr => 'OR（いずれか一致）';

  @override
  String get needLogicForConditions => '各条件のキーワードロジック（AND / OR）を選択してください。';

  @override
  String get enterSoundOrTts => 'サウンドまたはTTSメッセージを 1 つ以上設定していただけますか。';

  @override
  String get soundLabel => 'サウンド';

  @override
  String get selectSoundHint => 'サウンドを選択してください';

  @override
  String get ttsMessageLabel => 'TTSメッセージ';

  @override
  String get ttsMessageHint => '例: 緊急メールが届きました';

  @override
  String get loginTitle => 'ログイン';

  @override
  String get langKorean => '한국어';

  @override
  String get langEnglish => 'English';

  @override
  String get langJapanese => '日本語';

  @override
  String get changeLanguageUnavailable => '言語を変更できません。';

  @override
  String tokenRegisterFailed(String service) {
    return '$service のトークン登録に失敗しました';
  }

  @override
  String get fcmTokenFetchFailed => 'FCMトークンの取得に失敗しました';

  @override
  String loginFailed(String service) {
    return '$service のログインに失敗しました';
  }

  @override
  String loginError(String error) {
    return 'ログインエラー: $error';
  }

  @override
  String get alarmSoundLabel => 'サウンド';

  @override
  String get previewSound => '試聴';

  @override
  String get oneTimeAlarm => '1回だけ鳴動';

  @override
  String get untilStoppedAlarm => '止めるまで鳴動';

  @override
  String get alarmTitleOneTime => '1回鳴動';

  @override
  String get alarmTitleUntil => '止めるまで';
}
