import 'package:flutter/material.dart';
import 'package:mail_push_app/auth/auth_service.dart';
import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/screens/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mail_push_app/auth/gmail_auth.dart';
import 'package:mail_push_app/auth/outlook_auth.dart';

class HomeScreen extends StatefulWidget {
  final AuthService authService;
  final FcmService fcmService;
  final ApiClient apiClient;

  const HomeScreen({
    Key? key,
    required this.authService,
    required this.fcmService,
    required this.apiClient,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Email> _emails = [];
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    debugPrint('📌 HomeScreen: initState called');

    // 콜백 등록
    widget.fcmService.setOnNewEmailCallback(_onNewEmail);
    // 초기 메시지 확인
    _checkInitialMessage();
  }

  Future<void> _loadUserEmail() async {
    final email = await widget.authService.getCurrentUserEmail();
    setState(() {
      _userEmail = email;
    });
  }

  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await widget.fcmService.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🟠 초기 메시지 처리: ${initialMessage.messageId}');
      widget.fcmService.handleNewEmail(initialMessage);
    }
  }

  void _onNewEmail(Email email) {
    debugPrint('📬 onNewEmail: ${email.id}');
    if (!mounted) return;
    setState(() {
      if (!_emails.any((e) => e.id == email.id)) {
        _emails.insert(0, email);
      }
    });
    debugPrint('✅ setState fired, emails length=${_emails.length}');
  }

  Future<void> _handleLogout() async {
    try {
      await widget.authService.signOut();
      await _secureStorage.delete(key: 'fcm_token');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            fcmService: widget.fcmService,
            apiClient: widget.apiClient,
            gmailAuthService: GmailAuthService(),
            outlookAuthService: OutlookAuthService(),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ 로그아웃 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📌 HomeScreen: build called, emails: ${_emails.length}');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _userEmail != null
              ? '계정: $_userEmail'
              : '${widget.authService.serviceName} 푸시 데모',
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) async {
              if (value == 'logout') await _handleLogout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('로그아웃'),
              ),
            ],
          ),
        ],
      ),
      body: _emails.isEmpty
          ? const Center(child: Text('새 이메일 수신 대기 중...'))
          : ListView.builder(
              itemCount: _emails.length,
              itemBuilder: (context, index) {
                final email = _emails[index];
                return ListTile(
                  leading: Icon(
                    email.isNew ? Icons.mail : Icons.mail_outline,
                    color: email.isNew ? Colors.blue : Colors.grey,
                  ),
                  title: Text(email.subject),
                  onTap: () {
                    debugPrint('📩 Navigating to MailDetailPage for email: ${email.subject}');
                    setState(() => email.isNew = false);
                    Navigator.pushNamed(
                      context,
                      '/mail_detail',
                      arguments: email,
                    );
                  },
                );
              },
            ),
    );
  }
}