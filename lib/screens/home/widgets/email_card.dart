import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/ui/uikit_bridge.dart';

class EmailCard extends StatelessWidget {
  final Email email;
  final VoidCallback onTap;

  /// 우측 점 색을 외부에서 지정할 수 있게(선택)
  final Color? dotColor;

  const EmailCard({
    super.key,
    required this.email,
    required this.onTap,
    this.dotColor,
  });

  bool _isCriticalHeuristic(Email e) {
    final s = (e.subject + ' ' + e.body).toLowerCase();
    return s.contains('긴급') || s.contains('urgent') || s.contains('emergency');
  }

  /// 서버가 내려준 실제 적용 등급(effectiveAlarm) → 규칙 등급(ruleAlarm) 순으로 읽기
  String? _alarmLevel(Email e) {
    try {
      final dyn = e as dynamic;
      final eff = dyn.effectiveAlarm ?? dyn.extra?['effectiveAlarm'];
      if (eff is String && eff.isNotEmpty) return eff;
      final rule = dyn.ruleAlarm ?? dyn.extra?['ruleAlarm'];
      if (rule is String && rule.isNotEmpty) return rule;
    } catch (_) {
      // Email 모델에 필드가 없을 수 있으므로 안전 폴백
    }
    return null;
  }

  Color _colorForLevel(BuildContext context, String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return Colors.orange;            // 1회 긴급
      case 'until':
        return UiKit.danger(context);    // 반복 긴급(빨강)
      case 'normal':
      default:
        return UiKit.success(context);   // 일반(초록)
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = UiKit.radiusLg(context);
    final brightness = Theme.of(context).brightness;

    // dotColor 우선 → effectiveAlarm(ruleAlarm 폴백) → 휴리스틱
    late final Color resolvedDot;
    if (dotColor != null) {
      resolvedDot = dotColor!;
    } else {
      final level = _alarmLevel(email);
      if (level != null) {
        resolvedDot = _colorForLevel(context, level);
      } else {
        resolvedDot = _isCriticalHeuristic(email)
            ? UiKit.danger(context)
            : UiKit.success(context);
      }
    }

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
              width: 36,
              height: 36,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${email.sender} · ${DateFormat('yyyy-MM-dd HH:mm').format(email.receivedAt.add(const Duration(hours: 9)))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: UiKit.subtleText(context),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: resolvedDot,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
