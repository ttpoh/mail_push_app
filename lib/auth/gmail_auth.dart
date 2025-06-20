// lib/auth/gmail_auth.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'auth_service.dart';

class GmailAuthService implements AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _refreshTimer;

  static final String _clientId    = dotenv.env['GMAIL_CLIENT_ID']!;
  static final String _redirectUrl = dotenv.env['GMAIL_REDIRECT_URI']!;
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/gmail.modify',
    'openid',
    'https://www.googleapis.com/auth/userinfo.email',
  ];
  static final String _serverEndpoint =
      '${dotenv.env['SERVER_BASE_URL']}/api/update_tokens';

  @override
  String get serviceName => 'gmail';

  @override
  Future<Tokens> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint:
              'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
        ),
        scopes: _scopes,
        additionalParameters: {'access_type': 'offline', 'prompt': 'consent'},
      ),
    );
    final at = result?.accessToken;
    final rt = result?.refreshToken;
    if (at == null || rt == null) {
      throw Exception('Failed to obtain tokens');
    }

    // 토큰 저장
    await _storage.write(key: 'gmail_access_token', value: at);
    await _storage.write(key: 'gmail_refresh_token', value: rt);

    // 서버에 토큰 전송
    final fcmToken = await FirebaseMessaging.instance.getToken();
    await http.post(
      Uri.parse(_serverEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service': serviceName,
        'accessToken': at,
        'refreshToken': rt,
        'fcm_token': fcmToken,
      }),
    );

    // 자동 리프레시 타이머 설정
    final DateTime? expiry = result?.accessTokenExpirationDateTime;
    if (expiry != null) {
      final delay = expiry.difference(DateTime.now()) - const Duration(minutes: 5);
      _refreshTimer?.cancel();
      _refreshTimer = Timer(
        delay.isNegative ? Duration.zero : delay,
        refreshTokens,
      );
    }

    return {'accessToken': at, 'refreshToken': rt};
  }

  @override
  Future<Tokens> refreshTokens() async {
    final rt = await _storage.read(key: 'gmail_refresh_token');
    if (rt == null) return {'accessToken': null, 'refreshToken': null};

    final result = await _appAuth.token(
      TokenRequest(
        _clientId,
        _redirectUrl,
        refreshToken: rt,
        scopes: _scopes,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint:
              'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
        ),
      ),
    );
    final at = result?.accessToken;
    final newRt = result?.refreshToken ?? rt;
    if (at == null) throw Exception('Failed to refresh tokens');

    // 갱신된 토큰 저장
    await _storage.write(key: 'gmail_access_token', value: at);
    await _storage.write(key: 'gmail_refresh_token', value: newRt);

    // 서버에 갱신된 토큰 전송
    final fcmToken = await FirebaseMessaging.instance.getToken();
    await http.post(
      Uri.parse(_serverEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service': serviceName,
        'accessToken': at,
        'refreshToken': newRt,
        'fcm_token': fcmToken,
      }),
    );

    return {'accessToken': at, 'refreshToken': newRt};
  }

  @override
  Future<void> signOut() async {
    _refreshTimer?.cancel();
    await _storage.delete(key: 'gmail_access_token');
    await _storage.delete(key: 'gmail_refresh_token');
    await _storage.delete(key: 'gmail_user_email');
  }

  @override
  Future<String?> getCurrentUserEmail() async {
    return _storage.read(key: 'gmail_user_email');
  }
}
