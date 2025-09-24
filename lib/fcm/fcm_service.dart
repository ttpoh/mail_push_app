import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/utils/navigation_service.dart';

class AlarmSettingsStore {
  static const _kCriticalOn = 'criticalOn';
  static const _kLastMsgId = 'last_message_id';

  static Future<void> setCriticalOn(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kCriticalOn, v);
  }

  static Future<bool> getCriticalOn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kCriticalOn) ?? true;
  }

  static Future<bool> isDuplicateAndMark(String id) async {
    if (id.isEmpty) return true;
    final sp = await SharedPreferences.getInstance();
    final last = sp.getString(_kLastMsgId);
    if (last == id) return true;
    await sp.setString(_kLastMsgId, id);
    if (Platform.isIOS) {
      try {
        await const MethodChannel('com.secure.mail_push_app/sync').invokeMethod('syncMessageId', {'id': id});
      } catch (e) {
        debugPrint('❌ Failed to sync message ID with native: $e');
      }
    }
    return false;
  }
}

class _AlarmLoopState {
  static bool running = false;
}

class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Function(Email)? _onNewEmailCallback;
  bool _initialized = false;

  static const String _chGeneralId = 'mail_general';
  static const String _chGeneralName = 'General Mail';
  static const String _chCriticalId = 'mail_critical';
  static const String _chCriticalName = 'Critical Mail';

  static const MethodChannel _alarmLoopChannel =
      MethodChannel('com.secure.mail_push_app/alarm_loop');

  Future<RemoteMessage?> getInitialMessage() async {
    return await _fcm.getInitialMessage();
  }

  void handleNewEmail(RemoteMessage message) {
    _handleNewEmail(message);
  }

  void setOnNewEmailCallback(Function(Email) cb) {
    _onNewEmailCallback = cb;
    debugPrint('✅ setOnNewEmailCallback registered');
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ 알림 권한 거부됨');
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(requestCriticalPermission: true);
    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) async {
        debugPrint('👆 알림 클릭됨 → 루프 stop & 상세 진입');
        await _stopLoop();
        if (details.payload != null) {
          _navigateToDetailFromPayload(details.payload!);
        } else {
          NavigationService.instance.navigateTo('/home');
        }
      },
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        _chGeneralId, _chGeneralName,
        description: 'General (no sound)',
        importance: Importance.defaultImportance,
        playSound: false, enableVibration: false,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        _chCriticalId, _chCriticalName,
        description: 'Critical (with sound)',
        importance: Importance.max,
        playSound: true, enableVibration: true,
      ));
    }

    FirebaseMessaging.onMessage.listen((msg) async {
      debugPrint('🔔 포그라운드 메시지 수신: ${msg.messageId}');
      if (!await _shouldProcess(msg)) return;
      await _showNotification(msg);
      _handleNewEmail(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
      debugPrint('🔔 메시지 클릭으로 앱 열림: ${msg.messageId}');
      if (!await _shouldProcess(msg)) return;
      _handleNewEmail(msg);
      await _stopLoop();
      _navigateToDetail(msg);
    });

    final initialMsg = await getInitialMessage();
    if (initialMsg != null) {
      debugPrint('🔔 초기 메시지 처리: ${initialMsg.messageId}');
      if (await _shouldProcess(initialMsg)) {
        _handleNewEmail(initialMsg);
        await _stopLoop();
        _navigateToDetail(initialMsg);
      }
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _initialized = true;
    debugPrint('✅ FcmService 초기화 완료');
  }

  Map<String, String> _buildTtsForLocale({String? subject, String? body}) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final langCode = locale.languageCode.toLowerCase();

    const defaultTexts = {
      'ko': '긴급 메일이 도착했습니다',
      'ja': '緊急メールが届きました',
      'en': 'An emergency email has arrived',
      'zh': '您收到紧急邮件',
    };

    const ttsLangMap = {
      'ko': 'ko-KR', 'ja': 'ja-JP', 'en': 'en-US', 'zh': 'zh-CN',
    };

    String pickText(String lang) {
      final s = (subject ?? '');
      final b = (body ?? '');
      final hasMeeting = s.contains('미팅') || b.contains('미팅');
      if (hasMeeting) {
        switch (lang) {
          case 'ko': return '미팅 관련 메일이 도착했습니다';
          case 'ja': return 'ミーティングのメールが届きました';
          case 'zh': return '您收到会议相关邮件';
          default:   return 'A meeting-related email has arrived';
        }
      }
      return defaultTexts[lang] ?? defaultTexts['en']!;
    }

    final langKey = ttsLangMap.containsKey(langCode) ? langCode : 'en';
    return {'text': pickText(langKey), 'lang': ttsLangMap[langKey]!};
  }

  Future<bool> _shouldProcess(RemoteMessage message) async {
    final data = message.data;

    if (data['ruleMatched'] != 'true') {
      debugPrint('🚫 ruleMatched=false → 무시');
      return false;
    }

    final messageId = (data['messageId'] ?? message.messageId ?? '').toString();
    if (messageId.isEmpty) {
      debugPrint('🚫 messageId 누락 → 무시');
      return false;
    }

    final dup = await AlarmSettingsStore.isDuplicateAndMark(messageId);
    if (dup) {
      debugPrint('🚫 중복 messageId=$messageId → 무시');
      return false;
    }

    final mailData = data['mailData'];
    if (mailData == null) {
      debugPrint('🚫 mailData 없음 → 무시');
      return false;
    }
    try {
      jsonDecode(mailData);
    } catch (_) {
      debugPrint('🚫 mailData 파싱 실패 → 무시');
      return false;
    }

    return true;
  }

  void _handleNewEmail(RemoteMessage message) {
    final data = message.data;
    final mailJson = data['mailData'];
    if (mailJson == null) return;

    final mail = Email.fromJsonString(mailJson);
    _onNewEmailCallback?.call(mail);
    debugPrint('📬 onNewEmail callback: ${mail.subject} / ${mail.sender}');
  }

  Future<void> _showNotification(RemoteMessage msg) async {
    debugPrint('🔔 _showNotification 진입');

    final data = msg.data;
    final mailMap = data['mailData'] != null ? jsonDecode(data['mailData']) : null;
    final subject = mailMap?['subject'] ?? msg.notification?.title ?? '새 이메일';
    final sender = mailMap?['sender'] ?? data['sender'] ?? 'Unknown Sender';

    final serverCritical = data['isCritical'] == 'true';
    final allowCritical = await AlarmSettingsStore.getCriticalOn();
    final effectiveCritical = serverCritical && allowCritical;
    final criticalUntil = (data['criticalUntil']?.toString().toLowerCase() == 'true');

    debugPrint('🔎 flags: serverCritical=$serverCritical, allowCritical=$allowCritical, '
        'effective=$effectiveCritical, until=$criticalUntil');

    final androidDetails = AndroidNotificationDetails(
      effectiveCritical ? _chCriticalId : _chGeneralId,
      effectiveCritical ? _chCriticalName : _chGeneralName,
      importance: effectiveCritical ? Importance.max : Importance.defaultImportance,
      priority: effectiveCritical ? Priority.high : Priority.defaultPriority,
      playSound: effectiveCritical,
    );

    // iOS는 알림 사운드는 APNs가 담당(once일 때만). 여기서는 소리 끔.
    const iosDetails = DarwinNotificationDetails(presentSound: false);
    final nd = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final id = (data['messageId'] ?? msg.messageId ?? '').hashCode;
    await _notificationsPlugin.show(
      id,
      subject,
      'From: $sender',
      nd,
      payload: jsonEncode(data),
    );
    debugPrint('🧾 로컬 알림 표시 (id=$id)');

    await _startLoopIfNeeded(data);
  }

  Future<void> _startLoopIfNeeded(Map<String, dynamic> data) async {
    if (_AlarmLoopState.running) {
      debugPrint('🚫 loop already running (skip)');
      return;
    }
    final rawUntil = data['criticalUntil'];
    final criticalUntil = (rawUntil is bool && rawUntil == true) ||
        (rawUntil is String && rawUntil.toLowerCase() == 'true');

    final serverCritical = data['isCritical'] == 'true';
    final allowCritical = await AlarmSettingsStore.getCriticalOn();
    final effectiveCritical = serverCritical && allowCritical;

    debugPrint('🧪 loop check: serverCritical=$serverCritical, allowCritical=$allowCritical, criticalUntil=$criticalUntil');

    // 🔑 하이브리드 핵심:
    // loop(criticalUntil=true)일 때만 로컬 사이렌/tts 시작.
    if (!effectiveCritical || !criticalUntil) {
      debugPrint('🧪 loop skip: effectiveCritical=$effectiveCritical, criticalUntil=$criticalUntil');
      return;
    }

    String? subject, body;
    try {
      final mailMap = data['mailData'] != null ? jsonDecode(data['mailData']) : {};
      subject = (mailMap['subject'] ?? '').toString();
      body = (mailMap['body'] ?? '').toString();
    } catch (_) {}

    final tts = _buildTtsForLocale(subject: subject, body: body);
    final ttsText = tts['text']!;
    final ttsLang = tts['lang']!;

    try {
      const mode = 'loop';
      debugPrint('🧪 invoking alarm_loop.start… text="$ttsText", lang=$ttsLang, mode=$mode');
      await _alarmLoopChannel.invokeMethod('start', {'text': ttsText, 'lang': ttsLang, 'mode': mode});
      _AlarmLoopState.running = true;
      debugPrint('🚨 alarm loop started ($ttsLang): $ttsText (mode=$mode)');
    } catch (e) {
      debugPrint('❌ alarm loop start failed: $e');
    }
  }

  Future<void> _stopLoop() async {
    if (!_AlarmLoopState.running) return;
    try {
      await _alarmLoopChannel.invokeMethod('stop');
      debugPrint('🛑 alarm loop stopped');
    } catch (e) {
      debugPrint('❌ alarm loop stop failed: $e');
    }
    _AlarmLoopState.running = false;
  }

  Future<void> stopAlarmByUser() async {
    await _stopLoop();
  }

  void _navigateToDetail(RemoteMessage message) {
    final data = message.data;
    final mailMap = data['mailData'] != null ? jsonDecode(data['mailData']) : <String, dynamic>{};
    final email = Email(
      id: data['messageId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      emailAddress: mailMap['email_address'] ?? '',
      subject: mailMap['subject'] ?? data['subject'] ?? '',
      sender: mailMap['sender'] ?? data['sender'] ?? 'Unknown Sender',
      body: mailMap['body'] ?? data['body'] ?? '',
      receivedAt: mailMap['received_at'] != null
          ? DateTime.parse(mailMap['received_at'])
          : DateTime.now(),
      read: false,
    );
    NavigationService.instance.navigateTo('/mail_detail', arguments: email);
    debugPrint('🔔 디테일 페이지로 이동: ${email.id}');
  }

  void _navigateToDetailFromPayload(String payload) {
    final data = jsonDecode(payload);
    final mailMap = data['mailData'] != null ? jsonDecode(data['mailData']) : <String, dynamic>{};
    final email = Email(
      id: data['messageId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      subject: mailMap['subject'] ?? data['subject'] ?? '',
      sender: mailMap['sender'] ?? data['sender'] ?? 'Unknown Sender',
      body: mailMap['body'] ?? data['body'] ?? '',
      emailAddress: mailMap['email_address'] ?? '',
      receivedAt: mailMap['received_at'] != null
          ? DateTime.parse(mailMap['received_at'])
          : DateTime.now(),
      read: false,
    );
    NavigationService.instance.navigateTo('/mail_detail', arguments: email);
    debugPrint('🔔 페이로드에서 디테일 페이지로 이동: ${email.id}');
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 백그라운드 알림 수신(data): ${message.data}');
  final data = message.data;
  if (data['ruleMatched'] != 'true') return;
  final mid = (data['messageId'] ?? message.messageId ?? '').toString();
  if (mid.isEmpty) return;
  final dup = await AlarmSettingsStore.isDuplicateAndMark(mid);
  if (dup) return;

  final serverCritical = data['isCritical'] == 'true';
  final allowCritical = await AlarmSettingsStore.getCriticalOn();
  final effectiveCritical = serverCritical && allowCritical;

  final mail = data['mailData'] != null ? jsonDecode(data['mailData']) : {};
  final subject = mail['subject'] ?? '새 이메일';
  final sender = mail['sender'] ?? 'Unknown Sender';

  final plugin = FlutterLocalNotificationsPlugin();
  final androidDetails = AndroidNotificationDetails(
    effectiveCritical ? FcmService._chCriticalId : FcmService._chGeneralId,
    effectiveCritical ? FcmService._chCriticalName : FcmService._chGeneralName,
    importance: effectiveCritical ? Importance.max : Importance.high,
    playSound: effectiveCritical,
  );
  const iosDetails = DarwinNotificationDetails(presentSound: false);
  final nd = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await plugin.show(
    mid.hashCode,
    subject,
    'From: $sender',
    nd,
    payload: jsonEncode(data),
  );
  debugPrint('🔔 백그라운드 알림 표시 (critical=$effectiveCritical)');

  // 🔑 loop일 때만 로컬 사이렌/tts 실행
  await FcmService()._startLoopIfNeeded(data);
}
