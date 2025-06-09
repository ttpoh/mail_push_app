import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:mail_push_app/screens/login_screen.dart';
import 'package:mail_push_app/screens/home_screen.dart';
import 'package:mail_push_app/screens/mail_detail_page.dart';
import 'package:mail_push_app/auth/auth_service.dart';
import 'package:mail_push_app/auth/gmail_auth.dart';
import 'package:mail_push_app/auth/outlook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/firebase_options.dart';
import 'package:mail_push_app/utils/navigation_service.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:flutter/services.dart'; // Method Channel을 위한 임포트

// Critical Alerts 권한 요청 서비스
class CriticalAlertService {
  static const platform = MethodChannel('com.secure.mail_push_app/critical_alerts');

  Future<bool> requestCriticalAlertPermission() async {
    try {
      final bool granted = await platform.invokeMethod('requestCriticalAlertPermission');
      debugPrint('📢 Critical Alert 권한 허용 여부: $granted');
      return granted;
    } catch (e) {
      debugPrint('❌ Critical Alert 권한 요청 실패: $e');
      return false;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('❌ Firebase 초기화 실패: $e');
    return;
  }

  // FCM 서비스 싱글톤 생성 및 초기화
  final fcmService = FcmService();
  
  // Critical Alert 권한 요청
  final criticalAlertService = CriticalAlertService();
  await criticalAlertService.requestCriticalAlertPermission();
  
  await fcmService.initialize();

  final apiClient = ApiClient();
  final gmailAuthService = GmailAuthService();
  final outlookAuthService = OutlookAuthService();

  // 자동 로그인 확인
  final loginResult = await _checkAutoLogin(
    gmailAuthService,
    outlookAuthService,
    apiClient,
  );
  await dotenv.load(fileName: "assets/.env");

  runApp(MyApp(
    fcmService: fcmService,
    apiClient: apiClient,
    gmailAuthService: gmailAuthService,
    outlookAuthService: outlookAuthService,
    isLoggedIn: loginResult.isLoggedIn,
    authService: loginResult.authService,
  ));
}

Future<LoginResult> _checkAutoLogin(
  GmailAuthService gmailAuthService,
  OutlookAuthService outlookAuthService,
  ApiClient apiClient,
) async {
  const storage = FlutterSecureStorage();
  final gmailAccessToken = await storage.read(key: 'gmail_access_token');
  final outlookAccessToken = await storage.read(key: 'outlook_access_token');

  if (gmailAccessToken != null) {
    final isValid = await apiClient.validateToken(gmailAccessToken, 'gmail');
    if (isValid) {
      return LoginResult(isLoggedIn: true, authService: gmailAuthService);
    } else {
      await gmailAuthService.signOut();
    }
  } else if (outlookAccessToken != null) {
    final isValid = await apiClient.validateToken(outlookAccessToken, 'outlook');
    if (isValid) {
      return LoginResult(isLoggedIn: true, authService: outlookAuthService);
    } else {
      await outlookAuthService.signOut();
    }
  }
  return LoginResult(isLoggedIn: false, authService: null);
}

class LoginResult {
  final bool isLoggedIn;
  final AuthService? authService;

  LoginResult({required this.isLoggedIn, this.authService});
}

class MyApp extends StatelessWidget {
  final FcmService fcmService;
  final ApiClient apiClient;
  final GmailAuthService gmailAuthService;
  final OutlookAuthService outlookAuthService;
  final bool isLoggedIn;
  final AuthService? authService;

  const MyApp({
    Key? key,
    required this.fcmService,
    required this.apiClient,
    required this.gmailAuthService,
    required this.outlookAuthService,
    required this.isLoggedIn,
    required this.authService,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.instance.navigatorKey, // NavigationService로 변경
      title: '이메일 푸시 앱',
      debugShowCheckedModeBanner: false,
      initialRoute: isLoggedIn && authService != null ? '/home' : '/login',
      routes: {
        '/home': (context) => HomeScreen(
              authService: authService!,
              fcmService: fcmService,
              apiClient: apiClient,
            ),
        '/login': (context) => LoginScreen(
              fcmService: fcmService,
              apiClient: apiClient,
              gmailAuthService: gmailAuthService,
              outlookAuthService: outlookAuthService,
            ),
        '/mail_detail': (context) {
          final email = ModalRoute.of(context)!.settings.arguments as Email;
          return MailDetailPage(email: email);
        },
      },
    );
  }
}