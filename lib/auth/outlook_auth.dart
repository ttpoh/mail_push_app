import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'auth_service.dart';

class OutlookAuthService implements AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _refreshTimer;
  final apiClient = ApiClient();

  static final String _clientId = dotenv.env['OUTLOOK_CLIENT_ID']!;
  static final String _redirectUrl = dotenv.env['OUTLOOK_REDIRECT_URI']!;
  static const List<String> _scopes = [
    'https://graph.microsoft.com/Mail.Read',
    'https://graph.microsoft.com/Mail.ReadWrite',
    'https://graph.microsoft.com/User.Read',
    'offline_access',
  ];
  static final String _serverEndpoint =
      '${dotenv.env['SERVER_BASE_URL']}/api/update_tokens';

  @override
  String get serviceName => 'outlook';

  // client_state 생성 함수
  String _generateClientState() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // FCM 토큰 갱신 이벤트 처리
  void _setupFcmTokenRefreshListener() async {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM Token refreshed: $newToken at ${DateTime.now()}');
      final clientState = await _storage.read(key: 'outlook_client_state');
      final accessToken = await _storage.read(key: 'outlook_access_token');
      final refreshToken = await _storage.read(key: 'outlook_refresh_token');
      if (clientState != null && accessToken != null && refreshToken != null) {
        try {
          await http.post(
            Uri.parse(_serverEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'service': serviceName,
              'accessToken': accessToken,
              'refreshToken': refreshToken,
              'fcm_token': newToken,
              'client_state': clientState,
            }),
          );
          print('FCM token update sent to server: $newToken');
          await _storage.write(key: 'fcm_token', value: newToken); // 새로운 FCM 토큰 저장
        } catch (e) {
          print('Failed to update FCM token on server: $e');
        }
      }
    });
  }

  Future<void> _createSubscription(String accessToken, String fcmToken, String clientState) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('Attempting to create subscription (attempt $attempt): fcm_token=$fcmToken, client_state=$clientState');
        final response = await http.post(
          Uri.parse('${dotenv.env['SERVER_BASE_URL']}/api/create_subscription'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({
            'resource': "me/mailFolders('Inbox')/messages",
            'changeType': 'created',
            'notificationUrl': '${dotenv.env['SERVER_BASE_URL']}/outlook_webhook',
            'clientState': clientState,
            'fcm_token': fcmToken,
          }),
        ).timeout(Duration(seconds: 30));
        print('Subscription response: ${response.statusCode} ${response.body}');
        if (response.statusCode != 200) {
          throw Exception('Failed to create subscription: ${response.body}');
        }
        return;
      } catch (e) {
        print('Subscription attempt $attempt failed: $e');
        if (attempt == maxRetries) {
          throw Exception('Failed to create subscription after $maxRetries attempts: $e');
        }
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }

  @override
  Future<Tokens> signIn() async {
    // FCM 토큰 갱신 리스너 설정
    _setupFcmTokenRefreshListener();

    // 기존에 저장된 client_state가 있으면 재사용
    String? clientState = await _storage.read(key: 'outlook_client_state');
    if (clientState == null) {
      clientState = _generateClientState();
      await _storage.write(key: 'outlook_client_state', value: clientState);
      print('Generated new clientState: $clientState');
    } else {
      print('Reusing existing clientState: $clientState');
    }

    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint:
              'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
          tokenEndpoint:
              'https://login.microsoftonline.com/common/oauth2/v2.0/token',
        ),
        scopes: _scopes,
        additionalParameters: {'prompt': 'consent'},
      ),
    );
    final at = result?.accessToken;
    final rt = result?.refreshToken;
    if (at == null || rt == null) {
      throw Exception('Failed to obtain tokens');
    }

    // 토큰 저장
    await _storage.write(key: 'outlook_access_token', value: at);
    await _storage.write(key: 'outlook_refresh_token', value: rt);

    // FCM 토큰 획득 및 저장
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      throw Exception('Failed to obtain FCM token');
    }
    await _storage.write(key: 'fcm_token', value: fcmToken); // FCM 토큰 저장
    print('FCM Token obtained: $fcmToken at ${DateTime.now()}');

    final success = await apiClient.registerTokens(
      fcmToken: fcmToken,
      accessToken: at,
      refreshToken: rt,
      service: serviceName,
    );
    if (!success) {
      throw Exception('Failed to register tokens with server');
    }

    // 서브스크립션 생성 호출
    await Future.delayed(Duration(milliseconds: 300)); // optional delay
    print('Calling _createSubscription for fcm_token: $fcmToken, client_state: $clientState');
    await _createSubscription(at, fcmToken, clientState);

    // 자동 리프레시 타이머
    final DateTime? expiry = result?.accessTokenExpirationDateTime;
    if (expiry != null) {
      final delay = expiry.difference(DateTime.now()) - const Duration(minutes: 5);
      if (!delay.isNegative) { // 즉시 실행 방지
        _refreshTimer?.cancel();
        _refreshTimer = Timer(delay, refreshTokens);
      } else {
        print('Refresh timer not set due to negative delay: $delay');
      }
    }

    return {'accessToken': at, 'refreshToken': rt};
  }

  @override
  Future<Tokens> refreshTokens() async {
    print('refreshTokens called at ${DateTime.now()}');
    final rt = await _storage.read(key: 'outlook_refresh_token');
    if (rt == null) return {'accessToken': null, 'refreshToken': null};

    final result = await _appAuth.token(
      TokenRequest(
        _clientId,
        _redirectUrl,
        refreshToken: rt,
        scopes: _scopes,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint:
              'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
          tokenEndpoint:
              'https://login.microsoftonline.com/common/oauth2/v2.0/token',
        ),
      ),
    );
    final at = result?.accessToken;
    final newRt = result?.refreshToken ?? rt;
    if (at == null) throw Exception('Failed to refresh tokens');

    // 저장
    await _storage.write(key: 'outlook_access_token', value: at);
    await _storage.write(key: 'outlook_refresh_token', value: newRt);

    // 기존에 저장된 client_state 및 fcm_token 읽기
    final clientState = await _storage.read(key: 'outlook_client_state');
    final fcmToken = await _storage.read(key: 'fcm_token') ?? await FirebaseMessaging.instance.getToken();
    print('FCM Token used in refreshTokens: $fcmToken at ${DateTime.now()}');

    // 서버 전송
    await http.post(
      Uri.parse(_serverEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service': serviceName,
        'accessToken': at,
        'refreshToken': newRt,
        'fcm_token': fcmToken,
        if (clientState != null) 'client_state': clientState,
      }),
    );

    // 새로운 리프레시 타이머 설정
    final DateTime? expiry = result?.accessTokenExpirationDateTime;
    if (expiry != null) {
      final delay = expiry.difference(DateTime.now()) - const Duration(minutes: 5);
      if (!delay.isNegative) {
        _refreshTimer?.cancel();
        _refreshTimer = Timer(delay, refreshTokens);
      } else {
        print('Refresh timer not set due to negative delay: $delay');
      }
    }

    return {'accessToken': at, 'refreshToken': newRt};
  }

  @override
  Future<void> signOut() async {
    _refreshTimer?.cancel();
    await _storage.delete(key: 'outlook_access_token');
    await _storage.delete(key: 'outlook_refresh_token');
    await _storage.delete(key: 'outlook_client_state');
    await _storage.delete(key: 'fcm_token'); // FCM 토큰 삭제
  }

  @override
  Future<String?> getCurrentUserEmail() async {
    return _storage.read(key: 'outlook_user_email');
  }
}