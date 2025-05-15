import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/utils/navigation_service.dart';
import 'package:flutter/services.dart';

/// FCM 서비스: 로컬 알림, TTS, 네비게이션 처리
class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Function(Email)? _onNewEmailCallback;
  bool _initialized = false;

  // 중복 TTS 방지를 위한 메시지 ID 캐시
  final Set<String> _spokenMessageIds = {};

  // 네이티브 TTS 호출을 위한 MethodChannel
  static const _ttsChannel = MethodChannel('com.secure.mail_push_app/tts');

  /// 앱 시작 시 종료 상태의 FCM 메시지를 가져옵니다.
  Future<RemoteMessage?> getInitialMessage() async {
    return await _fcm.getInitialMessage();
  }

  /// 외부(예: HomeScreen)에서 직접 새 메일 처리를 트리거할 때 사용합니다.
  void handleNewEmail(RemoteMessage message) {
    _handleNewEmail(message);
  }

  /// HomeScreen 등 외부에서 새 메일 콜백 등록
  void setOnNewEmailCallback(Function(Email) cb) => _onNewEmailCallback = cb;

  /// 서비스 초기화
  Future<void> initialize() async {
    if (_initialized) return;

    // 1) 알림 권한 요청
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ 알림 권한 거부됨');
      return;
    }

    // 2) 로컬 알림 플러그인 초기화
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(requestCriticalPermission: true);
    await _notificationsPlugin.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _navigateToDetailFromPayload(details.payload!);
        } else {
          NavigationService.instance.navigateTo('/home');
        }
      },
    );

    // 3) 포그라운드 메시지 처리
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('🔔 포그라운드 메시지 수신: ${msg.messageId}');
      _showNotification(msg);
      _handleNewEmail(msg);
    });

    // 4) 백그라운드 메시지 클릭 처리
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('🔔 메시지 클릭으로 앱 열림: ${msg.messageId}');
      _handleNewEmail(msg);
      _navigateToDetail(msg);
    });

    // 5) 앱 종료 상태에서 알림 클릭으로 시작된 경우
    final initialMsg = await getInitialMessage();
    if (initialMsg != null) {
      debugPrint('🔔 초기 메시지 처리: ${initialMsg.messageId}');
      _handleNewEmail(initialMsg);
      _navigateToDetail(initialMsg);
    }

    // 6) 백그라운드 메시지 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _initialized = true;
    debugPrint('✅ FcmService 초기화 완료');
  }

  /// 실제 메일 데이터 파싱 및 콜백 실행
  void _handleNewEmail(RemoteMessage message) {
    final msgId = message.messageId ?? '';
    if (msgId.isEmpty) {
      debugPrint('❌ 메시지 ID 누락');
      return;
    }

    final mail = message.data['mailData'] != null
        ? jsonDecode(message.data['mailData'])
        : null;
    final subject = mail?['subject'] ??
        message.notification?.title ??
        message.data['subject'] ??
        '';
    final body = mail?['body'] ??
        message.notification?.body ??
        message.data['body'] ??
        '';

    final email = Email(
      id: msgId,
      subject: subject,
      body: body,
      isNew: true,
    );
    _onNewEmailCallback?.call(email);

    // 포그라운드 TTS 처리
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.resumed && !_spokenMessageIds.contains(msgId)) {
      _spokenMessageIds.add(msgId);
      String? ttsMsg;
      if (subject.contains('긴급') || body.contains('긴급')) {
        ttsMsg = '緊急メールが届きました';
      } else if (subject.contains('미팅') || body.contains('미팅')) {
        ttsMsg = 'ミーティングのメールが届きました';
      }
      if (ttsMsg != null) {
        try {
          _ttsChannel.invokeMethod('speak', {'text': ttsMsg});
          debugPrint('🔔 포그라운드 TTS 요청: $ttsMsg, msgId: $msgId');
        } catch (e) {
          debugPrint('🔔 포그라운드 TTS 실패: $e');
        }
      } else {
        debugPrint('🔔 포그라운드 TTS 메시지 없음: $msgId');
      }
    } else if (_spokenMessageIds.contains(msgId)) {
      debugPrint('🔇 이미 처리된 메시지: $msgId');
    } else {
      debugPrint('🔇 앱 상태($state)로 TTS 미실행: $msgId');
    }
  }

  /// 알림 표시
  Future<void> _showNotification(RemoteMessage msg) async {
    const androidDetails = AndroidNotificationDetails(
      'mail_push_channel',
      'Mail Push Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    final isCritical = msg.data['isCritical'] == 'true';
    final iosDetails = DarwinNotificationDetails(
      sound: isCritical ? 'siren.mp3' : null,
      presentSound: true,
      interruptionLevel: isCritical
          ? InterruptionLevel.critical
          : InterruptionLevel.active,
    );
    final nd = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(
      msg.messageId.hashCode,
      msg.notification?.title ?? '새 이메일',
      msg.notification?.body ?? '새 이메일이 도착했습니다!',
      nd,
      payload: jsonEncode(msg.data),
    );
    debugPrint('🔔 알림 표시: ${msg.messageId}');
  }

  /// 디테일 페이지로 네비게이트
  void _navigateToDetail(RemoteMessage message) {
    final data = message.data;
    final mailMap = data['mailData'] != null
        ? jsonDecode(data['mailData'])
        : <String, dynamic>{};
    final email = Email(
      id: data['messageId'] ?? DateTime.now().toString(),
      subject: mailMap['subject'] ?? data['subject'] ?? '',
      body: mailMap['body'] ?? data['body'] ?? '',
      isNew: true,
    );
    NavigationService.instance
        .navigateTo('/mail_detail', arguments: email);
    debugPrint('🔔 디테일 페이지로 이동: ${email.id}');
  }

  /// payload JSON 문자열에서 디테일 네비게이션
  void _navigateToDetailFromPayload(String payload) {
    final data = jsonDecode(payload);
    final mailMap = data['mailData'] != null
        ? jsonDecode(data['mailData'])
        : <String, dynamic>{};
    final email = Email(
      id: data['messageId'] ?? DateTime.now().toString(),
      subject: mailMap['subject'] ?? data['subject'] ?? '',
      body: mailMap['body'] ?? data['body'] ?? '',
      isNew: true,
    );
    NavigationService.instance
        .navigateTo('/mail_detail', arguments: email);
    debugPrint('🔔 페이로드에서 디테일 페이지로 이동: ${email.id}');
  }
}

/// 백그라운드 핸들러: 알림 표시만 처리, TTS는 네이티브에서
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 백그라운드 알림 수신: ${message.data}');
  if (message.data['mailData'] != null) {
    try {
      final mail = jsonDecode(message.data['mailData']);
      final subject = mail['subject'] ?? '';
      debugPrint('🔔 백그라운드 알림 처리: $subject');
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'mail_push_channel',
        'Mail Push Notifications',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );
      final iosDetails = DarwinNotificationDetails(
        sound: message.data['isCritical'] == 'true' ? 'siren.mp3' : null,
        presentSound: true,
        interruptionLevel: message.data['isCritical'] == 'true'
            ? InterruptionLevel.critical
            : InterruptionLevel.active,
      );
      final notificationDetails =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      await flutterLocalNotificationsPlugin.show(
        message.messageId.hashCode,
        'New Email',
        subject,
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('🔔 백그라운드 알림 처리 실패: $e');
    }
  }
}