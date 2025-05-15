import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:mail_push_app/auth/auth_service.dart';
import 'package:mail_push_app/screens/home_screen.dart';

class LoginScreen extends StatelessWidget {
  final FcmService fcmService;
  final ApiClient apiClient;
  final GmailAuthService gmailAuthService;
  final OutlookAuthService outlookAuthService;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  const LoginScreen({
    Key? key,
    required this.fcmService,
    required this.apiClient,
    required this.gmailAuthService,
    required this.outlookAuthService,
  }) : super(key: key);

  Future<void> _signIn(BuildContext context, AuthService authService) async {
    try {
      final tokens = await authService.signIn();
      final accessToken = tokens['accessToken'];
      final refreshToken = tokens['refreshToken'];

      if (accessToken != null) {
        final fcmToken = await _secureStorage.read(key: 'fcm_token') ?? await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          // FCM 토큰 저장
          await _secureStorage.write(key: 'fcm_token', value: fcmToken);
          
          // 토큰 등록
          final success = await apiClient.registerTokens(
            fcmToken: fcmToken,
            accessToken: accessToken,
            refreshToken: refreshToken,
            service: authService.serviceName,
          );
          
          if (success) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  authService: authService,
                  fcmService: fcmService,
                  apiClient: apiClient,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${authService.serviceName} 토큰 등록 실패')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('FCM 토큰 획득 실패')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${authService.serviceName} 로그인 실패')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _signIn(context, gmailAuthService),
              child: const Text('Gmail로 로그인'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _signIn(context, outlookAuthService),
              child: const Text('Outlook으로 로그인'),
            ),
          ],
        ),
      ),
    );
  }
}