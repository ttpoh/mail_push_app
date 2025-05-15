import 'package:flutter/material.dart';
import 'package:mail_push_app/models/email.dart';

class MailDetailPage extends StatelessWidget {
  final Email email;

  const MailDetailPage({Key? key, required this.email}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 기본값 설정
    final subject = email.subject ?? '제목 정보 없음';
    final body    = email.body    ?? '본문 정보 없음';

    return Scaffold(
      appBar: AppBar(
        title: Text(subject),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '본문:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  body,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
