import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
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
import 'package:mail_push_app/screens/home/dialogs/alarm_settings_dialog.dart';
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;
import 'package:mail_push_app/device/alarm_setting_sync.dart';

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

  // iOS 네이티브 메일 이벤트 채널
  static const EventChannel _mailEventChannel =
      EventChannel('com.secure.mail_push_app/mail_event');
  StreamSubscription? _mailEventSub;

  bool _normalOn = true;
  bool _criticalOn = false;
  bool _criticalUntilStopped = false;

  String? _deviceId;
  String? _fcmToken;
  bool _syncing = false;
  late final AlarmSettingSync _alarmSync;

  /// messageId → 점 색상 (규칙 우선)
  final Map<String, Color> _alarmDotByMsgId = {};

  // inbox ValueNotifier 구독용 리스너 참조
  VoidCallback? _inboxListener;

  Color _colorForLevel(String? level) {
    switch ((level ?? 'normal').toLowerCase()) {
      case 'until':
        return Colors.red;
      case 'critical':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  final Set<String> _seenEventKeys = <String>{};
  static const int _maxSeen = 500;

  String _eventDedupeKey(Map<String, dynamic> ev, Map<String, dynamic>? md) {
    final mid = (ev['messageId'] ?? md?['messageId'] ?? '').toString();
    final ver = (ev['ruleVersion'] ?? md?['ruleVersion'] ?? 'v0').toString();
    // final ch  = (ev['pushChannel'] ?? md?['pushChannel'] ?? 'alert').toString();
    return '$mid:$ver';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔸 중복 파이프 제거를 위해 콜백 등록하지 않음
    // widget.fcmService.setOnNewEmailCallback(_onNewEmail);

    _initializeFcmAndLoadData();

    _alarmSync = AlarmSettingSync(api: widget.apiClient);
    _loadAlarmSettings();

    // ✅ FcmService.inbox 변화를 홈 리스트에 즉시 반영 (단일 파이프)
    _inboxListener = () {
      if (!mounted) return;
      final fromInbox = FcmService.inbox.value;
      if (fromInbox.isEmpty) return;

      final existing = _emails.map((e) => e.id).toSet();
      bool changed = false;
      for (final e in fromInbox) {
        if (e.id.isNotEmpty && !existing.contains(e.id)) {
          _emails.insert(0, e);
          existing.add(e.id);
          changed = true;
        }
      }
      if (changed) setState(() {});
    };
    FcmService.inbox.addListener(_inboxListener!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        widget.fcmService.ensureForegroundListeners?.call();
      } catch (_) {}
      _mailEventSub ??= _mailEventChannel
          .receiveBroadcastStream()
          .listen(_handleMailEvent, onError: (e) {
        debugPrint('❌ mail_event error: $e');
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mailEventSub?.cancel();
    _mailEventSub = null;

    if (_inboxListener != null) {
      FcmService.inbox.removeListener(_inboxListener!);
      _inboxListener = null;
    }
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
      debugPrint(
          '🧭 초기 업서트 완료 deviceId=$_deviceId, platform=${Platform.isIOS ? 'ios' : 'android'}');
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
      debugPrint(
          '🧭 이메일/알람 업서트 완료 email=$email normal=$_normalOn critical=$_criticalOn until=$_criticalUntilStopped');
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
    await _loadUserEmail();
    await _checkInitialMessage();
    if (!mounted) return;
    if (widget.authService.serviceName.toLowerCase() != 'icloud') {
      await _fetchAndSetEmails();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed &&
        widget.authService.serviceName.toLowerCase() != 'icloud') {
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

      // 서버 저장 등급을 점 색상 캐시에 반영 (규칙 우선)
      for (final e in emails) {
        final level = e.ruleAlarm ?? e.effectiveAlarm;
        if (level != null && e.id.isNotEmpty) {
          _alarmDotByMsgId[e.id] = _colorForLevel(level);
        }
      }

      debugPrint('📥 목록 동기화 완료: ${emails.length}건');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.emailLoadFailed('$e')),
        ),
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
      _criticalUntilStopped =
          prefs.getBool(_kCriticalUntilKey) ?? false;
    });
    debugPrint(
        '🔧 로컬 알람 설정: normal=$_normalOn, critical=$_criticalOn, until=$_criticalUntilStopped');
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

  // 새 메일 도착 시: 낙관적 prepend → 이후 증분 동기화
  Future<void> _onNewEmail(Email email) async {
    if (!mounted) return;

    // messageId 기준 색상 보강 (규칙 우선)
    try {
      final dyn = email as dynamic;
      final String? effective = dyn.effectiveAlarm ?? dyn.extra?['effectiveAlarm'];
      final String? ruleAlarm  = dyn.ruleAlarm ?? dyn.extra?['ruleAlarm'];
      final level = (ruleAlarm?.toString().isNotEmpty ?? false)
          ? ruleAlarm!.toString()
          : (effective?.toString() ?? 'normal');

      final String msgId = (dyn.messageId ?? email.id).toString();
      if (msgId.isNotEmpty) {
        _alarmDotByMsgId[msgId] = _colorForLevel(level);
      }
    } catch (_) {}

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

      DateTime? newest =
          _emails.isNotEmpty ? _emails.first.receivedAt : null;
      final sinceIso = newest != null
          ? newest
              .toUtc()
              .subtract(const Duration(seconds: 2))
              .toIso8601String()
          : null;

      final fetched = sinceIso != null
          ? await widget.apiClient
              .fetchEmails(service, emailAddress, since: sinceIso)
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
      debugPrint('🔗 증분 동기화 완료');
    } catch (e) {
      debugPrint('❌ _onNewEmail 동기화 실패: $e');
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  // iOS EventChannel 수신 → sender/received_at 우선 사용 + 색상 캐싱
  void _handleMailEvent(dynamic event) {
    if (event is! Map) return;
    final ev = Map<String, dynamic>.from(event as Map);
    debugPrint('📡 이벤트 수신: $ev');

    // mailData: Map 또는 String(JSON) 모두 안전 파싱
    Map<String, dynamic>? md;
    final rawMd = ev['mailData'];
    if (rawMd is Map) {
      md = Map<String, dynamic>.from(rawMd);
    } else if (rawMd is String) {
      try { md = Map<String, dynamic>.from(jsonDecode(rawMd)); } catch (_) {}
    }
    final key = _eventDedupeKey(ev, md);
    if (key.isNotEmpty) {
      if (_seenEventKeys.contains(key)) {
        debugPrint('🚫 (Dart) EC duplicate: $key');
        return;
      }
      _seenEventKeys.add(key);
      if (_seenEventKeys.length > _maxSeen) {
        // 아주 단순한 LRU-ish 정리
        _seenEventKeys.remove(_seenEventKeys.first);
      }
    }

    // 1) 규칙/유효 알람 둘 다 보존
    final String? ruleAlarm =
        (ev['ruleAlarm'] as String?) ?? (md?['ruleAlarm'] as String?);
    final String? effectiveAlarm =
        (ev['effectiveAlarm'] as String?) ?? (md?['effectiveAlarm'] as String?);

    // 2) 표시 레벨: 규칙 우선 → effective → normal
    final String showLevel = (ruleAlarm != null && ruleAlarm.isNotEmpty)
        ? ruleAlarm
        : (effectiveAlarm ?? 'normal');

    // 3) 점 색상 캐시 업데이트 (규칙 우선 표시 기준 사용)
    try {
      final msgId = (ev['messageId']?.toString()) ??
          (md?['messageId']?.toString()) ??
          DateTime.now().millisecondsSinceEpoch.toString();
      _alarmDotByMsgId[msgId] = _colorForLevel(showLevel);
    } catch (_) {}

    // 4) sender 파싱(메일데이터 우선 → 이벤트 상위 → 폴백)
    String sender = (md?['sender'] as String? ?? ev['sender'] as String? ?? '').trim();
    if (sender.isEmpty) {
      final subj = (md?['subject'] as String?) ?? (ev['subject'] as String?) ?? '';
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

    // 5) subject/email_address/received_at 등 폴백 계층 정리 (mailData 우선)
    final normalized = <String, dynamic>{
      // ✅ 메일 고유 ID 우선 사용
      'messageId': (md?['message_id']?.toString()) ??
                  (md?['messageId']?.toString()) ??
                  (ev['messageId']?.toString()) ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
      'email_address': (md?['email_address'] as String?) ??
          (ev['email_address'] as String?) ??
          (_userEmail ?? ''),
      'subject': (md?['subject'] as String?) ??
          (ev['subject'] as String?) ??
          AppLocalizations.of(context)!.noSubject,
      'sender': sender,
      'body': (md?['body'] as String?) ?? (ev['body'] as String?) ?? '',
      'received_at': (md?['received_at']?.toString()) ??
          (ev['received_at']?.toString()) ??
          DateTime.now().toUtc().toIso8601String(),
      'read': (md?['read']) ?? (ev['read']) ?? false,

      'ruleAlarm': ruleAlarm ?? '',
      'effectiveAlarm': effectiveAlarm ?? '',
    };

    try {
      final email = Email.fromJson(normalized);
        // 2) 보강: id와 messageId를 동일하게(=normalized['messageId'])
      final fixedId = normalized['messageId']!.toString();
      final emailFixed = email.id == fixedId ? email : email.copyWith(id: fixedId);

      // 3) (선택) 동일 메일 콘텐츠지만 과거 잘못된 ID(FCM ID)로 들어온 중복을 정리
      _emails.removeWhere((e) =>
        e.emailAddress == emailFixed.emailAddress &&
        e.subject == emailFixed.subject &&
        e.sender == emailFixed.sender &&
        e.body == emailFixed.body &&
        e.id != fixedId
      );
      // [CHANGED] EventChannel → FcmService 단일 파이프로 합치기
      widget.fcmService.emitEmailDirect(email);
      // (이전에는 _onNewEmail(email) 를 직접 호출 → 중복 경로 생성)
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
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.logoutFailed('$e'))),
      );
    }
  }

  void _openAlarmDialog() async {
    await widget.fcmService.isAlarmLoopRunning();

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
      onStopAlarm: () async {
        try {
          await widget.fcmService.stopAlarmByUser();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('긴급 알람을 중지했습니다')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('알람 중지 실패: $e')),
            );
          }
        }
      },
    );
  }

  void _openRules() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RuleListPage()));
  }

  Future<void> _openEmail(Email email, int index) async {
    if (!email.read) {
      setState(() {
        _emails[index] = email.copyWith(read: true);
      });

      try {
        final service = widget.authService.serviceName.toLowerCase();
        final owner = await widget.authService.getCurrentUserEmail();
        if (owner != null && owner.isNotEmpty) {
          await widget.apiClient.markEmailRead(
            service: service,
            emailAddress: owner,
            messageId: email.id,
            read: true,
          );
        }
      } catch (e) {
        debugPrint('markEmailRead failed: $e');
      }
    }

    try {
      await widget.fcmService.stopAlarmByUser();
    } catch (_) {}

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
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: ec.eventLightSecondaryTextColor,
                              ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: EmailList(
                        key: ValueKey(_emails.length),
                        emails: _emails,
                        onOpenEmail: _openEmail,
                        // ✅ 점 색상: 캐시 우선 → 규칙 우선 → 기본
                        dotColorResolver: (email) {
                          final cached = _alarmDotByMsgId[email.id];
                          if (cached != null) return cached;
                          final level = email.ruleAlarm ?? email.effectiveAlarm ?? 'normal';
                          return _colorForLevel(level);
                        },
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
