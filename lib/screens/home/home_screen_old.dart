// // lib/screens/home_screen.dart
// import 'dart:convert';
// import 'dart:io' show Platform;
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:mail_push_app/auth/auth_service.dart';
// import 'package:mail_push_app/fcm/fcm_service.dart';
// import 'package:mail_push_app/api/api_client.dart';
// import 'package:mail_push_app/models/email.dart';
// import 'package:mail_push_app/screens/login_screen.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:mail_push_app/auth/icloud_auth.dart';
// import 'package:mail_push_app/auth/gmail_auth.dart';
// import 'package:mail_push_app/auth/outlook_auth.dart';
// import 'package:mail_push_app/menu/rule_list_page.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter/services.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:android_intent_plus/android_intent.dart';
// import 'package:package_info_plus/package_info_plus.dart';
// import 'package:permission_handler/permission_handler.dart';

// // ui_kit
// import 'package:mail_push_app/ui_kit/widgets/widgets.dart' as uk;
// import 'package:mail_push_app/ui_kit/constant/event_color.dart' as ec;

// import 'package:mail_push_app/models/event_all_model.dart'; // Event 모델

// // ✅ i18n
// import 'package:mail_push_app/l10n/app_localizations.dart';

// // ─────────────────────────────────────────────────────────────────────────────
// // UI-Kit ↔ Material 브리지: ui_kit 색/반경/그림자 통일 사용
// // ─────────────────────────────────────────────────────────────────────────────
// class UiKit {
//   static Color primary(BuildContext c) => ec.eventPrimaryColor;
//   static Color success(BuildContext c) => ec.greenRight; // 초록 점
//   static Color danger(BuildContext c) => ec.eventErrorColor; // 빨강 점
//   static Color cardBg(BuildContext c) => Theme.of(c).cardColor; // eventLightCardColor / eventDarkCardColor
//   static Color onSurfaceSubtle(BuildContext c) =>
//       Theme.of(c).textTheme.bodySmall?.color?.withOpacity(0.70) ??
//       const Color(0x99000000);
//   static double radiusLg(BuildContext c) => 18.0;
//   static List<BoxShadow> softShadow(Brightness b) => [
//         BoxShadow(
//           blurRadius: 10,
//           offset: const Offset(0, 4),
//           // 라이트/다크 모두 무난한 얕은 그림자
//           color: (b == Brightness.dark
//                   ? Colors.black.withOpacity(0.35)
//                   : Colors.black.withOpacity(0.05)),
//         ),
//       ];
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // 상단 계정 헤더 카드
// // ─────────────────────────────────────────────────────────────────────────────
// class _AccountHeaderCard extends StatelessWidget {
//   final String title;
//   final VoidCallback onSettings;
//   const _AccountHeaderCard({required this.title, required this.onSettings});

//   @override
//   Widget build(BuildContext context) {
//     final r = UiKit.radiusLg(context);
//     final brightness = Theme.of(context).brightness;

//     return Container(
//       decoration: BoxDecoration(
//         color: UiKit.cardBg(context),
//         borderRadius: BorderRadius.circular(r + 6),
//         boxShadow: UiKit.softShadow(brightness),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//       child: Row(
//         children: [
//           CircleAvatar(
//             radius: 20,
//             backgroundColor: UiKit.primary(context).withOpacity(0.12),
//             child: Icon(Icons.person, color: UiKit.primary(context)),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               title,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: Theme.of(context)
//                   .textTheme
//                   .titleMedium
//                   ?.copyWith(fontWeight: FontWeight.w800),
//             ),
//           ),
//           IconButton(
//             tooltip: '설정',
//             onPressed: onSettings,
//             icon: const Icon(Icons.settings),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // 메일 카드 아이템
// // ─────────────────────────────────────────────────────────────────────────────
// class _EmailCard extends StatelessWidget {
//   final Email email;
//   final VoidCallback onTap;
//   const _EmailCard({required this.email, required this.onTap});

//   bool _isCritical(Email e) {
//     final s = (e.subject + ' ' + e.body).toLowerCase();
//     return s.contains('긴급') || s.contains('urgent') || s.contains('emergency');
//   }

//   @override
//   Widget build(BuildContext context) {
//     final r = UiKit.radiusLg(context);
//     final brightness = Theme.of(context).brightness;
//     final isCritical = _isCritical(email);

