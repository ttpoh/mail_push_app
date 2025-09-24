import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/ui/uikit_bridge.dart';

class EmailCard extends StatelessWidget {
  final Email email;
  final VoidCallback onTap;
  const EmailCard({super.key, required this.email, required this.onTap});

  bool _isCritical(Email e) {
    final s = (e.subject + ' ' + e.body).toLowerCase();
    return s.contains('긴급') || s.contains('urgent') || s.contains('emergency');
  }

  @override
  Widget build(BuildContext context) {
    final r = UiKit.radiusLg(context);
    final isCritical = _isCritical(email);
    final brightness = Theme.of(context).brightness;

    return Container(
      decoration: BoxDecoration(
        color: UiKit.cardBg(context),
        borderRadius: BorderRadius.circular(r),
        boxShadow: UiKit.softShadow(brightness),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(r),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: UiKit.primary(context).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                email.read ? Icons.mail_outline : Icons.mail,
                color: UiKit.primary(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email.subject.isEmpty ? '제목 없음' : email.subject,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${email.sender} · ${DateFormat('yyyy-MM-dd HH:mm').format(email.receivedAt.add(const Duration(hours: 9)))}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: UiKit.subtleText(context),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: isCritical ? UiKit.danger(context) : UiKit.success(context),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
