import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mail_push_app/auth/auth_service.dart';
import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:mail_push_app/screens/login_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mail_push_app/auth/icloud_auth.dart';
import 'package:mail_push_app/auth/gmail_auth.dart';
import 'package:mail_push_app/auth/outlook_auth.dart';
import 'package:mail_push_app/menu/rule_list_page.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // EventChannel 사용을 위해 추가

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final List<Email> _emails = [];
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _userEmail;
  bool _isFetching = false; // 디바운싱 플래그

  // EventChannel 추가
  static const EventChannel _mailEventChannel = EventChannel('com.secure.mail_push_app/mail_events');

  bool get _isICloud => widget.authService.serviceName.toLowerCase() == 'icloud';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeFcmAndLoadData();

    // EventChannel로 실시간 이벤트 수신
    _mailEventChannel.receiveBroadcastStream().listen(_handleMailEvent,
        onError: (error) => debugPrint('🔔 EventChannel 오류: $error'));

    debugPrint('📌 HomeScreen: initState called');
  }

  Future<void> _initializeFcmAndLoadData() async {
    await widget.fcmService.initialize();
    widget.fcmService.setOnNewEmailCallback(_onNewEmail);
    await _loadUserEmail();
    await _checkInitialMessage();
    if (!_isICloud) {
      await _fetchAndSetEmails();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📌 AppLifecycleState: $state');
    if (state == AppLifecycleState.resumed && !_isICloud) {
      _fetchAndSetEmails();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _fetchAndSetEmails() async {
    if (_isFetching) return;
    setState(() {
      _isFetching = true;
    });
    try {
      final service = widget.authService.serviceName.toLowerCase();
      final emailAddress = await widget.authService.getCurrentUserEmail();
      debugPrint('👤 Current user email: $emailAddress');
      if (emailAddress == null || emailAddress.isEmpty) {
        throw Exception('로그인된 사용자 이메일이 없습니다.');
      }
      final emails = await widget.apiClient.fetchEmails(service, emailAddress);
      debugPrint('🔔 서버 응답 이메일 수: ${emails.length}');
      if (!mounted) return;
      setState(() {
        _emails
          ..clear()
          ..addAll(emails);
      });
      debugPrint('✅ 서버에서 이메일 ${emails.length}개 불러옴');
    } catch (e) {
      debugPrint('❌ 이메일 로딩 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이메일 로딩 실패: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  Future<void> _loadUserEmail() async {
    final email = await widget.authService.getCurrentUserEmail();
    setState(() {
      _userEmail = email;
    });
    debugPrint('👤 Loaded user email: $_userEmail');
  }

  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await widget.fcmService.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🟠 초기 메시지 처리: ${initialMessage.messageId}');
      widget.fcmService.handleNewEmail(initialMessage);
    }
  }

  void _onNewEmail(Email email) {
    debugPrint('📬 onNewEmail: ${email.id}, email_address: ${email.emailAddress}');
    if (!mounted) return;
    final currentEmail = _userEmail;
    if (currentEmail != null && email.emailAddress.isNotEmpty && email.emailAddress != currentEmail) {
      debugPrint('🚫 Ignoring email for ${email.emailAddress}, current user: $currentEmail');
      return;
    }
    setState(() {
      _emails.insert(0, email); // 새로운 이메일을 리스트 맨 위에 추가
    });
    debugPrint('✅ 새로운 이메일 추가: ${email.subject}');
  }

  // EventChannel에서 수신한 이벤트를 처리
  void _handleMailEvent(dynamic event) {
    if (event is Map<dynamic, dynamic>) {
      final mailData = Map<String, dynamic>.from(event);
      debugPrint('🔔 메일 이벤트 수신: $mailData');

      // subject에서 sender와 subject를 파싱하는 헬퍼 함수
      String _parseSender(String? subject) {
        if (subject == null || subject.isEmpty) return 'Unknown Sender';

        // "이름 <email>" 패턴을 찾기 위한 정규 표현식
        final senderPattern = RegExp(r'^"([^"]+)"\s+<([^>]+)>\s*-');
        final match = senderPattern.firstMatch(subject);

        if (match != null) {
          // sender 이름과 이메일 추출
          final name = match.group(1) ?? 'Unknown Sender'; // 그룹 1: 이름
          final email = match.group(2) ?? ''; // 그룹 2: 이메일
          return '$name <$email>';
        }

        return 'Unknown Sender';
      }

      // subject에서 sender 부분을 제거하고 실제 제목 추출
      String getParsedSubject(String? subject) {
        if (subject == null || subject.isEmpty) return 'No Subject';

        final senderPattern = RegExp(r'^"[^"]+"\s+<[^>]+>\s*-');
        return subject.replaceFirst(senderPattern, '').trim();
      }

      // Email.fromJson이 기대하는 구조로 mailData 정규화
      final normalizedData = {
        'messageId': mailData['messageId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'email_address': _userEmail ?? '',
        'subject': getParsedSubject(mailData['subject']),
        'sender': _parseSender(mailData['subject']) ?? 'Unknown Sender',
        'body': mailData['body'] ?? '',
        'received_at': mailData['received_at']?.toString() ?? DateTime.now().toIso8601String(),
        'read': mailData['read'] ?? false,
      };

      try {
        final email = Email.fromJson(normalizedData);
        debugPrint('📬 처리된 새 메일: ${email.id}, 제목: ${email.subject}, 발신자: ${email.sender}');
        _onNewEmail(email);
      } catch (e) {
        debugPrint('❌ 메일 이벤트 처리 오류: $e');
      }
    } else {
      debugPrint('🔔 유효하지 않은 이벤트 데이터: $event');
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      await widget.authService.signOut();
      await _secureStorage.delete(key: 'fcm_token');
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            fcmService: widget.fcmService,
            apiClient: widget.apiClient,
            iCloudAuthService: ICloudAuthService(),
            gmailAuthService: GmailAuthService(),
            outlookAuthService: OutlookAuthService(),
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      debugPrint('❌ 로그아웃 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그아웃 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_userEmail != null
            ? '계정: $_userEmail'
            : '${widget.authService.serviceName}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) async {
              if (value == 'logout') {
                await _handleLogout();
              } else if  (value == 'rules') {
                //규칙 페이지로 이동. 
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RuleListPage()),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem<String>(
                value: 'rules',
                child: Text('메일 규칙'), // 또는 'Rules'
              ),
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
                    email.read ? Icons.mail_outline : Icons.mail,
                    color: email.read ? Colors.grey : Colors.blue,
                  ),
                  title: Text(email.subject),
                  subtitle: Text(
                    '${email.sender} · ${DateFormat('yyyy-MM-dd HH:mm').format(email.receivedAt.add(const Duration(hours: 9)))}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    debugPrint('📩 Navigating to MailDetailPage for email: ${email.subject}');
                    if (!email.read) {
                      setState(() {
                        _emails[index] = Email(
                          id: email.id,
                          emailAddress: email.emailAddress,
                          subject: email.subject,
                          sender: email.sender,
                          body: email.body,
                          receivedAt: email.receivedAt,
                          read: true,
                        );
                      });
                    }
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