//     return Container(
//       decoration: BoxDecoration(
//         color: UiKit.cardBg(context),
//         borderRadius: BorderRadius.circular(r),
//         boxShadow: UiKit.softShadow(brightness),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//       child: InkWell(
//         borderRadius: BorderRadius.circular(r),
//         onTap: onTap,
//         child: Row(
//           children: [
//             // 왼쪽 파란 메일 아이콘 배지
//             Container(
//               width: 36,
//               height: 36,
//               decoration: BoxDecoration(
//                 color: UiKit.primary(context).withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(
//                 email.read ? Icons.mail_outline : Icons.mail,
//                 color: UiKit.primary(context),
//                 size: 20,
//               ),
//             ),
//             const SizedBox(width: 12),

//             // 중앙 텍스트
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // 제목
//                   Text(
//                     email.subject.isEmpty ? '제목 없음' : email.subject,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: Theme.of(context)
//                         .textTheme
//                         .titleMedium
//                         ?.copyWith(fontWeight: FontWeight.w700),
//                   ),
//                   const SizedBox(height: 4),
//                   // 보낸사람 · 시간
//                   Text(
//                     '${email.sender} · ${DateFormat('yyyy-MM-dd HH:mm').format(email.receivedAt.add(const Duration(hours: 9)))}',
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: Theme.of(context)
//                         .textTheme
//                         .bodySmall
//                         ?.copyWith(color: UiKit.onSurfaceSubtle(context)),
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(width: 8),

//             // 오른쪽 상태 점
//             Container(
//               width: 10,
//               height: 10,
//               decoration: BoxDecoration(
//                 color: isCritical
//                     ? UiKit.danger(context)
//                     : UiKit.success(context),
//                 shape: BoxShape.circle,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────────────────────────────────────
// // HomeScreen 본문
// // ─────────────────────────────────────────────────────────────────────────────
// class HomeScreen extends StatefulWidget {
//   final AuthService authService;
//   final FcmService fcmService;
//   final ApiClient apiClient;

//   // ✅ 언어 변경 콜백
//   final void Function(Locale)? onChangeLocale;

//   const HomeScreen({
//     Key? key,
//     required this.authService,
//     required this.fcmService,
//     required this.apiClient,
//     this.onChangeLocale,
//   }) : super(key: key);

//   @override
//   _HomeScreenState createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
//   final List<Email> _emails = [];
//   final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
//   String? _userEmail;
//   bool _isFetching = false;

//   // ===== 알림 설정 저장 키 =====
//   static const _kNormalOnKey = 'alarm_normal_on';
//   static const _kCriticalOnKey = 'alarm_critical_on';
//   static const _kCriticalUntilKey = 'alarm_critical_until_stopped';

//   // ===== 알림 설정 상태값 =====
//   bool _normalOn = true;
//   bool _criticalOn = false;
//   bool _criticalUntilStopped = false;

//   static const EventChannel _mailEventChannel =
//       EventChannel('com.secure.mail_push_app/mail_events');

//   bool get _isICloud =>
//       widget.authService.serviceName.toLowerCase() == 'icloud';

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _loadAlarmSettings();
//     _initializeFcmAndLoadData();

//     _mailEventChannel.receiveBroadcastStream().listen(
//       _handleMailEvent,
//       onError: (error) => debugPrint('🔔 EventChannel 오류: $error'),
//     );
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   Future<void> _initializeFcmAndLoadData() async {
//     try {
//       await widget.fcmService.initialize();
//     } catch (e) {
//       debugPrint('⚠️ FCM 초기화 실패: $e');
//     }
//     widget.fcmService.setOnNewEmailCallback(_onNewEmail);
//     await _loadUserEmail();
//     await _checkInitialMessage();
//     if (!_isICloud) {
//       await _fetchAndSetEmails();
//     }
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     if (state == AppLifecycleState.resumed && !_isICloud) {
//       _fetchAndSetEmails();
//     }
//   }

//   Future<void> _loadAlarmSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() {
//       _normalOn = prefs.getBool(_kNormalOnKey) ?? true;
//       _criticalOn = prefs.getBool(_kCriticalOnKey) ?? false;
//       _criticalUntilStopped = prefs.getBool(_kCriticalUntilKey) ?? false;
//     });
//   }

//   Future<void> _persistSettings() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(_kNormalOnKey, _normalOn);
//     await prefs.setBool(_kCriticalOnKey, _criticalOn);
//     await prefs.setBool(_kCriticalUntilKey, _criticalUntilStopped);
//   }

//   Future<void> _openAppNotificationSettings() async {
//     final t = AppLocalizations.of(context)!;
//     try {
//       if (Platform.isAndroid) {
//         final info = await PackageInfo.fromPlatform();
//         final intent = AndroidIntent(
//           action: 'android.settings.APP_NOTIFICATION_SETTINGS',
//           arguments: <String, dynamic>{
//             'android.provider.extra.APP_PACKAGE': info.packageName,
//             'app_package': info.packageName,
//             'app_uid': 0,
//           },
//         );
//         await intent.launch();
//       } else if (Platform.isIOS) {
//         await openAppSettings();
//       }
//     } catch (e) {
//       debugPrint('⚠️ 알림 설정 화면 이동 실패: $e');
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text(t.settingsOpenError)));
//     }
//   }

