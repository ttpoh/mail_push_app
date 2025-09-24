// lib/auth/gmail_auth.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';
import '../api/api_client.dart';
import 'package:mail_push_app/device/alarm_setting_sync.dart';


class GmailAuthService implements AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiClient _apiClient = ApiClient(); // 인스턴스 생성

  Timer? _refreshTimer;

  static final String _clientId = dotenv.env['GMAIL_CLIENT_ID']!;
  static final String _redirectUrl = dotenv.env['GMAIL_REDIRECT_URI']!;
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/gmail.modify',
    'openid',
    'https://www.googleapis.com/auth/userinfo.email',
  ];
  static final String _serverEndpoint =
      '${dotenv.env['SERVER_BASE_URL']}/api/update_tokens';

  static final String _createSubscriptionEndpoint =
      '${dotenv.env['SERVER_BASE_URL']}/api/create_gmail_subscription';

  @override
  String get serviceName => 'gmail';

  final AlarmSettingSync _alarmSync =
      AlarmSettingSync(api: ApiClient()); // 공용 싱크 유틸

  GmailAuthService() {
    // FCM 토큰 갱신 리스너 등록
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed: $newToken');
      await _updateServerTokens(newToken);

      final email = await _storage.read(key: 'gmail_user_email');
      if (email != null && email.isNotEmpty) {
        await _alarmSync.upsertAfterLogin(email: email, pushFlagsFromPrefs: false);
      }
    });
  }

  Future<void> _updateServerTokens(String fcmToken) async {
    final accessToken = await _storage.read(key: 'gmail_access_token');
    final refreshToken = await _storage.read(key: 'gmail_refresh_token');
    final email = await _storage.read(key: 'gmail_user_email');

    if (accessToken != null && refreshToken != null && email != null) {
      final success = await _apiClient.registerTokens(
        fcmToken: fcmToken,
        accessToken: accessToken,
        refreshToken: refreshToken,
        service: serviceName,
        emailAddress: email,
      );
      if (!success) {
        print('Failed to update server with new FCM token');
      } else {
        print('Updated server with new FCM token: $fcmToken');
      }
    }
  }

  @override
  Future<Tokens> signIn() async {
    try {
      // 인증 및 토큰 교환 요청 (PKCE 자동 처리)
      final authResult = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _clientId,
          _redirectUrl,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
            tokenEndpoint: 'https://oauth2.googleapis.com/token',
          ),
          scopes: _scopes,
          promptValues: const ['consent', 'select_account'],
           additionalParameters: const {
             'access_type': 'offline',
             'include_granted_scopes': 'true',
    },
        ),
      );

      final accessToken = authResult?.accessToken;
      final refreshToken = authResult?.refreshToken;

      if (accessToken == null || refreshToken == null) {
        throw Exception('Failed to obtain tokens');
      }

      // Gmail API 호출하여 이메일 주소 가져오기
      final email = await _getEmailAddress(accessToken);
      print('User email: $email');

      // 토큰과 이메일 주소 저장
      await _storage.write(key: 'gmail_access_token', value: accessToken);
      await _storage.write(key: 'gmail_refresh_token', value: refreshToken);
      await _storage.write(key: 'gmail_user_email', value: email);

      // 서버에 토큰 및 이메일 주소 전송
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final response = await http.post(
        Uri.parse(_serverEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service': serviceName,
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'fcm_token': fcmToken,
          'email_address': email,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update tokens on server: ${response.body}');
      }

      await _alarmSync.upsertAfterLogin(email: email, pushFlagsFromPrefs: false); // 로그인과 동시에 서버의 alarm_setting table에 email 저장
 
      // ② 그리고 즉시 서버에서 세팅 로딩하여 로컬 반영
      print('🔎 signIn → loadFromServerAndSeedPrefs()');
      final loaded = await _alarmSync.loadFromServerAndSeedPrefs();
      print('✅ signIn loaded settings from server: $loaded');
 
      // Gmail Pub/Sub 구독 생성
      final subResp = await http.post(
        Uri.parse(_createSubscriptionEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fcm_token': fcmToken,
          'access_token': accessToken,
          'refresh_token': refreshToken,
          'email_address': email,
        }),
      );

      if (subResp.statusCode == 200) {
        print('✅ Gmail Pub/Sub subscription created');
      } else {
        print('⚠️ Failed to create Gmail subscription: ${subResp.body}');
      }

      // 자동 리프레시 타이머 설정
      final expiry = authResult?.accessTokenExpirationDateTime;
      if (expiry != null) {
        final delay = expiry.difference(DateTime.now()) - const Duration(minutes: 5);
        _refreshTimer?.cancel();
        _refreshTimer = Timer(
          delay.isNegative ? Duration.zero : delay,
          refreshTokens,
        );
      }

      return {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
    } catch (e) {
      print('Sign-in error: $e');
      rethrow;
    }
  }


  // Gmail API로 이메일 주소 가져오기
  Future<String> _getEmailAddress(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/profile'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final email = data['emailAddress'] as String?;
      if (email == null) {
        throw Exception('Failed to retrieve email address');
      }
      return email;
    } else {
      throw Exception('Failed to fetch email: ${response.statusCode} ${response.body}');
    }
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
          authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
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

    // 서버에 갱신된 토큰 및 이메일 주소 전송
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final email = await _storage.read(key: 'gmail_user_email');
    final response = await http.post(
      Uri.parse(_serverEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service': serviceName,
        'accessToken': at,
        'refreshToken': newRt,
        'fcm_token': fcmToken,
        'email_address': email, // 이메일 주소 추가
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update tokens on server: ${response.body}');
    }    

    return {'accessToken': at, 'refreshToken': newRt};
  }

  @override
  Future<void> signOut() async {
    _refreshTimer?.cancel();
    await _storage.delete(key: 'gmail_access_token');
    await _storage.delete(key: 'gmail_refresh_token');
    await _storage.delete(key: 'gmail_user_email');

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      print('❌ No FCM token found for logout.');
      return;
    }

    final logoutUrl = '${dotenv.env['SERVER_BASE_URL']}/api/logout_gmail';

    try {
      // 1. 서버에 로그아웃 요청 (FCM 토큰 삭제 등)
      final logoutResponse = await http.post(
        Uri.parse(logoutUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      if (logoutResponse.statusCode == 200) {
        print('✅ Gmail logout request successful');
      } else {
        print('❌ Gmail logout failed: ${logoutResponse.statusCode} ${logoutResponse.body}');
      }   

    } catch (e) {
      print('❌ Error during logout or unsubscribe: $e');
    }
  }


  @override
  Future<String?> getCurrentUserEmail() async {
    return _storage.read(key: 'gmail_user_email');
  }
}