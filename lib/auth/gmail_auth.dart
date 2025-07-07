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

  GmailAuthService() {
    // FCM 토큰 갱신 리스너 등록
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed: $newToken');
      await _updateServerTokens(newToken);
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
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: 'https://accounts.google.com/o/oauth2/v2/auth',
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

    // Gmail API 호출하여 이메일 주소 가져오기
    final email = await _getEmailAddress(at);
    print('User email: $email'); // 디버깅용 로그

    // 토큰과 이메일 주소 저장
    await _storage.write(key: 'gmail_access_token', value: at);
    await _storage.write(key: 'gmail_refresh_token', value: rt);
    await _storage.write(key: 'gmail_user_email', value: email);

    // 서버에 토큰 및 이메일 주소 전송
    final fcmToken = await FirebaseMessaging.instance.getToken();
    final response = await http.post(
      Uri.parse(_serverEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'service': serviceName,
        'accessToken': at,
        'refreshToken': rt,
        'fcm_token': fcmToken,
        'email_address': email, // 이메일 주소 추가
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update tokens on server: ${response.body}');
    }

    // 자동 리프레시 타이머 설정
    final expiry = result?.accessTokenExpirationDateTime;
    if (expiry != null) {
      final delay = expiry.difference(DateTime.now()) - const Duration(minutes: 5);
      _refreshTimer?.cancel();
      _refreshTimer = Timer(
        delay.isNegative ? Duration.zero : delay,
        refreshTokens,
      );
    }

    // Create Gmail subscription (Pub/Sub)
    final subResp = await http.post(
      Uri.parse(_createSubscriptionEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fcm_token': fcmToken,
        'access_token': at,
        'refresh_token': rt,
        'email_address': email,
      }),
    );

    if (subResp.statusCode == 200) {
      print('✅ Gmail Pub/Sub subscription created');
    } else {
      print('⚠️ Failed to create Gmail subscription: ${subResp.body}');
    }

    return {'accessToken': at, 'refreshToken': rt};
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
    // final unsubscribeUrl = '${dotenv.env['SERVER_BASE_URL']}/api/delete_gmail_subscription';

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

      // // 2. Gmail 구독 삭제 요청
      // final unsubscribeResponse = await http.post(
      //   Uri.parse(unsubscribeUrl),
      //   headers: {'Content-Type': 'application/json'},
      // );

      // if (unsubscribeResponse.statusCode == 200) {
      //   print('✅ Gmail subscription deleted successfully');
      // } else {
      //   print('❌ Gmail subscription delete failed: ${unsubscribeResponse.statusCode} ${unsubscribeResponse.body}');
      // }

    } catch (e) {
      print('❌ Error during logout or unsubscribe: $e');
    }
  }


  @override
  Future<String?> getCurrentUserEmail() async {
    return _storage.read(key: 'gmail_user_email');
  }
}