//   void _openAlarmDialog() {
//     final t = AppLocalizations.of(context)!;
//     showDialog(
//       context: context,
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setModal) => AlertDialog(
//           title: Text(t.alarmSettingsTitle),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 SwitchListTile(
//                   contentPadding: EdgeInsets.zero,
//                   title: Text(t.generalAlarmLabel),
//                   subtitle: Text(t.generalAlarmSubtitle),
//                   value: _normalOn,
//                   onChanged: (v) {
//                     setModal(() => _normalOn = v);
//                     setState(() => _normalOn = v);
//                     _persistSettings();
//                   },
//                 ),
//                 const Divider(height: 16),
//                 SwitchListTile(
//                   contentPadding: EdgeInsets.zero,
//                   title: Text(t.criticalAlarmLabel),
//                   subtitle: Text(t.criticalAlarmSubtitle),
//                   value: _criticalOn,
//                   onChanged: (v) {
//                     setModal(() => _criticalOn = v);
//                     setState(() => _criticalOn = v);
//                     _persistSettings();
//                   },
//                 ),
//                 const SizedBox(height: 8),
//                 IgnorePointer(
//                   ignoring: !_criticalOn,
//                   child: Opacity(
//                     opacity: _criticalOn ? 1 : 0.5,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(t.criticalAlarmModeLabel),
//                         const SizedBox(height: 8),
//                         SegmentedButton<bool>(
//                           segments: [
//                             ButtonSegment(value: false, label: Text(t.ringOnce)),
//                             ButtonSegment(
//                                 value: true, label: Text(t.ringUntilStopped)),
//                           ],
//                           selected: {_criticalUntilStopped},
//                           onSelectionChanged: (s) {
//                             final v = s.first;
//                             setModal(() => _criticalUntilStopped = v);
//                             setState(() => _criticalUntilStopped = v);
//                             _persistSettings();
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 12),
//                 const Divider(height: 16),
//                 ListTile(
//                   contentPadding: EdgeInsets.zero,
//                   leading: const Icon(Icons.app_settings_alt),
//                   title: Text(t.openAppNotificationSettings),
//                   onTap: _openAppNotificationSettings,
//                 ),
//               ],
//             ),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(ctx),
//               child: Text(t.close),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _fetchAndSetEmails() async {
//     if (_isFetching) return;
//     setState(() => _isFetching = true);
//     try {
//       final service = widget.authService.serviceName.toLowerCase();
//       final emailAddress = await widget.authService.getCurrentUserEmail();
//       if (emailAddress == null || emailAddress.isEmpty) {
//         throw Exception(AppLocalizations.of(context)!.noLoggedInEmail);
//       }
//       final emails = await widget.apiClient.fetchEmails(service, emailAddress);
//       if (!mounted) return;
//       setState(() {
//         _emails
//           ..clear()
//           ..addAll(emails);
//       });
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text(AppLocalizations.of(context)!.emailLoadFailed('$e'))),
//       );
//     } finally {
//       if (mounted) setState(() => _isFetching = false);
//     }
//   }

//   Future<void> _loadUserEmail() async {
//     final email = await widget.authService.getCurrentUserEmail();
//     if (!mounted) return;
//     setState(() {
//       _userEmail = email;
//     });
//   }

//   Future<void> _checkInitialMessage() async {
//     try {
//       RemoteMessage? initialMessage =
//           await widget.fcmService.getInitialMessage();
//       if (initialMessage != null) {
//         widget.fcmService.handleNewEmail(initialMessage);
//       }
//     } catch (e) {
//       debugPrint('⚠️ 초기 메시지 가져오기 실패: $e');
//     }
//   }

