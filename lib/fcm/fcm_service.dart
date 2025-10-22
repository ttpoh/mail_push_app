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
import 'package:flutter/foundation.dart' show ValueNotifier, defaultTargetPlatform, TargetPlatform;
// 🔽 [ADDED]
import 'package:just_audio/just_audio.dart';

/// ===============================================================
/// ② assets/sounds/*.mp3 목록 로드 유틸 (AssetManifest.json 파싱)
/// ===============================================================
Future<List<String>> listSoundAssets({
  String prefix = 'assets/sounds/',
  String extension = '.mp3',
}) async {
  try {
    final raw = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest = json.decode(raw) as Map<String, dynamic>;
    final items = manifest.keys
        .where((k) =>
            k.startsWith(prefix) &&
            k.toLowerCase().endsWith(extension.toLowerCase()))
        .toList()
      ..sort();
    return items;
  } catch (e) {
    debugPrint('⚠️ listSoundAssets error: $e');
    return const <String>[];
  }
}

/// 파일명만 표시하고 싶을 때 사용
String soundDisplayName(String assetPath) {
  final p = assetPath.trim();
  if (p.isEmpty) return '';
  final idx = p.lastIndexOf('/');
  return (idx >= 0 && idx < p.length - 1) ? p.substring(idx + 1) : p;
}

/// ===============================================================
/// ③ 미리듣기 싱글턴 유틸 (JustAudio)
/// - Dialog/위젯 어디서든 SoundPreview.instance 로 사용
/// ===============================================================
class SoundPreview {
  SoundPreview._() {
    _player.playerStateStream.listen((s) {
      isPlaying.value = s.playing;
    });
  }
  static final SoundPreview instance = SoundPreview._();

  final AudioPlayer _player = AudioPlayer();
  /// 단순 재생 여부 관찰용
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);

  /// 선택된 에셋을 즉시 재생 (같은 곡 전환도 자동 처리)
  Future<void> playAsset(String? assetPath) async {
    if (assetPath == null || assetPath.isEmpty) {
      await stop();
      return;
    }
    try {
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      debugPrint('❌ SoundPreview.playAsset error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('❌ SoundPreview.pause error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('❌ SoundPreview.stop error: $e');
    }
  }

  /// 앱 전역 싱글턴이라 일반적으로 호출 필요 없음.
  /// (정리하고 싶을 때 호출)
  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('❌ SoundPreview.dispose error: $e');
    }
  }
}

/// 기존 코드 ================================================

String _dedupeKeyFromData(Map<String, dynamic> d, String? fallbackMsgId) {
  // 1) mailData에서 메일 고유 ID를 먼저 시도
  String? mailId;
  final md = d['mailData'];
  if (md is String) {
    try {
      final m = jsonDecode(md);
      mailId = (m['message_id'] ?? m['messageId'])?.toString();
    } catch (_) {}
  } else if (md is Map) {
    mailId = (md['message_id'] ?? md['messageId'])?.toString();
  }

  final ver = (d['ruleVersion'] ?? 'v0').toString();

  // 2) 메일 ID가 있으면 채널 상관없이 mailId+ver 로 키 생성
  if (mailId != null && mailId.isNotEmpty) {
    return '$mailId:$ver';
  }

  // 3) 없으면 FCM ID로 폴백(이때도 채널은 키에서 제외해 중복 억제)
  final mid = (d['messageId'] ?? fallbackMsgId ?? '').toString();
  return '$mid:$ver';
}

class AlarmSettingsStore {
  static const _kGlobalOn = 'alarm_normal_on';
  static const _kLastMsgId = 'last_message_id';
  static const _kLastTtsId = 'last_tts_message_id';
  static const _kProcessedIds = 'processed_ids_cache';
  static const _kMaxCacheSize = 500;

