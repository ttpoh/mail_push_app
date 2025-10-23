// lib/models/rule_model.dart
import 'package:mail_push_app/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';

enum ConditionType {
  subjectContains,
  bodyContains,
  fromSender,
}

extension ConditionTypeExt on ConditionType {
  String displayName(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case ConditionType.subjectContains:
        return t.conditionTypeSubjectContains;
      case ConditionType.bodyContains:
        return t.conditionTypeBodyContains;
      case ConditionType.fromSender:
        return t.conditionTypeFromSender;
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

enum LogicType { and, or }

extension LogicTypeExt on LogicType {
  String displayName(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case LogicType.and:
        return t.logicAnd;
      case LogicType.or:
        return t.logicOr;
    }
  }

  String get apiValue => name;

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

enum AlarmLevel { normal, critical, until }

extension AlarmLevelExt on AlarmLevel {
  String displayName(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    switch (this) {
      case AlarmLevel.normal:
        return t.generalAlarmLabel;
      case AlarmLevel.critical:
        return t.oneTimeAlarm;
      case AlarmLevel.until:
        return t.untilStoppedAlarm;
    }
  }

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
    this.logic = LogicType.or,
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
  String? sound;
  String? tts;
  int? id;

  MailRule({
    required this.name,
    required this.conditions,
    this.enabled = true,
    this.alarm = AlarmLevel.normal,
    this.sound,
    this.tts,
    this.id,
  });

  MailRule.clone(MailRule other)
      : name = other.name,
        conditions = other.conditions.map((c) => RuleCondition.clone(c)).toList(),
        enabled = other.enabled,
        alarm = other.alarm,
        sound = other.sound,
        tts = other.tts,
        id = other.id;

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
      conditions: conditions ?? this.conditions.map((c) => RuleCondition.clone(c)).toList(),
      enabled: enabled ?? this.enabled,
      alarm: alarm ?? this.alarm,
      sound: sound ?? this.sound,
      tts: tts ?? this.tts,
      id: id ?? this.id,
    );
  }


  factory MailRule.fromJson(Map<String, dynamic> json) {
    return MailRule(
      id: json['id'],
      name: json['name'],
      enabled: json['enabled'] ?? true,
      alarm: AlarmLevelExt.fromApiValue(json['alarm'] as String?),
      sound: json['sound'],
      tts: json['tts'],
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
      if (sound != null) 'sound': sound,
      if (tts != null) 'tts': tts,
      'conditions': conditions.map((c) => c.toJson()).toList(),
    };
  }
}
