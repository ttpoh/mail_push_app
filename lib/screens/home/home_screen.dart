import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mail_push_app/auth/auth_service.dart';
import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/menu/rule_list_page.dart';
import 'package:mail_push_app/l10n/app_localizations.dart';

import 'widgets/gf_home_app_bar.dart';
import 'widgets/email_list.dart';
// ⚠️ 중복 import 제거: 아래 경로 하나만 유지하세요.
import 'package:mail_push_app/screens/home/dialogs/alarm_settings_dialog.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import 'package:mail_push_app/device/alarm_setting_sync.dart';

/// 공통 라이트 카드
class AppCard extends StatelessWidget {
  final Widget child;
  const AppCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: child,
    );
  }
}

class HomeScreen extends StatefulWidget {
  final AuthService authService;
  final FcmService fcmService;
  final ApiClient apiClient;
  final void Function(Locale)? onChangeLocale;

  const HomeScreen({
    super.key,
    required this.authService,
    required this.fcmService,
    required this.apiClient,
    this.onChangeLocale,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<Email> _emails = [];
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _userEmail;
  bool _isFetching = false;

  static const _kNormalOnKey = 'alarm_normal_on';
  static const _kCriticalOnKey = 'alarm_critical_on';
  static const _kCriticalUntilKey = 'alarm_critical_until_stopped';

  bool _normalOn = true;
  bool _criticalOn = false;
  bool _criticalUntilStopped = false;

  static const EventChannel _mailEventChannel =
      EventChannel('com.secure.mail_push_app/mail_events');

  bool get _isICloud =>
      widget.authService.serviceName.toLowerCase() == 'icloud';

  String? _deviceId;
  String? _fcmToken;
  bool _syncing = false;
  late final AlarmSettingSync _alarmSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAlarmSettings();
    _initializeFcmAndLoadData();
    _alarmSync = AlarmSettingSync(api: widget.apiClient);

    _mailEventChannel.receiveBroadcastStream().listen(
      _handleMailEvent,
      onError: (error) => debugPrint('🔔 EventChannel 오류: $error'),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _upsertInitialDevice() async {
    try {
      final devId = await _secureStorage.read(key: 'device_id');
      if (devId == null || devId.isEmpty) return;
      _deviceId = devId;

      _fcmToken ??= await FirebaseMessaging.instance.getToken();

      await widget.apiClient.upsertAlarmSetting(
        deviceId: _deviceId!,
        platform: Platform.isIOS ? 'ios' : 'android',
        fcmToken: _fcmToken,
      );
      debugPrint('🧭 초기 업서트 완료 deviceId=$_deviceId, platform=${Platform.isIOS ? 'ios' : 'android'}');
    } catch (e) {
      debugPrint('⚠️ _upsertInitialDevice 실패: $e');
    }
  }

  Future<void> _upsertEmailAndFlags() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final devId = _deviceId ?? await _secureStorage.read(key: 'device_id');
      if (devId == null || devId.isEmpty) return;
      _deviceId = devId;

      final email = await widget.authService.getCurrentUserEmail();
      if (email == null || email.isEmpty) {
        _syncing = false;
        return;
      }

      _fcmToken ??= await FirebaseMessaging.instance.getToken();

      await widget.apiClient.upsertAlarmSetting(
        deviceId: _deviceId!,
        emailAddress: email,
        fcmToken: _fcmToken,
        normalOn: _normalOn,
        criticalOn: _criticalOn,
        criticalUntilStopped: _criticalUntilStopped,
      );
      debugPrint('🧭 이메일/알람 업서트 완료 email=$email normal=$_normalOn critical=$_criticalOn until=$_criticalUntilStopped');
    } catch (e) {
      debugPrint('⚠️ _upsertEmailAndFlags 실패: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _initializeFcmAndLoadData() async {
    try {
      await widget.fcmService.initialize();
      _fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('✅ FCM init ok, token=$_fcmToken');
    } catch (e) {
      debugPrint('⚠️ FCM 초기화 실패: $e');
    }

    await _upsertInitialDevice();

    widget.fcmService.setOnNewEmailCallback(_onNewEmail);
    await _loadUserEmail();
    await _checkInitialMessage();
    if (!_isICloud) await _fetchAndSetEmails();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_isICloud) {
      _fetchAndSetEmails();
    }
  }

  Future<void> _loadUserEmail() async {
    final email = await widget.authService.getCurrentUserEmail();
    if (!mounted) return;
    setState(() {
      _userEmail = email;
    });
    debugPrint('👤 로그인 이메일: $_userEmail');

    if (email != null && email.isNotEmpty) {
      await _upsertEmailAndFlags();
    }
  }

  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await widget.fcmService.getInitialMessage();
      if (initialMessage != null) {
        widget.fcmService.handleNewEmail(initialMessage);
      }
    } catch (e) {
      debugPrint('⚠️ 초기 메시지 실패: $e');
    }
  }

