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

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(
      id: json['id'],
      position: json['position'],
      type: ConditionTypeExt.fromApiValue(json['type'] ?? ''),
      logic: LogicTypeExt.fromApiValue(json['logic'] ?? 'or'),
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
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
  int? id;

  MailRule({
    required this.name,
    required this.conditions,
    this.enabled = true,
    this.alarm = AlarmLevel.normal,
    this.id,
  });

  MailRule.clone(MailRule other)
      : name = other.name,
        conditions = other.conditions.map((c) => RuleCondition.clone(c)).toList(),
        enabled = other.enabled,
        alarm = other.alarm,
        id = other.id;

  factory MailRule.fromJson(Map<String, dynamic> json) {
    return MailRule(
      id: json['id'],
      name: json['name'],
      enabled: json['enabled'] ?? true,
      alarm: AlarmLevelExt.fromApiValue(json['alarm'] as String?),
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
      'conditions': conditions.map((c) => c.toJson()).toList(),
    };
  }
}
