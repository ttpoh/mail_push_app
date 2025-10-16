// mail_detail_page.dart
import 'package:flutter/material.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/l10n/app_localizations.dart';

class MailDetailPage extends StatefulWidget {
  final Email email;
  final FcmService fcm; // ← 주입

  const MailDetailPage({Key? key, required this.email, required this.fcm}) : super(key: key);

  @override
  State<MailDetailPage> createState() => _MailDetailPageState();
}

class _MailDetailPageState extends State<MailDetailPage> {
  bool _syncedOnce = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    try { await FcmService().isAlarmLoopRunning(); } catch (_) {}
    if (mounted) setState(() => _syncedOnce = true);
  }

  Future<void> _stopAlarm() async {
    final t = AppLocalizations.of(context)!;
    try {
      await FcmService().stopAlarmByUser();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.stopEmergencyAlarm)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('알람 중지 실패: $e')),
      );
    }
    await widget.fcm.stopAlarmByUser();

  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.email.subject ?? '제목 정보 없음';
    final body = widget.email.body ?? '본문 정보 없음';

    return Scaffold(
      backgroundColor: ec.eventLightBackgroundColor,
      appBar: AppBar(
        backgroundColor: ec.eventLightCardColor,
        elevation: 0,
        foregroundColor: ec.eventLightPrimaryTextColor,
        title: Text(
          subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: ec.eventLightPrimaryTextColor,
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: FcmService.loopRunning,
            builder: (context, running, _) {
              if (!_syncedOnce || !running) return const SizedBox.shrink();
              return IconButton(
                tooltip: '알람 중지',
                icon: const Icon(Icons.alarm_off_rounded),
                onPressed: _stopAlarm,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ec.eventLightCardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ec.eventLightBorderColor),
            boxShadow: [
              BoxShadow(
                color: ec.eventLightShadowColor,
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
                      color: ec.eventLightPrimaryTextColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '본문:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: ec.eventLightSecondaryTextColor,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: ec.eventLightSecondaryTextColor,
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
