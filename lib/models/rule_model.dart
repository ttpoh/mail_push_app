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

  String get apiValue => name; // 서버가 "subjectContains" 같은 형식을 기대한다고 가정

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

class RuleCondition {
  ConditionType type;
  List<String> keywords;
  int? id;
  int? position;

  RuleCondition({
    required this.type,
    List<String>? keywords,
    this.id,
    this.position,
  }) : keywords = List.from(keywords ?? []);

  RuleCondition.clone(RuleCondition other)
      : type = other.type,
        keywords = List.from(other.keywords),
        id = other.id,
        position = other.position;

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(
      id: json['id'],
      position: json['position'],
      type: ConditionTypeExt.fromApiValue(json['type'] ?? ''),
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type.apiValue,
      'keywords': keywords,
    };
  }
}

class MailRule {
  String name;
  List<RuleCondition> conditions;
  bool stopFurtherRules;
  bool enabled;
  int? id;

  MailRule({
    required this.name,
    required this.conditions,
    this.stopFurtherRules = false,
    this.enabled = true,
    this.id,
  });

  MailRule.clone(MailRule other)
      : name = other.name,
        conditions = other.conditions.map((c) => RuleCondition.clone(c)).toList(),
        stopFurtherRules = other.stopFurtherRules,
        enabled = other.enabled,
        id = other.id;

  factory MailRule.fromJson(Map<String, dynamic> json) {
    return MailRule(
      id: json['id'],
      name: json['name'],
      enabled: json['enabled'] ?? true,
      stopFurtherRules: json['stop_further_rules'] ?? false,
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
      'stop_further_rules': stopFurtherRules,
      'conditions': conditions.map((c) => c.toJson()).toList(),
    };
  }
}
