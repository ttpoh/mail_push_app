import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:mail_push_app/fcm/fcm_service.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'package:mail_push_app/auth/auth_service.dart';
import 'package:mail_push_app/screens/home/home_screen.dart';
import 'package:mail_push_app/auth/icloud_auth.dart';
import 'package:mail_push_app/auth/gmail_auth.dart';
import 'package:mail_push_app/auth/outlook_auth.dart';

// i18n
import 'package:mail_push_app/l10n/app_localizations.dart';

// UI kit
import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

class LoginScreen extends StatefulWidget {
  final FcmService fcmService;
  final ApiClient apiClient;
  final ICloudAuthService iCloudAuthService;
  final GmailAuthService gmailAuthService;
  final OutlookAuthService outlookAuthService;
  final void Function(Locale)? onChangeLocale;

  const LoginScreen({
    Key? key,
    required this.fcmService,
    required this.apiClient,
    required this.iCloudAuthService,
    required this.gmailAuthService,
    required this.outlookAuthService,
    this.onChangeLocale,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;

  Future<void> _signIn(BuildContext context, AuthService authService) async {
    final t = AppLocalizations.of(context)!;
    setState(() => _isLoading = true);
    try {
      final tokens = await authService.signIn();
      final accessToken = tokens['accessToken'];
      final refreshToken = tokens['refreshToken'];

      if (accessToken != null) {
        final fcmToken = await _secureStorage.read(key: 'fcm_token') ??
            await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _secureStorage.write(key: 'fcm_token', value: fcmToken);

          final ok = await widget.apiClient.registerTokens(
            fcmToken: fcmToken,
            accessToken: accessToken,
            refreshToken: refreshToken,
            service: authService.serviceName,
          );

          if (ok) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(
                  authService: authService,
                  fcmService: widget.fcmService,
                  apiClient: widget.apiClient,
                  onChangeLocale: widget.onChangeLocale,
                ),
              ),
            );
            return;
          } else {
            _snack(t.tokenRegisterFailed(authService.serviceName));
          }
        } else {
          _snack(t.fcmTokenFetchFailed);
        }
      } else {
        _snack(t.loginFailed(authService.serviceName));
      }
    } catch (e) {
      _snack(t.loginError('$e'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    // 버튼은 흰 배경, 텍스트/리플/단색 아이콘 틴트는 프라이머리 블루
    final Color buttonBg = Colors.white;
    final Color buttonFg = ec.eventPrimaryColor;

    return Scaffold(
      backgroundColor: ec.eventLightBackgroundColor,
      appBar: null, // 상단 "로그인" 텍스트 제거
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ec.eventLightCardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ec.eventLightBorderColor),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _UiKitButton(
                            label: '',
                            background: buttonBg,
                            foreground: buttonFg,
                            leading: const _Logo('assets/icons/scalable_iCloud.svg', scale: 4),
                            onPressed: () =>
                                _signIn(context, widget.iCloudAuthService),
                          ),
                          const SizedBox(height: 16),
                          _UiKitButton(
                            label: '',
                            background: buttonBg,
                            foreground: buttonFg,
                            leading: Transform.translate(
                              offset: Offset(-15, 0), // ← 원하는 만큼 왼쪽(-) 이동
                              child: _Logo('assets/icons/scalable_Google.svg', scale: 3.5),
                            ),
                            onPressed: () =>
                                _signIn(context, widget.gmailAuthService),
                          ),
                          const SizedBox(height: 16),
                          _UiKitButton(
                            label: '',
                            background: buttonBg,
                            foreground: buttonFg,
                            leading: const _Logo('assets/icons/scalable_Yahoo.svg', scale: 1.8),
                            onPressed: () => _snack('Yahoo!는 준비 중입니다.'),
                          ),
                          const SizedBox(height: 16),
                          _UiKitButton(
                            label: '',
                            background: buttonBg,
                            foreground: buttonFg,
                            leading: const _Logo('assets/icons/scalable_Outlook.svg', scale: 1.3),
                            onPressed: () =>
                                _signIn(context, widget.outlookAuthService),
                          ),
                          const SizedBox(height: 24),
                          // 언어 변경 pill (흰 배경, 아이콘 파랑) - 기존 유지
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: ec.eventLightBorderColor),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: _LanguagePill(
                              onSelected: widget.onChangeLocale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// UI kit 스타일 버튼 (높이 64)
class _UiKitButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground; // 텍스트/리플 색
  final Widget? leading;
  final VoidCallback onPressed;

  const _UiKitButton({
    Key? key,
    required this.label,
    required this.background,
    required this.onPressed,
    this.leading,
    this.foreground = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double height = 64;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground, // 텍스트/리플 컬러는 여기서 제어
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Text(label),
          ],
        ),
      ),
    );
  }
}

/// 워드마크 로고: 세로 22px 고정, 가로는 비율 유지. 버튼 안에서 균일한 영역 확보.
// 워드마크 로고: 세로 22px 고정, scale로 미세 조정
class _Logo extends StatelessWidget {
  final String asset;
  final double height;
  final double width;   // 버튼 안에서 차지할 최대 가로폭
  final double scale;   // 시각 크기 보정 (1.0 = 그대로)

  const _Logo(
    this.asset, {
    this.height = 22,
    this.width = 140,   // 필요시 120~160 사이에서 조절
    this.scale = 1.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.centerLeft,
          child: SvgPicture.asset(
            asset,
            height: height,        // 세로 고정, 가로는 비율 유지
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// 가운데 정렬 언어 드롭다운 (원본 유지)
class _LanguagePill extends StatelessWidget {
  final void Function(Locale)? onSelected;
  const _LanguagePill({Key? key, this.onSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return PopupMenuButton<Locale>(
      tooltip: '',
      color: Colors.white, // 팝업 배경 흰색
      onSelected: (locale) => onSelected?.call(locale),
      itemBuilder: (ctx) => [
        PopupMenuItem(
            value: const Locale('ko'),
            child: Row(children: [const Text('🇰🇷 '), Text(t.langKorean)])),
        PopupMenuItem(
            value: const Locale('en'),
            child: Row(children: [
              const Text('🇺🇸 '),
              Text(t.langEnglish.toUpperCase())
            ])),
        PopupMenuItem(
            value: const Locale('ja'),
            child: Row(children: [const Text('🔴 '), Text(t.langJapanese)])),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public, size: 18, color: ec.eventPrimaryColor),
          const SizedBox(width: 8),
          Icon(Icons.arrow_drop_down,
              color: ec.eventPrimaryColor.withOpacity(0.7)),
        ],
      ),
    );
  }
}