//   Future<void> _onNewEmail(Email email) async {
//     if (!mounted) return;
//     final currentEmail = _userEmail;
//     if (currentEmail != null &&
//         email.emailAddress.isNotEmpty &&
//         email.emailAddress != currentEmail) {
//       return;
//     }

//     if (_isFetching) return;
//     setState(() => _isFetching = true);

//     try {
//       final service = widget.authService.serviceName.toLowerCase();
//       final emailAddress = await widget.authService.getCurrentUserEmail();
//       if (emailAddress == null || emailAddress.isEmpty) return;

//       DateTime? newestReceivedAt =
//           _emails.isNotEmpty ? _emails.first.receivedAt : null;

//       List<Email> newEmails;
//       if (newestReceivedAt != null) {
//         newEmails = await widget.apiClient.fetchEmails(
//           service,
//           emailAddress,
//           since: newestReceivedAt.toIso8601String(),
//         );
//       } else {
//         newEmails = await widget.apiClient.fetchEmails(service, emailAddress);
//       }

//       final existingIds = _emails.map((e) => e.id).toSet();
//       final merged = <Email>[];
//       for (var em in newEmails) {
//         if (!existingIds.contains(em.id)) merged.add(em);
//       }
//       merged.addAll(_emails);

//       if (!mounted) return;
//       setState(() {
//         _emails
//           ..clear()
//           ..addAll(merged);
//       });
//     } catch (e) {
//       debugPrint('❌ _onNewEmail 동기화 실패: $e');
//     } finally {
//       if (mounted) setState(() => _isFetching = false);
//     }
//   }

//   void _handleMailEvent(dynamic event) {
//     if (event is Map<dynamic, dynamic>) {
//       final mailData = Map<String, dynamic>.from(event);

//       String _parseSender(String? subject) {
//         if (subject == null || subject.isEmpty) {
//           return AppLocalizations.of(context)!.unknownSender;
//         }
//         final senderPattern = RegExp(r'^"([^"]+)"\s+<([^>]+)>\s*-');
//         final match = senderPattern.firstMatch(subject);
//         if (match != null) {
//           final name =
//               match.group(1) ?? AppLocalizations.of(context)!.unknownSender;
//           final email = match.group(2) ?? '';
//           return '$name <$email>';
//         }
//         return AppLocalizations.of(context)!.unknownSender;
//       }

//       String getParsedSubject(String? subject) {
//         if (subject == null || subject.isEmpty) {
//           return AppLocalizations.of(context)!.noSubject;
//         }
//         final senderPattern = RegExp(r'^"[^"]+"\s+<[^>]+>\s*-');
//         return subject.replaceFirst(senderPattern, '').trim();
//       }

//       final normalizedData = {
//         'messageId': mailData['messageId']?.toString() ??
//             DateTime.now().millisecondsSinceEpoch.toString(),
//         'email_address': _userEmail ?? '',
//         'subject': getParsedSubject(mailData['subject']),
//         'sender': _parseSender(mailData['subject']),
//         'body': mailData['body'] ?? '',
//         'received_at': mailData['received_at']?.toString() ??
//             DateTime.now().toIso8601String(),
//         'read': mailData['read'] ?? false,
//       };

//       try {
//         final email = Email.fromJson(normalizedData);
//         _onNewEmail(email);
//       } catch (e) {
//         debugPrint('❌ 메일 이벤트 파싱 오류: $e');
//       }
//     }
//   }

//   Future<void> _handleLogout() async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );

//     try {
//       await widget.authService.signOut();
//       await _secureStorage.delete(key: 'fcm_token');

//       if (!mounted) return;
//       Navigator.of(context, rootNavigator: true).pop();
//       Navigator.pushReplacementNamed(context, '/login');
//     } catch (e) {
//       if (!mounted) return;
//       Navigator.of(context, rootNavigator: true).pop();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content:
//                 Text(AppLocalizations.of(context)!.logoutFailed('$e'))),
//       );
//     }
//   }

//   // ✅ AppBar용 언어 드롭다운
//   Widget _buildLangMenu(BuildContext context) {
//     final t = AppLocalizations.of(context)!;
//     final code = Localizations.localeOf(context).languageCode;
//     String emoji;
//     switch (code) {
//       case 'ko':
//         emoji = '🇰🇷';
//         break;
//       case 'ja':
//         emoji = '🔴';
//         break;
//       default:
//         emoji = '🇺🇸';
//     }

