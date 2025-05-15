import 'dart:async';
import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

/// 인증 서비스 인터페이스
typedef Tokens = Map<String,String?>;
abstract class AuthService {
  Future<Tokens> signIn();
  Future<void> signOut();
  Future<Tokens> refreshTokens();
  String get serviceName;
  Future<String?> getCurrentUserEmail();
}

/// GmailAuthService
class GmailAuthService implements AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _refreshTimer;

  static const String _clientId =
      '896564723347-ooift0gpd2idsgmllnoll75gjju646ai.apps.googleusercontent.com';
  static const String _redirectUrl = 'com.secure.mailpushapp:/oauth2redirect';
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/gmail.modify',
    'openid',
    'https://www.googleapis.com/auth/userinfo.email',
  ];
  static const String _serverEndpoint =
      'https://mail-push.xtect.net/api/update_tokens';

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
    await _storage.write(key: 'gmail_access_token', value: at);
    await _storage.write(key: 'gmail_refresh_token', value: rt);

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
    if (rt == null) {
      return {'accessToken': null, 'refreshToken': null};
    }
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
    if (at == null) {
      throw Exception('Failed to refresh tokens');
    }
    await _storage.write(key: 'gmail_access_token', value: at);
    await _storage.write(key: 'gmail_refresh_token', value: newRt);

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
    return await _storage.read(key: 'gmail_user_email');
  }
}

/// OutlookAuthService (unchanged)
class OutlookAuthService implements AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Timer? _refreshTimer;

  static const String _clientId = 'dcf1d4af-a8fc-4474-9857-5801f9ac766e';
  static const String _redirectUrl = 'mailapp://oauth/';
  static const List<String> _scopes = ['User.Read', 'Mail.Read', 'offline_access'];
  static const String _serverEndpoint =
      'https://mail-push.xtect.net/api/update_tokens';

  @override
  String get serviceName => 'outlook';

  @override
  Future<Tokens> signIn() async {
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
    await _storage.write(key: 'outlook_access_token', value: at);
    await _storage.write(key: 'outlook_refresh_token', value: rt);

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
    final rt = await _storage.read(key: 'outlook_refresh_token');
    if (rt == null) {
      return {'accessToken': null, 'refreshToken': null};
    }
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
    if (at == null) {
      throw Exception('Failed to refresh tokens');
    }
    await _storage.write(key: 'outlook_access_token', value: at);
    await _storage.write(key: 'outlook_refresh_token', value: newRt);

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
    await _storage.delete(key: 'outlook_access_token');
    await _storage.delete(key: 'outlook_refresh_token');
  }

  @override
  Future<String?> getCurrentUserEmail() async {
    return await _storage.read(key: 'outlook_user_email');
  }
}