  static Future<void> _addToProcessedCache(String id) async {
    final sp = await SharedPreferences.getInstance();
    final cacheStr = sp.getString(_kProcessedIds) ?? '';
    final cacheIds = cacheStr.isNotEmpty ? cacheStr.split(',') : <String>[];
    if (cacheIds.length >= _kMaxCacheSize) {
      await sp.remove(_kProcessedIds);
    } else {
      cacheIds.add(id);
      await sp.setString(_kProcessedIds, cacheIds.join(','));
    }
  }

  static Future<bool> _isInProcessedCache(String id) async {
    final sp = await SharedPreferences.getInstance();
    final cacheStr = sp.getString(_kProcessedIds) ?? '';
    if (cacheStr.isEmpty) return false;
    return cacheStr.split(',').contains(id);
  }

  static Future<void> setGlobalOn(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kGlobalOn, v);
  }

  static Future<bool> getGlobalOn() async {
    final sp = await SharedPreferences.getInstance();
    // 기본값 true (앱 첫 실행 시에도 울리도록)
    return sp.getBool(_kGlobalOn) ?? true;
  }

  static Future<bool> isDuplicateAndMark(
    String id, {
    bool syncToNative = false,
  }) async {
    if (id.isEmpty) return true;
    if (await _isInProcessedCache(id)) {
      debugPrint('🚫 Dart cache hit: $id');
      return true;
    }
    await _addToProcessedCache(id);
    if (syncToNative && Platform.isIOS) {
      try {
        await const MethodChannel('com.secure.mail_push_app/sync')
            .invokeMethod('syncMessageId', {'id': id});
        debugPrint('✅ Synced with native: $id');
      } catch (e) {
        debugPrint('❌ Failed to sync message ID with native: $e');
      }
    }
    return false;
  }

  static Future<bool> isDuplicateTtsAndMark(String id) async {
    if (id.isEmpty) return true;
    final sp = await SharedPreferences.getInstance();
    final last = sp.getString(_kLastTtsId);
    if (last == id) return true;
    await sp.setString(_kLastTtsId, id);
    return false;
  }

  static Future<void> clearProcessedCache() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kProcessedIds);
    debugPrint('✅ Processed cache cleared');
  }
}

class _AlarmLoopState {
  static bool running = false;
}

