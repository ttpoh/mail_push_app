// lib/models/email.dart
import 'dart:convert';

class Email {
  /// 원본 메시지 ID (예: Gmail messageId). 리스트/딕셔너리 키로 사용.
  final String id;

  final String emailAddress;
  final String subject;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final bool read;

  /// 규칙 등급 / 실제 등급
  final String? ruleAlarm;       // 'normal' | 'critical' | 'until'
  final String? effectiveAlarm;  // 서버 전역 세팅 반영 값 (우선 사용)

  /// 호환용: 예전 코드가 messageId를 참조해도 동작
  String get messageId => id;

  Email({
    required this.id,
    required this.emailAddress,
    required this.subject,
    required this.sender,
    required this.body,
    required this.receivedAt,
    required this.read,
    this.ruleAlarm,
    this.effectiveAlarm,
  });

  static String _asString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  /// 다양한 키에서 message id 추출: messageId → message_id → id → fallback
  static String _extractId(Map<String, dynamic> data) {
    for (final k in const ['messageId', 'message_id', 'id']) {
      final v = data[k];
      if (v != null && _asString(v).isNotEmpty) return _asString(v);
    }
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 다양한 경로에서 ruleAlarm 추출
  static String? _extractRuleAlarm(Map<String, dynamic> data) {
    final ra = data['ruleAlarm'];
    if (ra is String && ra.isNotEmpty) return ra;
    final alt = data['alarm']; // 혹시 다른 키로 올 수도 있음
    if (alt is String && alt.isNotEmpty) return alt;
    final mailData = data['mailData'];
    if (mailData is Map && mailData['ruleAlarm'] is String) {
      final s = mailData['ruleAlarm'] as String;
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  /// 다양한 경로에서 effectiveAlarm 추출
  static String? _extractEffectiveAlarm(Map<String, dynamic> data) {
    final ea = data['effectiveAlarm'];
    if (ea is String && ea.isNotEmpty) return ea;
    final mailData = data['mailData'];
    if (mailData is Map && mailData['effectiveAlarm'] is String) {
      final s = mailData['effectiveAlarm'] as String;
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  factory Email.fromJson(Map<String, dynamic> data) {
    final id = _extractId(data);
    final emailAddress = _asString(data['email_address']);
    final subject = _asString(data['subject']);
    final sender = _asString(data['sender']);
    final body = _asString(data['body']);

    final receivedRaw = data['received_at'];
    final receivedAt = (receivedRaw != null && _asString(receivedRaw).isNotEmpty)
        ? DateTime.parse(_asString(receivedRaw))
        : DateTime.now();

    final read = (data['read'] is bool) ? data['read'] as bool : false;

    final ruleAlarm = _extractRuleAlarm(data);
    final effectiveAlarm = _extractEffectiveAlarm(data);

    return Email(
      id: id,
      emailAddress: emailAddress,
      subject: subject,
      sender: sender,
      body: body,
      receivedAt: receivedAt,
      read: read,
      ruleAlarm: ruleAlarm,
      effectiveAlarm: effectiveAlarm,
    );
  }

  factory Email.fromJsonString(String json) =>
      Email.fromJson(jsonDecode(json) as Map<String, dynamic>);

  Map<String, dynamic> toJson() => {
        'messageId': id,
        'email_address': emailAddress,
        'subject': subject,
        'sender': sender,
        'body': body,
        'received_at': receivedAt.toIso8601String(),
        'read': read,
        if (ruleAlarm != null) 'ruleAlarm': ruleAlarm,
        if (effectiveAlarm != null) 'effectiveAlarm': effectiveAlarm,
      };

  Email copyWith({
    String? id,
    String? emailAddress,
    String? subject,
    String? sender,
    String? body,
    DateTime? receivedAt,
    bool? read,
    String? ruleAlarm,
    String? effectiveAlarm,
  }) {
    return Email(
      id: id ?? this.id,
      emailAddress: emailAddress ?? this.emailAddress,
      subject: subject ?? this.subject,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      receivedAt: receivedAt ?? this.receivedAt,
      read: read ?? this.read,
      ruleAlarm: ruleAlarm ?? this.ruleAlarm,
      effectiveAlarm: effectiveAlarm ?? this.effectiveAlarm,
    );
  }
}
