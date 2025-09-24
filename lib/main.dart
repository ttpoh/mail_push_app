import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:mail_push_app/screens/login_screen.dart';
import 'package:mail_push_app/screens/home/home_screen.dart';
import 'package:mail_push_app/screens/mail_detail_page.dart';
import 'package:mail_push_app/auth/auth_service.dart';
import 'package:mail_push_app/auth/icloud_auth.dart';
import 'package:mail_push_app/auth/gmail_auth.dart';
import 'package:mail_push_app/auth/outlook_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/firebase_options.dart';
import 'package:mail_push_app/utils/navigation_service.dart';
import 'package:mail_push_app/models/email.dart';
import 'package:flutter/services.dart';
import 'package:mail_push_app/device/device_id_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ✅ i18n
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mail_push_app/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

// ✅ 로케일 저장/불러오기 헬퍼
class AppLocale {
  static const _key = 'localeCode';
  static Future<Locale?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    return code == null ? null : Locale(code);
  }
  static Future<void> save(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env");
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('❌ Firebase 초기화 실패: $e');
    return;
  }

  final fcmService = FcmService();
  final apiClient = ApiClient();
  final iCloudAuthService = ICloudAuthService();
  final gmailAuthService = GmailAuthService();
  final outlookAuthService = OutlookAuthService();
  const storage = FlutterSecureStorage();

  // Critical Alert 권한 요청
  final criticalAlertService = CriticalAlertService();
  await criticalAlertService.requestCriticalAlertPermission();

  // FCM 초기화
  await fcmService.initialize();

  // ✅ 디바이스 식별자 확보
  final identity = await DeviceIdService.getIdentity();
  debugPrint('✅ Device ID=${identity.deviceId}, platform=${identity.platform}');

  // ✅ FCM 토큰 확보
  final fcmToken = await FirebaseMessaging.instance.getToken();
  debugPrint('✅ FCM token=$fcmToken');

  // ✅ 알람 기본값을 "최초 1회만" 서버에 시드
  //    이후 실행에서는 유저 설정을 덮어쓰지 않기 위해 기본값을 다시 보내지 않음
  const seededKey = 'alarm_defaults_seeded'; // SecureStorage 키
  final seeded = (await storage.read(key: seededKey)) == 'true';

  if (!seeded) {
    final ok = await apiClient.upsertAlarmSetting(
      deviceId: identity.deviceId,
      platform: identity.platform, // 최초 등록이므로 플랫폼까지 전달
      fcmToken: fcmToken,
      normalOn: true,              // 기본값 시드
      criticalOn: false,
      criticalUntilStopped: false,
      overwrite: false,            // 기본값이더라도 강제 덮어쓰기는 하지 않음
    );
    debugPrint('✅ 최초 기본값 시드 upsertAlarmSetting=$ok');

    if (ok) {
      await storage.write(key: seededKey, value: 'true');
    }
  } else {
    // 이미 기본값을 시드했다면, 실행 시에는 디바이스/토큰만 업서트(플래그는 null로 미전달)
    final ok = await apiClient.upsertAlarmSetting(
      deviceId: identity.deviceId,
      platform: '',                // '' → 서버에서 플랫폼 미변경(백엔드 규칙)
      fcmToken: fcmToken,
      // normalOn/criticalOn/criticalUntilStopped 미전달 → 서버 미변경
      overwrite: false,
    );
    debugPrint('🔄 실행 시 기기/토큰만 업서트 upsertAlarmSetting=$ok');
  }

  // 자동 로그인 확인
  final loginResult = await _checkAutoLogin(
    iCloudAuthService, gmailAuthService, outlookAuthService, apiClient,
  );

  runApp(MyApp(
    fcmService: fcmService,
    apiClient: apiClient,
    iCloudAuthService: iCloudAuthService,
    gmailAuthService: gmailAuthService,
    outlookAuthService: outlookAuthService,
    isLoggedIn: loginResult.isLoggedIn,
    authService: loginResult.authService,
  ));
}

Future<LoginResult> _checkAutoLogin(
  ICloudAuthService iCloudAuthService,
  GmailAuthService gmailAuthService,
  OutlookAuthService outlookAuthService,
  ApiClient apiClient,
) async {
  const storage = FlutterSecureStorage();
  final iCloudAccessToken = await storage.read(key: 'icloud_access_token');
  final gmailAccessToken = await storage.read(key: 'gmail_access_token');
  final outlookAccessToken = await storage.read(key: 'outlook_access_token');
  if (iCloudAccessToken != null) {
    final isValid = await apiClient.validateToken(iCloudAccessToken, 'icloud');
    if (isValid) return LoginResult(isLoggedIn: true, authService: iCloudAuthService);
    await iCloudAuthService.signOut();
  } else if (gmailAccessToken != null) {
    final isValid = await apiClient.validateToken(gmailAccessToken, 'gmail');
    if (isValid) return LoginResult(isLoggedIn: true, authService: gmailAuthService);
    await gmailAuthService.signOut();
  } else if (outlookAccessToken != null) {
    final isValid = await apiClient.validateToken(outlookAccessToken, 'outlook');
    if (isValid) return LoginResult(isLoggedIn: true, authService: outlookAuthService);
    await outlookAuthService.signOut();
  }
  return LoginResult(isLoggedIn: false, authService: null);
}

class LoginResult {
  final bool isLoggedIn;
  final AuthService? authService;
  LoginResult({required this.isLoggedIn, this.authService});
}

// ✅ MyApp: Stateful (런타임 언어 변경 지원)
class MyApp extends StatefulWidget {
  final FcmService fcmService;
  final ApiClient apiClient;
  final ICloudAuthService iCloudAuthService;
  final GmailAuthService gmailAuthService;
  final OutlookAuthService outlookAuthService;
  final bool isLoggedIn;
  final AuthService? authService;

  const MyApp({
    Key? key,
    required this.fcmService,
    required this.apiClient,
    required this.iCloudAuthService,
    required this.gmailAuthService,
    required this.outlookAuthService,
    required this.isLoggedIn,
    required this.authService,
  }) : super(key: key);

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final saved = await AppLocale.load();
    if (!mounted) return;
    setState(() => _locale = saved);
  }

  Future<void> setLocale(Locale locale) async {
    await AppLocale.save(locale);
    if (!mounted) return;
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.instance.navigatorKey,
      debugShowCheckedModeBanner: false,

      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,

      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('ko'), Locale('ja')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],

      initialRoute: widget.isLoggedIn && widget.authService != null ? '/home' : '/login',
      routes: {
        '/home': (context) => HomeScreen(
              authService: widget.authService!,
              fcmService: widget.fcmService,
              apiClient: widget.apiClient,
              // ✅ 홈에서도 언어 변경 가능
              onChangeLocale: setLocale,
            ),
        '/login': (context) => LoginScreen(
              fcmService: widget.fcmService,
              apiClient: widget.apiClient,
              iCloudAuthService: widget.iCloudAuthService,
              gmailAuthService: widget.gmailAuthService,
              outlookAuthService: widget.outlookAuthService,
              // ✅ 로그인에서도 언어 변경 가능
              onChangeLocale: setLocale,
            ),
        '/mail_detail': (context) {
          final email = ModalRoute.of(context)!.settings.arguments as Email;
          return MailDetailPage(email: email);
        },
      },
    );
  }
}
