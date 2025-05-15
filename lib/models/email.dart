class Email {
  final String id; // 추가된 id 필드
  final String subject;
  final String body;
  bool isNew;

  Email({
    required this.id,
    required this.subject,
    required this.body,
    this.isNew = true,
  });

  @override
  String toString() {
    return 'Email(id: $id, subject: $subject, body: $body, isNew: $isNew)';
  }
}