import 'package:flutter/material.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/screens/home/widgets/email_card.dart';

class EmailList extends StatelessWidget {
  final List<Email> emails;
  final void Function(Email email, int index) onOpenEmail;

  /// 각 이메일의 점 색을 정하는 선택 콜백 (없으면 카드가 기본 로직 사용)
  final Color Function(Email email)? dotColorResolver;

  const EmailList({
    super.key,
    required this.emails,
    required this.onOpenEmail,
    this.dotColorResolver,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: emails.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final email = emails[i];
        final dot = dotColorResolver?.call(email);
        return EmailCard(
          email: email,
          onTap: () => onOpenEmail(email, i),
          dotColor: dot, // 전달(없으면 카드가 자체 판단)
        );
      },
    );
  }
}
