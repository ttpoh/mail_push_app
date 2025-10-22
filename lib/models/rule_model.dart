// rule_model.dart
enum ConditionType {
  subjectContains,
  bodyContains,
  fromSender,
}

extension ConditionTypeExt on ConditionType {
  String get displayName {
    switch (this) {
      case ConditionType.subjectContains:
        return 'タイトルに含まれる'; // 제목에 포함
      case ConditionType.bodyContains:
        return '内容に含まれる'; // 내용에 포함
      case ConditionType.fromSender:
        return '差出人'; // 보낸 사람
    }
  }

  String get apiValue => name;

  static ConditionType fromApiValue(String t) {
    switch (t) {
      case 'subjectContains':
        return ConditionType.subjectContains;
      case 'bodyContains':
        return ConditionType.bodyContains;
      case 'fromSender':
        return ConditionType.fromSender;
      default:
        return ConditionType.subjectContains;
    }
  }
}

/// ✅ 키워드 매칭 로직(AND / OR)
enum LogicType { and, or }

extension LogicTypeExt on LogicType {
  String get apiValue => name; // 서버도 "and" / "or" 문자열 사용
  static LogicType fromApiValue(String t) {
    switch (t) {
      case 'and':
        return LogicType.and;
      case 'or':
      default:
        return LogicType.or;
    }
  }
}

/// ✅ 규칙별 알람 레벨
enum AlarmLevel { normal, critical, until }

extension AlarmLevelExt on AlarmLevel {
  String get apiValue => name;
  static AlarmLevel fromApiValue(String? t) {
    switch (t) {
      case 'critical':
        return AlarmLevel.critical;
      case 'until':
        return AlarmLevel.until;
      case 'normal':
      default:
        return AlarmLevel.normal;
    }
  }
}

class RuleCondition {
  ConditionType type;
  List<String> keywords;
  LogicType logic;
  int? id;
  int? position;

  RuleCondition({
    required this.type,
    List<String>? keywords,
    this.logic = LogicType.or, // 기본값: OR
    this.id,
    this.position,
  }) : keywords = List.from(keywords ?? []);

  RuleCondition.clone(RuleCondition other)
      : type = other.type,
        keywords = List.from(other.keywords),
        logic = other.logic,
        id = other.id,
        position = other.position;

  /// ✅ copyWith 추가
  RuleCondition copyWith({
    ConditionType? type,
    List<String>? keywords,
    LogicType? logic,
    int? id,         // id를 명시적으로 바꿔야 하면 전달
    int? position,   // position을 명시적으로 바꿔야 하면 전달
  }) {
    return RuleCondition(
      type: type ?? this.type,
      keywords: keywords ?? List<String>.from(this.keywords),
      logic: logic ?? this.logic,
      id: id ?? this.id,
      position: position ?? this.position,
    );
  }

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    final kw = (json['keywords'] as List?)?.cast<String>() ?? const <String>[];
    return RuleCondition(
      id: json['id'],
      position: json['position'],
      type: ConditionTypeExt.fromApiValue(json['type'] ?? ''),
      logic: LogicTypeExt.fromApiValue(json['logic'] ?? 'or'),
      keywords: kw,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      'type': type.apiValue,
      'logic': logic.apiValue,
      'keywords': keywords,
    };
  }
}

class MailRule {
  String name;
  List<RuleCondition> conditions;
  bool enabled;
  AlarmLevel alarm;

  /// ✅ 추가: 알람 사운드 식별자/경로 (예: 'default' 또는 'assets/sounds/siren.mp3')
  String sound;

  /// ✅ 추가: TTS 메시지(사용자 입력). null 가능
  String? tts;

  int? id;

  MailRule({
    required this.name,
    required this.conditions,
    this.enabled = true,
    this.alarm = AlarmLevel.normal,
    this.sound = 'default',
    this.tts,                 // ✅ 새 필드
    this.id,
  });

  MailRule.clone(MailRule other)
      : name = other.name,
        conditions = other.conditions.map((c) => RuleCondition.clone(c)).toList(),
        enabled = other.enabled,
        alarm = other.alarm,
        sound = other.sound,
        tts = other.tts,      // ✅ 복제
        id = other.id;

  /// ✅ copyWith에 sound/tts 파라미터를 추가
  MailRule copyWith({
    String? name,
    List<RuleCondition>? conditions,
    bool? enabled,
    AlarmLevel? alarm,
    String? sound,
    String? tts,
    int? id,
  }) {
    return MailRule(
      name: name ?? this.name,
      // 방어적 복사: 외부에서 전달 안하면 기존 리스트를 깊은 복사로 복제
      conditions: conditions ??
          this.conditions.map((c) => RuleCondition.clone(c)).toList(),
      enabled: enabled ?? this.enabled,
      alarm: alarm ?? this.alarm,
      sound: sound ?? this.sound,     // ✅ sound 반영
      tts: tts ?? this.tts,           // ✅ tts 반영
      id: id ?? this.id,
    );
  }

  factory MailRule.fromJson(Map<String, dynamic> json) {
    return MailRule(
      id: json['id'],
      name: json['name'],
      enabled: json['enabled'] ?? true,
      alarm: AlarmLevelExt.fromApiValue(json['alarm'] as String?),
      sound: (json['sound'] as String?)?.trim().isNotEmpty == true
          ? json['sound']
          : 'default',
      tts: (json['tts'] as String?)?.trim().isNotEmpty == true
          ? json['tts']
          : null,                         // ✅ tts 수신
      conditions: (json['conditions'] as List<dynamic>)
          .map((c) => RuleCondition.fromJson(c))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'enabled': enabled,
      'alarm': alarm.apiValue,
      'sound': sound,                              // ✅ 직렬화
      if (tts != null) 'tts': tts,                 // ✅ 직렬화 (null이면 제외)
      'conditions': conditions.map((c) => c.toJson()).toList(),
    };
  }
}
