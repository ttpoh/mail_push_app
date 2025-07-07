import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/utils/navigation_service.dart';

class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Function(Email)? _onNewEmailCallback;
  bool _initialized = false;

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
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ 알림 권한 거부됨');
      return;
    }

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

    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('🔔 포그라운드 메시지 수신: ${msg.messageId}');
      _showNotification(msg);
      _handleNewEmail(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('🔔 메시지 클릭으로 앱 열림: ${msg.messageId}');
      _handleNewEmail(msg);
      _navigateToDetail(msg);
    });

    final initialMsg = await getInitialMessage();
    if (initialMsg != null) {
      debugPrint('🔔 초기 메시지 처리: ${initialMsg.messageId}');
      _handleNewEmail(initialMsg);
      _navigateToDetail(initialMsg);
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _initialized = true;
    debugPrint('✅ FcmService 초기화 완료');
  }

  void _handleNewEmail(RemoteMessage message) {
    final msgId = message.messageId ?? '';
    if (msgId.isEmpty) {
      debugPrint('❌ 메시지 ID 누락');
      return;
    }

    final mail = message.data['mailData'] != null
        ? Email.fromJsonString(message.data['mailData'])
        : null;
    if (mail == null) {
      debugPrint('❌ mailData 누락 또는 파싱 실패');
      return;
    }
    _onNewEmailCallback?.call(mail);
    debugPrint('📬 onNewEmail: ${mail.id}, email_address: ${mail.emailAddress}');
  }

  Future<void> _showNotification(RemoteMessage msg) async {
    final mail = msg.data['mailData'] != null
        ? jsonDecode(msg.data['mailData'])
        : null;
    final subject = mail?['subject'] ?? msg.notification?.title ?? '새 이메일';
    final sender = mail?['sender'] ?? msg.data['sender'] ?? 'Unknown Sender';

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
      subject,
      'From: $sender',
      nd,
      payload: jsonEncode(msg.data),
    );
    debugPrint('🔔 알림 표시: ${msg.messageId}');
  }

  void _navigateToDetail(RemoteMessage message) {
    final data = message.data;
    final mailMap = data['mailData'] != null
        ? jsonDecode(data['mailData'])
        : <String, dynamic>{};
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
    NavigationService.instance
        .navigateTo('/mail_detail', arguments: email);
    debugPrint('🔔 디테일 페이지로 이동: ${email.id}');
  }

  void _navigateToDetailFromPayload(String payload) {
    final data = jsonDecode(payload);
    final mailMap = data['mailData'] != null
        ? jsonDecode(data['mailData'])
        : <String, dynamic>{};
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
    NavigationService.instance
        .navigateTo('/mail_detail', arguments: email);
    debugPrint('🔔 페이로드에서 디테일 페이지로 이동: ${email.id}');
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 백그라운드 알림 수신: ${message.data}');
  if (message.data['mailData'] != null) {
    try {
      final mail = jsonDecode(message.data['mailData']);
      final subject = mail['subject'] ?? '';
      final sender = mail['sender'] ?? 'Unknown Sender';
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
        subject,
        'From: $sender',
        notificationDetails,
        payload: jsonEncode(message.data),
      );
    } catch (e) {
      debugPrint('🔔 백그라운드 알림 처리 실패: $e');
    }
  }
}