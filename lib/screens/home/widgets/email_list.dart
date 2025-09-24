import 'package:flutter/material.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/screens/home/widgets/email_card.dart';

class EmailList extends StatelessWidget {
  final List<Email> emails;
  final void Function(Email email, int index) onOpenEmail;

  const EmailList({
    super.key,
    required this.emails,
    required this.onOpenEmail,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: emails.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final email = emails[i];
        return EmailCard(
          email: email,
          onTap: () => onOpenEmail(email, i),
        );
      },
    );
  }
}
