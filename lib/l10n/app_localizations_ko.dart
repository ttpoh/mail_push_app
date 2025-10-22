// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'GUARD-FORCE';

  @override
  String get menuRulesLabel => '메일 규칙';

  @override
  String get menuAlarmSettings => '알람 설정';

  @override
  String get menuLogout => '로그아웃';

  @override
  String get waitingNewEmails => '새 이메일 수신 대기 중...';

  @override
  String get settingsOpenError => '설정 화면을 열 수 없습니다.';

  @override
  String get alarmSettingsTitle => '알람 설정';

  @override
  String get generalAlarmLabel => '일반 알람';

  @override
  String get generalAlarmSubtitle => '무음/방해금지 모드를 우회하지 않음';

  @override
  String get criticalAlarmLabel => '긴급 알람 (무음 모드 허용)';

  @override
  String get criticalAlarmSubtitle => '필요 시 방해금지 모드도 우회';

  @override
  String get criticalAlarmModeLabel => '긴급 알람 모드';

  @override
  String get ringOnce => '1회 울림';

  @override
  String get ringUntilStopped => '끌 때까지 울림';

  @override
  String get openAppNotificationSettings => '앱 알림 설정 열기';

  @override
  String get close => '닫기';

  @override
  String get unknownSender => '보낸 이 미상';

  @override
  String get noSubject => '제목 없음';

  @override
  String get noLoggedInEmail => '로그인된 사용자 이메일이 없습니다.';

  @override
  String emailLoadFailed(String error) {
    return '이메일 로딩 실패: $error';
  }

  @override
  String logoutFailed(String error) {
    return '로그아웃 실패: $error';
  }

  @override
  String userLabel(String email) {
    return '사용자: $email';
  }

  @override
  String get addRule => '새 규칙 추가';

  @override
  String get reload => '새로 고침';

  @override
  String get retry => '재시도';

  @override
  String loadFailed(String error) {
    return '불러오기 실패: $error';
  }

  @override
  String get noRules => '등록된 규칙이 없습니다. + 버튼으로 새 규칙을 추가하세요.';

  @override
  String get newRule => '신규 규칙';

  @override
  String ruleCreateFailed(String error) {
    return '규칙 생성 실패: $error';
  }

  @override
  String ruleUpdateFailed(String error) {
    return '규칙 수정 실패: $error';
  }

  @override
  String ruleDeleteFailed(String error) {
    return '규칙 삭제 실패: $error';
  }

  @override
  String get ruleEdit => '수정';

  @override
  String get ruleDelete => '삭제';

  @override
  String get none => '없음';

  @override
  String get ruleEditTitle => '규칙 수정';

  @override
  String get ruleCreateTitle => '신규 규칙';

  @override
  String get savingEllipsis => '저장중...';

  @override
  String get save => '저장';

  @override
  String get cancel => '취소';

  @override
  String get conditions => '조건';

  @override
  String get noConditionsHint => '조건이 없습니다. 아래 \"조건 추가\"로 추가하세요.';

  @override
  String get addCondition => '조건 추가';

  @override
  String get deleteCondition => '조건 삭제';

  @override
  String get conditionTypeSubjectContains => '제목에 포함';

  @override
  String get conditionTypeBodyContains => '본문에 포함';

  @override
  String get conditionTypeFromSender => '보낸 사람';

  @override
  String get keywordHint => '예: MTG';

  @override
  String get keywordAddLabel => '키워드 추가';

  @override
  String get add => '추가';

  @override
  String get addAtLeastOneKeyword => '키워드를 하나 이상 추가하세요.';

  @override
  String get ruleNameLabel => '규칙 이름 지정';

  @override
  String get ruleNameRequired => '규칙의 제목을 입력하세요.';

  @override
  String get needAtLeastOneCondition => '조건을 하나 이상 추가하세요.';

  @override
  String get needKeywordsInAllConditions => '모든 조건에 키워드를 넣어야 합니다.';

  @override
  String get keywordInputHelper => '쉼표(,)·세미콜론(;)·줄바꿈으로 여러 개 입력할 수 있어요.';

  @override
  String get ruleSaveFailed => '규칙 저장에 실패했습니다. 다시 시도해주세요.';

  @override
  String get stopFurtherRules => '이 규칙 이후 처리 중지';

  @override
  String get criticalMustBeOnForUntilStopped => '정지 시까지 울림을 사용하려면 긴급 알림을 켜야 합니다.';

  @override
  String get stopEmergencyAlarm => '긴급 알람 중지';

  @override
  String get keywordLogicLabel => '키워드 로직';

  @override
  String get logicAnd => 'AND (모두 일치)';

  @override
  String get logicOr => 'OR (하나 이상 일치)';

  @override
  String get needLogicForConditions => '각 조건의 키워드 로직(AND / OR)을 선택하세요.';

  @override
  String get enterSoundOrTts => '사운드 또는 TTS 메시지를 하나 이상 설정해 주세요.';

  @override
  String get soundLabel => '사운드';

  @override
  String get selectSoundHint => '사운드를 선택하세요';

  @override
  String get ttsMessageLabel => 'TTS 메시지';

  @override
  String get ttsMessageHint => '예: 긴급 메일이 도착했습니다.';

  @override
  String get loginTitle => '로그인';

  @override
  String get langKorean => '한국어';

  @override
  String get langEnglish => 'English';

  @override
  String get langJapanese => '日本語';

  @override
  String get changeLanguageUnavailable => '언어 변경을 사용할 수 없습니다.';

  @override
  String tokenRegisterFailed(String service) {
    return '$service 토큰 등록 실패';
  }

  @override
  String get fcmTokenFetchFailed => 'FCM 토큰 획득 실패';

  @override
  String loginFailed(String service) {
    return '$service 로그인 실패';
  }

  @override
  String loginError(String error) {
    return '로그인 오류: $error';
  }
}