//     return PopupMenuButton<Locale>(
//       tooltip: '',
//       onSelected: (locale) => widget.onChangeLocale?.call(locale),
//       itemBuilder: (ctx) => [
//         PopupMenuItem(
//             value: const Locale('ko'),
//             child: Row(children: [const Text('🇰🇷 '), Text(t.langKorean)])),
//         PopupMenuItem(
//             value: const Locale('en'),
//             child: Row(children: [
//               const Text('🇺🇸 '),
//               Text(t.langEnglish.toUpperCase())
//             ])),
//         PopupMenuItem(
//             value: const Locale('ja'),
//             child: Row(children: [const Text('🔴 '), Text(t.langJapanese)])),
//       ],
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 4.0),
//         child: Row(children: [Text(emoji), const Icon(Icons.arrow_drop_down)]),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final t = AppLocalizations.of(context)!;

//     return Scaffold(
//       // ✅ Drawer 유지
//       drawer: Drawer(
//         child: ListView(
//           padding: EdgeInsets.zero,
//           children: [
//             DrawerHeader(
//               decoration: BoxDecoration(
//                 color: Theme.of(context).colorScheme.primary,
//               ),
//               child: Align(
//                 alignment: Alignment.bottomLeft,
//                 child: Text(
//                   _userEmail ?? widget.authService.serviceName,
//                   style: Theme.of(context)
//                       .textTheme
//                       .titleLarge
//                       ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
//                 ),
//               ),
//             ),
//             ListTile(
//               leading: const Icon(Icons.rule),
//               title: Text(t.menuRulesLabel),
//               onTap: () {
//                 Navigator.pop(context);
//                 Navigator.of(context)
//                     .push(MaterialPageRoute(builder: (_) => const RuleListPage()));
//               },
//             ),
//             ListTile(
//               leading: const Icon(Icons.notifications_active),
//               title: Text(t.menuAlarmSettings),
//               onTap: () {
//                 Navigator.pop(context);
//                 _openAlarmDialog();
//               },
//             ),
//             const Divider(height: 8),
//             ListTile(
//               leading: const Icon(Icons.logout),
//               title: Text(t.menuLogout),
//               onTap: () async {
//                 Navigator.pop(context);
//                 await _handleLogout();
//               },
//             ),
//           ],
//         ),
//       ),

//       appBar: AppBar(
//         title: Text(_userEmail != null
//             ? t.userLabel(_userEmail!)
//             : widget.authService.serviceName),
//         actions: [
//           _buildLangMenu(context),
//           PopupMenuButton<String>(
//             icon: const Icon(Icons.more_vert),
//             onSelected: (value) async {
//               if (value == 'logout') {
//                 await _handleLogout();
//               } else if (value == 'rules') {
//                 Navigator.of(context)
//                     .push(MaterialPageRoute(builder: (_) => const RuleListPage()));
//               } else if (value == 'alarm_settings') {
//                 _openAlarmDialog();
//               }
//             },
//             itemBuilder: (_) => [
//               PopupMenuItem<String>(value: 'rules', child: Text(t.menuRulesLabel)),
//               PopupMenuItem<String>(
//                   value: 'alarm_settings', child: Text(t.menuAlarmSettings)),
//               PopupMenuItem<String>(value: 'logout', child: Text(t.menuLogout)),
//             ],
//           ),
//         ],
//       ),

//       // ✅ 카드형 레이아웃
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//           child: Column(
//             children: [
//               _AccountHeaderCard(
//                 title: _userEmail ?? widget.authService.serviceName,
//                 onSettings: _openAlarmDialog,
//               ),
//               const SizedBox(height: 12),
//               Expanded(
//                 child: _emails.isEmpty
//                     ? Center(child: Text(t.waitingNewEmails))
//                     : ListView.separated(
//                         itemCount: _emails.length,
//                         separatorBuilder: (_, __) => const SizedBox(height: 10),
//                         itemBuilder: (context, index) {
//                           final email = _emails[index];
//                           return _EmailCard(
//                             email: email,
//                             onTap: () {
//                               if (!email.read) {
//                                 setState(() {
//                                   _emails[index] = Email(
//                                     id: email.id,
//                                     emailAddress: email.emailAddress,
//                                     subject: email.subject,
//                                     sender: email.sender,
//                                     body: email.body,
//                                     receivedAt: email.receivedAt,
//                                     read: true,
//                                   );
//                                 });
//                               }
//                               Navigator.pushNamed(context, '/mail_detail',
//                                   arguments: email);
//                             },
//                           );
//                         },
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