class FcmService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final ValueNotifier<bool> loopRunning = ValueNotifier(false);

  Function(Email)? _onNewEmailCallback;
  bool _initialized = false;

  static const String _chGeneralId = 'mail_general';
  static const String _chGeneralName = 'General Mail';
  static const String _chCriticalId = 'mail_critical';
  static const String _chCriticalName = 'Critical Mail';

  static const MethodChannel _alarmLoopChannel =
      MethodChannel('com.secure.mail_push_app/alarm_loop');

  // ===== 실시간 파이프 =====
  final _emailStreamCtrl = StreamController<Email>.broadcast();
  Stream<Email> get emailStream => _emailStreamCtrl.stream;
  static final ValueNotifier<List<Email>> inbox = ValueNotifier<List<Email>>([]);

  void _emitEmail(Email e) {
    // id 기준 중복 방지
    if ((e.id).isEmpty) return; // [CHANGED] 안전 가드
    final cur = List<Email>.from(inbox.value);
    final exists = cur.any((x) => x.id == e.id);
    if (!exists) {
      cur.insert(0, e);
      inbox.value = cur;
      _emailStreamCtrl.add(e);
    }
    _onNewEmailCallback?.call(e);
  }

  // [ADDED] HomeScreen이 EventChannel 수신을 단일 파이프로 합치도록 공개 래퍼
  void emitEmailDirect(Email e) => _emitEmail(e);

  // ========================

  Future<void> ensureForegroundListeners() async => initialize();
  Future<RemoteMessage?> getInitialMessage() => _fcm.getInitialMessage();

  void handleNewEmail(RemoteMessage message) => _handleNewEmail(message);

  void setOnNewEmailCallback(Function(Email) cb) {
    _onNewEmailCallback = cb;
    debugPrint('✅ setOnNewEmailCallback registered');
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final settings =
        await _fcm.requestPermission(alert: true, badge: true, sound: true);
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ 알림 권한 거부됨');
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestCriticalPermission: true,
      requestAlertPermission: true,
      requestSoundPermission: true,
      requestBadgePermission: true,
    );
    await _notificationsPlugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (details) async {
        await _stopLoop();
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            final key = _dedupeKeyFromData(
              Map<String, dynamic>.from(data),
              null,
            );
            final ch = (data['pushChannel'] ?? 'alert').toString();
            final isDup = await AlarmSettingsStore.isDuplicateAndMark(
              key,
              syncToNative: Platform.isIOS && ch == 'bg',
            );
            if (!isDup) {
              final mailMap = data['mailData'] != null
                  ? jsonDecode(data['mailData'])
                  : <String, dynamic>{};
              final email = Email(
                id: (data['messageId'] ??
                        DateTime.now().millisecondsSinceEpoch.toString())
                    .toString(),
                emailAddress: (mailMap['email_address'] ?? '').toString(),
                subject:
                    (mailMap['subject'] ?? data['subject'] ?? '').toString(),
                sender: (mailMap['sender'] ?? data['sender'] ?? 'Unknown Sender')
                    .toString(),
                body: (mailMap['body'] ?? data['body'] ?? '').toString(),
                receivedAt: mailMap['received_at'] != null
                    ? DateTime.parse(mailMap['received_at'])
                    : DateTime.now(),
                read: false,
                ruleAlarm: (data['ruleAlarm'] as String?)?.trim(),
              );
              _emitEmail(email);
            }
          } catch (_) {}
          _navigateToDetailFromPayload(details.payload!);
        } else {
          NavigationService.instance.navigateTo('/home');
        }
      },
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _chGeneralId,
          _chGeneralName,
          description: 'General (no sound)',
          importance: Importance.defaultImportance,
          playSound: false,
          enableVibration: false,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _chCriticalId,
          _chCriticalName,
          description: 'Critical (with sound)',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    // 포그라운드
    FirebaseMessaging.onMessage.listen((msg) async {
      if (!await _shouldProcess(msg)) return;

      if (Platform.isIOS) {
        // [CHANGED] iOS 포그라운드: EventChannel이 리스트 반영 → 여기선 emit 금지
        await _showNotification(msg);
        return;
      }

      // Android 등: 여기서만 emit
      _handleNewEmail(msg); // [CHANGED] (플랫폼 분기)
      await _showNotification(msg);
    });

    // 알림 탭(메시지 객체 제공됨)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
      if (!await _shouldProcess(msg)) return;
      _handleNewEmail(msg);      // 탭 시에는 단일 경로
      await _stopLoop();
      _navigateToDetail(msg);
    });

    // cold start
    final initialMsg = await getInitialMessage();
    if (initialMsg != null && await _shouldProcess(initialMsg)) {
      _handleNewEmail(initialMsg);
      await _stopLoop();
      _navigateToDetail(initialMsg);
    }

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }

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
      'ko': 'ko-KR',
      'ja': 'ja-JP',
      'en': 'en-US',
      'zh': 'zh-CN'
    };
    String pickText(String lang) {
      final s = (subject ?? ''), b = (body ?? '');
      final meet = s.contains('미팅') || b.contains('미팅');
      if (meet) {
        switch (lang) {
          case 'ko':
            return '미팅 관련 메일이 도착했습니다';
          case 'ja':
            return 'ミーティングのメールが届きました';
          case 'zh':
            return '您收到会议相关邮件';
          default:
            return 'A meeting-related email has arrived';
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

    final key = _dedupeKeyFromData(data, message.messageId);
    if (key.isEmpty) {
      debugPrint('🚫 dedupe key 생성 실패 → 무시');
      return false;
    }

    final ch = (data['pushChannel'] ?? 'alert').toString();
    final dup = await AlarmSettingsStore.isDuplicateAndMark(
      key,
      syncToNative: Platform.isIOS && ch == 'bg',
    );
    if (dup) {
      debugPrint('🚫 중복 dedupeKey=$key → 무시');
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

    var email = Email.fromJsonString(mailJson);

    // 1) mailData 내부의 "메일 고유 ID" 우선
    String? mailId;
    try {
      final m = jsonDecode(mailJson);
      mailId = (m['message_id'] ?? m['messageId'])?.toString();
    } catch (_) {}

    // 2) 보강: ruleAlarm가 상위 data에 있다면 주입
    final ra = (data['ruleAlarm'] as String?)?.trim();
    if ((email.ruleAlarm == null || email.ruleAlarm!.isEmpty) && (ra?.isNotEmpty ?? false)) {
      email = email.copyWith(ruleAlarm: ra);
    }

    // 3) Email.id는 메일 고유 ID 우선, 없으면 FCM ID로 폴백(최후의 수단)
    final ensuredId = (mailId?.isNotEmpty == true)
        ? mailId!
        : (message.messageId ?? data['messageId'] ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();

    if (email.id != ensuredId) {
      email = email.copyWith(id: ensuredId);
    }

    _emitEmail(email);
  }

  Future<void> _maybeSpeakOnceIfOneShot(Map<String, dynamic> data) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    final rawUntil = data['criticalUntil'];
    final criticalUntil = (rawUntil is bool && rawUntil) ||
        (rawUntil is String && rawUntil.toLowerCase() == 'true');
    final isCritical = data['isCritical'] == 'true';
    if (!isCritical || criticalUntil) return;

    final msgId = (data['messageId'] ?? '').toString();
    if (await AlarmSettingsStore.isDuplicateTtsAndMark('tts_once_$msgId')) {
      return;
    }
  
    final ttsOverride = (data['tts'] as String?)?.trim();
    String? subject, body;
    try {
      final mailMap =
          data['mailData'] != null ? jsonDecode(data['mailData']) : {};
      subject = (mailMap['subject'] ?? '').toString();
      body = (mailMap['body'] ?? '').toString();
    } catch (_) {}

    String ttsText, ttsLang;
    if (ttsOverride != null && ttsOverride.isNotEmpty) {
      ttsText = ttsOverride;
      ttsLang = _buildTtsForLocale(subject: subject, body: body)['lang']!;
    } else {
      final t = _buildTtsForLocale(subject: subject, body: body);
      ttsText = t['text']!;
      ttsLang = t['lang']!;
    }


    await Future.delayed(const Duration(milliseconds: 800));
    try {
      const ttsChannel = MethodChannel('com.secure.mail_push_app/tts');
      await ttsChannel.invokeMethod('speak', {'text': ttsText, 'lang': ttsLang});
    } catch (_) {}
  }

  Future<void> _showNotification(RemoteMessage msg) async {
    final data = msg.data;
    final mailMap =
        data['mailData'] != null ? jsonDecode(data['mailData']) : null;
    final subject = mailMap?['subject'] ?? msg.notification?.title ?? '새 이메일';
    final sender = mailMap?['sender'] ?? data['sender'] ?? 'Unknown Sender';

    final serverCritical = data['isCritical'] == 'true';
    // ✅ 전역 허용 여부(일반 알람 스위치)
    final globalOn = await AlarmSettingsStore.getGlobalOn();

    // 전역 OFF면 배너/로컬/루프 모두 스킵
    if (!globalOn) {
      debugPrint('📵 Global alarm OFF → skip local notification');
      return;
    }

    // ✅ 규칙 사운드 이름(확장자 제외)
    final ruleSound = (data['sound'] as String?)?.trim();
    final hasCustomSound = ruleSound != null && ruleSound.isNotEmpty && ruleSound != 'default';


    final effectiveCritical = serverCritical; // ← 전역 ON이면 서버 의도 그대로

    final androidDetails = AndroidNotificationDetails(
      effectiveCritical ? _chCriticalId : _chGeneralId,
      effectiveCritical ? _chCriticalName : _chGeneralName,
      importance: effectiveCritical
          ? Importance.max
          : Importance.defaultImportance,
      priority: effectiveCritical ? Priority.high : Priority.defaultPriority,
      playSound: effectiveCritical,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final nd = NotificationDetails(android: androidDetails, iOS: iosDetails);
    final channel = (data['pushChannel'] ?? 'alert').toString();

    if (Platform.isIOS && channel == 'alert') {
      debugPrint('📵 iOS: APNs alert 감지 → 로컬 배너 스킵');
    } else {
      final localId = (data['messageId'] ?? msg.messageId ?? '').hashCode;
      await _notificationsPlugin.show(
        localId,
        subject,
        'From: $sender',
        nd,
        payload: jsonEncode(data),
      );
    }

    if (Platform.isAndroid) {
      final until = (data['criticalUntil']?.toString().toLowerCase() == 'true');
      if (!until && (hasCustomSound || ruleSound == 'default')) {
        final asset = hasCustomSound ? 'assets/sounds/$ruleSound.mp3' : null;
        if (asset != null) {
          await SoundPreview.instance.playAsset(asset);
        }
      }
    }

    await _maybeSpeakOnceIfOneShot(data);
    await _startLoopIfNeeded(data);
  }

  Future<void> _startLoopIfNeeded(Map<String, dynamic> data) async {
    if (_AlarmLoopState.running) return;

    final rawUntil = data['criticalUntil'];
    final criticalUntil = (rawUntil is bool && rawUntil) ||
        (rawUntil is String && rawUntil.toLowerCase() == 'true');
    final serverCritical = data['isCritical'] == 'true';
    final globalOn = await AlarmSettingsStore.getGlobalOn();
    if (!globalOn) return;

    final effectiveCritical = serverCritical;
    if (!effectiveCritical || !criticalUntil) return;

    final ttsOverride = (data['tts'] as String?)?.trim();

    String? subject, body;
    try {
      final mailMap =
          data['mailData'] != null ? jsonDecode(data['mailData']) : {};
      subject = (mailMap['subject'] ?? '').toString();
      body = (mailMap['body'] ?? '').toString();
    } catch (_) {}

    String ttsText, ttsLang;
    if (ttsOverride != null && ttsOverride.isNotEmpty) {
      ttsText = ttsOverride;
      ttsLang = _buildTtsForLocale(subject: subject, body: body)['lang']!;
    } else {
      final t = _buildTtsForLocale(subject: subject, body: body);
      ttsText = t['text']!;
      ttsLang = t['lang']!;
    }


    try {
      await _alarmLoopChannel.invokeMethod(
        'start',
        {'text': ttsText, 'lang': ttsLang, 'mode': 'loop'},
      );
      _AlarmLoopState.running = true;
      loopRunning.value = true;
      debugPrint('✅ Alarm loop started');
    } catch (e) {
      debugPrint('❌ alarm loop start failed: $e');
    }
  }

  Future<void> _stopLoop() async {
    if (!_AlarmLoopState.running) return;
    try {
      await _alarmLoopChannel.invokeMethod('stop');
    } catch (_) {}
    _AlarmLoopState.running = false;
    loopRunning.value = false;
    debugPrint('✅ Alarm loop stopped');
  }

  Future<bool> isAlarmLoopRunning() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final res = await _alarmLoopChannel.invokeMethod('status');
        if (res is bool) {
          _AlarmLoopState.running = res;
          loopRunning.value = res;
          return res;
        }
      } catch (_) {}
    }
    return _AlarmLoopState.running;
  }

  Future<void> stopAlarmByUser() async => _stopLoop();

  void _navigateToDetail(RemoteMessage message) {
    final data = message.data;
    final mailMap = data['mailData'] != null
        ? jsonDecode(data['mailData'])
        : <String, dynamic>{};

    final email = Email(
      id: (data['messageId'] ??
              message.messageId ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .toString(),
      emailAddress: (mailMap['email_address'] ?? '').toString(),
      subject: (mailMap['subject'] ?? data['subject'] ?? '').toString(),
      sender: (mailMap['sender'] ?? data['sender'] ?? 'Unknown Sender')
          .toString(),
      body: (mailMap['body'] ?? data['body'] ?? '').toString(),
      receivedAt: mailMap['received_at'] != null
          ? DateTime.parse(mailMap['received_at'])
          : DateTime.now(),
      read: false,
      ruleAlarm: (data['ruleAlarm'] as String?)?.trim(),
    );
    NavigationService.instance.navigateTo('/mail_detail', arguments: email);
  }

  void _navigateToDetailFromPayload(String payload) {
    final data = jsonDecode(payload);
    final mailMap = data['mailData'] != null
        ? jsonDecode(data['mailData'])
        : <String, dynamic>{};

    final email = Email(
      id: (data['messageId'] ??
              DateTime.now().millisecondsSinceEpoch.toString())
          .toString(),
      subject: (mailMap['subject'] ?? data['subject'] ?? '').toString(),
      sender: (mailMap['sender'] ?? data['sender'] ?? 'Unknown Sender')
          .toString(),
      body: (mailMap['body'] ?? data['body'] ?? '').toString(),
      emailAddress: (mailMap['email_address'] ?? '').toString(),
      receivedAt: mailMap['received_at'] != null
          ? DateTime.parse(mailMap['received_at'])
          : DateTime.now(),
      read: false,
      ruleAlarm: (data['ruleAlarm'] as String?)?.trim(),
    );
    NavigationService.instance.navigateTo('/mail_detail', arguments: email);
  }
}

// Android BG isolate (iOS는 네이티브/OS가 배너 처리)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // iOS BG에서 until=TRUE는 네이티브 루프 전담 → Dart BG는 NO-OP
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final d = message.data;
    final isCritical = d['isCritical'] == 'true';
    final until = (d['criticalUntil']?.toString().toLowerCase() == 'true');
    if (isCritical && until) {
      debugPrint('🔕 iOS until=TRUE BG: hand off to native; Dart BG no-op');
      return;
    }
  }

  debugPrint('🔔 백그라운드 알림 수신(data): ${message.data}');
  final data = message.data;

  // 규칙 매칭 안 된 푸시는 무시
  if (data['ruleMatched'] != 'true') return;

  // 중복 억제 키 생성
  final key = _dedupeKeyFromData(data, message.messageId);
  if (key.isEmpty) return;

  // BG 중복 캐시 체크
  final dup = await AlarmSettingsStore.isDuplicateAndMark(key);
  if (dup) {
    debugPrint('🚫 Duplicate detected in BG: $key');
    return;
  }

  // ✅ 전역 스위치(일반 알람) OFF면 모든 표시 스킵
  final globalOn = await AlarmSettingsStore.getGlobalOn();
  if (!globalOn) {
    debugPrint('📵 Global alarm OFF → skip showing BG notification');
    return;
  }

  // 서버가 내려준 의도 그대로 사용 (전역 ON일 때만)
  final serverCritical = data['isCritical'] == 'true';
  final effectiveCritical = serverCritical;

  // 표시용 제목/보낸이
  final mail = data['mailData'] != null ? jsonDecode(data['mailData']) : {};
  final subject = mail['subject'] ?? '새 이메일';
  final sender  = mail['sender']  ?? 'Unknown Sender';

  // 로컬 노티 표시
  final plugin = FlutterLocalNotificationsPlugin();
  final androidDetails = AndroidNotificationDetails(
    effectiveCritical ? FcmService._chCriticalId : FcmService._chGeneralId,
    effectiveCritical ? FcmService._chCriticalName : FcmService._chGeneralName,
    importance: effectiveCritical ? Importance.max : Importance.high,
    playSound: effectiveCritical,
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
  );
  final nd = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await plugin.show(
    key.hashCode,
    subject,
    'From: $sender',
    nd,
    payload: jsonEncode(data),
  );
}
