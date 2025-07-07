import 'dart:convert';

class Email {
  final int id;
  final String emailAddress;
  final String subject;
  final String sender;
  final String body;
  final DateTime receivedAt;
  final bool read;

  Email({
    required this.id,
    required this.emailAddress,
    required this.subject,
    required this.sender,
    required this.body,
    required this.receivedAt,
    required this.read,
  });

  factory Email.fromJson(Map<String, dynamic> data) {
    return Email(
      id: (data['messageId'] ?? DateTime.now().millisecondsSinceEpoch).toString().hashCode,
      emailAddress: data['email_address'] ?? '',
      subject: data['subject'] ?? '',
      sender: data['sender'] ?? 'Unknown Sender',
      body: data['body'] ?? '',
      receivedAt: data['received_at'] != null
          ? DateTime.parse(data['received_at'])
          : DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  factory Email.fromJsonString(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return Email.fromJson(data);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email_address': emailAddress,
        'subject': subject,
        'sender': sender,
        'body': body,
        'received_at': receivedAt.toIso8601String(),
        'read': read,
      };
}