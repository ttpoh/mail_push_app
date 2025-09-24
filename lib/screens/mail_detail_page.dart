import 'package:flutter/material.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

class MailDetailPage extends StatelessWidget {
  final Email email;
  const MailDetailPage({Key? key, required this.email}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final subject = email.subject ?? '제목 정보 없음';
    final body    = email.body ?? '본문 정보 없음';

    return Scaffold(
      backgroundColor: ec.eventLightBackgroundColor,
      appBar: AppBar(
        backgroundColor: ec.eventLightCardColor,
        elevation: 0,
        foregroundColor: ec.eventLightPrimaryTextColor, // ✅ 라이트 전경
        title: Text(
          subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ec.eventLightPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity, // 전체 화면 너비
          decoration: BoxDecoration(
            color: ec.eventLightCardColor,                        // ✅ 라이트 카드
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ec.eventLightBorderColor),  // ✅ 라이트 보더
            boxShadow: [
              BoxShadow(
                color: ec.eventLightShadowColor,                  // ✅ 라이트 섀도우
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: ec.eventLightPrimaryTextColor,        // ✅ 본문 제목 색
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '본문:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: ec.eventLightSecondaryTextColor,       // ✅ 보조 텍스트
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ec.eventLightSecondaryTextColor,   // ✅ 본문 색
                          height: 1.5,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
