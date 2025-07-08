import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:mail_push_app/auth/auth_service.dart';
import 'package:mail_push_app/screens/home_screen.dart';
import 'package:mail_push_app/auth/icloud_auth.dart';
import 'package:mail_push_app/auth/gmail_auth.dart';
import 'package:mail_push_app/auth/outlook_auth.dart';

class LoginScreen extends StatefulWidget {
  final FcmService fcmService;
  final ApiClient apiClient;
  final ICloudAuthService iCloudAuthService;
  final GmailAuthService gmailAuthService;
  final OutlookAuthService outlookAuthService;

  const LoginScreen({
    Key? key,
    required this.fcmService,
    required this.apiClient,
    required this.iCloudAuthService,
    required this.gmailAuthService,
    required this.outlookAuthService,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;

  Future<void> _signIn(BuildContext context, AuthService authService) async {
    setState(() => _isLoading = true);
    try {
      final tokens = await authService.signIn();
      final accessToken = tokens['accessToken'];
      final refreshToken = tokens['refreshToken'];

      if (accessToken != null) {
        final fcmToken = await _secureStorage.read(key: 'fcm_token') ?? await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _secureStorage.write(key: 'fcm_token', value: fcmToken);

          final success = await widget.apiClient.registerTokens(
            fcmToken: fcmToken,
            accessToken: accessToken,
            refreshToken: refreshToken,
            service: authService.serviceName,
          );

          if (success) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  authService: authService,
                  fcmService: widget.fcmService,
                  apiClient: widget.apiClient,
                ),
              ),
            );
            return;
          } else {
            _showSnackBar('${authService.serviceName} 토큰 등록 실패');
          }
        } else {
          _showSnackBar('FCM 토큰 획득 실패');
        }
      } else {
        _showSnackBar('${authService.serviceName} 로그인 실패');
      }
    } catch (e) {
      _showSnackBar('로그인 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _signIn(context, widget.iCloudAuthService),
                    child: const Text('iCloud로 로그인'),
                  ),
                  ElevatedButton(
                    onPressed: () => _signIn(context, widget.gmailAuthService),
                    child: const Text('Gmail로 로그인'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _signIn(context, widget.outlookAuthService),
                    child: const Text('Outlook으로 로그인'),
                  ),
                ],
              ),
      ),
    );
  }
}