  Future<void> _fetchAndSetEmails() async {
    if (_isFetching) return;
    setState(() => _isFetching = true);
    try {
      final service = widget.authService.serviceName.toLowerCase();
      final emailAddress = await widget.authService.getCurrentUserEmail();
      if (emailAddress == null || emailAddress.isEmpty) {
        throw Exception(AppLocalizations.of(context)!.noLoggedInEmail);
      }
      final emails = await widget.apiClient.fetchEmails(service, emailAddress);
      if (!mounted) return;
      setState(() {
        _emails
          ..clear()
          ..addAll(emails);
      });
      debugPrint('📥 목록 동기화 완료: ${emails.length}건');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.emailLoadFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  Future<void> _loadAlarmSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _normalOn = prefs.getBool(_kNormalOnKey) ?? true;
      _criticalOn = prefs.getBool(_kCriticalOnKey) ?? false;
      _criticalUntilStopped = prefs.getBool(_kCriticalUntilKey) ?? false;
    });
    debugPrint('🔧 로컬 알람 설정: normal=$_normalOn, critical=$_criticalOn, until=$_criticalUntilStopped');
  }

  Future<void> _persistSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNormalOnKey, _normalOn);
    await prefs.setBool(_kCriticalOnKey, _criticalOn);
    await prefs.setBool(_kCriticalUntilKey, _criticalUntilStopped);
    debugPrint('💾 설정 저장');
  }

  Future<void> _openAppNotificationSettings() async {
    final t = AppLocalizations.of(context)!;
    try {
      if (Platform.isAndroid) {
        final info = await PackageInfo.fromPlatform();
        final intent = AndroidIntent(
          action: 'android.settings.APP_NOTIFICATION_SETTINGS',
          arguments: <String, dynamic>{
            'android.provider.extra.APP_PACKAGE': info.packageName,
            'app_package': info.packageName,
            'app_uid': 0,
          },
        );
        await intent.launch();
      } else if (Platform.isIOS) {
        await openAppSettings();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.settingsOpenError)),
      );
    }
  }

  // 새 메일 도착 시: 낙관적 prepend 후 증분 동기화
  Future<void> _onNewEmail(Email email) async {
    if (!mounted) return;

    final currentEmail = _userEmail;
    if (currentEmail != null &&
        email.emailAddress.isNotEmpty &&
        email.emailAddress != currentEmail) {
      debugPrint('↩️ 다른 계정 메일 무시: ${email.emailAddress}');
      return;
    }

    setState(() {
      _emails.removeWhere((e) => e.id == email.id);
      _emails.insert(0, email);
    });
    debugPrint('➕ 낙관적 삽입: ${email.subject} / ${email.sender}');

    if (_isFetching) return;
    setState(() => _isFetching = true);

    try {
      final service = widget.authService.serviceName.toLowerCase();
      final emailAddress = await widget.authService.getCurrentUserEmail();
      if (emailAddress == null || emailAddress.isEmpty) return;

      DateTime? newest = _emails.isNotEmpty ? _emails.first.receivedAt : null;
      final sinceIso = newest != null
          ? newest.toUtc().subtract(const Duration(seconds: 2)).toIso8601String()
          : null;

      final fetched = sinceIso != null
          ? await widget.apiClient.fetchEmails(service, emailAddress, since: sinceIso)
          : await widget.apiClient.fetchEmails(service, emailAddress);

      final existingIds = _emails.map((e) => e.id).toSet();
      final merged = <Email>[];
      for (final em in fetched) {
        if (!existingIds.contains(em.id)) merged.add(em);
      }
      merged.addAll(_emails);

      if (!mounted) return;
      setState(() {
        _emails
          ..clear()
          ..addAll(merged);
      });
      debugPrint('🔗 증분 동기화 완료(+${merged.length - _emails.length})');
    } catch (e) {
      debugPrint('❌ _onNewEmail 동기화 실패: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  // iOS EventChannel 수신 → sender/received_at 우선 사용
  void _handleMailEvent(dynamic event) {
    if (event is! Map) return;
    final mailData = Map<String, dynamic>.from(event as Map);
    debugPrint('📡 이벤트 수신: $mailData');

    // sender 우선 사용, 없으면 subject에서 fallback
    String sender = (mailData['sender'] as String?)?.trim() ?? '';
    if (sender.isEmpty) {
      final subj = (mailData['subject'] as String?) ?? '';
      final m = RegExp(r'^"([^"]+)"\s+<([^>]+)>\s*-').firstMatch(subj);
      if (m != null) {
        final name = m.group(1) ?? '';
        final email = m.group(2) ?? '';
        sender = (name.isNotEmpty && email.isNotEmpty)
            ? '$name <$email>'
            : (name.isNotEmpty ? name : (email.isNotEmpty ? email : AppLocalizations.of(context)!.unknownSender));
      } else {
        sender = AppLocalizations.of(context)!.unknownSender;
      }
    }

    final normalized = {
      'messageId': mailData['messageId']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      'email_address': (mailData['email_address'] as String?) ?? (_userEmail ?? ''),
      'subject': (mailData['subject'] as String?) ?? AppLocalizations.of(context)!.noSubject,
      'sender': sender,
      'body': (mailData['body'] as String?) ?? '',
      'received_at': (mailData['received_at']?.toString()) ??
          DateTime.now().toUtc().toIso8601String(),
      'read': mailData['read'] ?? false,
    };

    try {
      final email = Email.fromJson(normalized);
      _onNewEmail(email);
    } catch (e) {
      debugPrint('❌ 메일 이벤트 파싱 오류: $e');
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await widget.authService.signOut();
      await _secureStorage.delete(key: 'fcm_token');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.logoutFailed('$e'))),
      );
    }
  }

  void _openAlarmDialog() {
    showAlarmSettingsDialog(
      context: context,
      normalOn: _normalOn,
      criticalOn: _criticalOn,
      criticalUntilStopped: _criticalUntilStopped,
      sync: _alarmSync,
      onNormalChanged: (v) async {
        setState(() => _normalOn = v);
        await _persistSettings();
        await _upsertEmailAndFlags();
      },
      onCriticalChanged: (v) async {
        setState(() => _criticalOn = v);
        await _persistSettings();
        await _upsertEmailAndFlags();
      },
      onCriticalUntilChanged: (v) async {
        setState(() => _criticalUntilStopped = v);
        await _persistSettings();
        await _upsertEmailAndFlags();
      },
      onOpenAppNotificationSettings: _openAppNotificationSettings,
    );
  }

  void _openRules() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RuleListPage()));
  }

  Future<void> _openEmail(Email email, int index) async {
    if (!email.read) {
      setState(() {
        _emails[index] = Email(
          id: email.id,
          emailAddress: email.emailAddress,
          subject: email.subject,
          sender: email.sender,
          body: email.body,
          receivedAt: email.receivedAt,
          read: true,
        );
      });
    }

    try {
      await widget.fcmService.stopAlarmByUser();
    } catch (e) {
      debugPrint('stopAlarmByUser failed: $e');
    }

    if (!mounted) return;
    Navigator.pushNamed(context, '/mail_detail', arguments: email);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final title = _userEmail ?? widget.authService.serviceName;

    return Scaffold(
      backgroundColor: ec.eventLightBackgroundColor,
      appBar: GfHomeAppBar(
        title: title,
        onRefresh: _fetchAndSetEmails,
        onOpenAlarmSettings: _openAlarmDialog,
        onOpenRules: _openRules,
        onLogout: _logout,
        onChangeLocale: (loc) => widget.onChangeLocale?.call(loc),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: AppCard(
              child: _emails.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          t.waitingNewEmails,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: ec.eventLightSecondaryTextColor,
                              ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: EmailList(
                        emails: _emails,
                        onOpenEmail: _openEmail,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
