import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mail_push_app/api/api_client.dart';
import 'auth_service.dart';

class ICloudAuthService extends AuthService {
  @override
  String get serviceName => 'icloud';

  String? _email;
  String? _identityToken;
  final _storage = const FlutterSecureStorage();
  final _apiClient = ApiClient();

  @override
  Future<Map<String, String?>> signIn({String? fcmToken}) async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      _email = appleCredential.email;
      _identityToken = appleCredential.identityToken;
      final sub = appleCredential.userIdentifier;

      if (_identityToken == null || sub == null) {
        throw Exception('Apple 로그인 실패: identityToken 또는 userIdentifier가 없습니다.');
      }

      // SecureStorage에 저장
      await _storage.write(key: 'icloud_sub', value: sub);
      if (_email != null) {
        await _storage.write(key: 'icloud_user_email', value: _email);
      }

      // FCM 토큰 가져오기
      final realFcmToken = fcmToken ?? await FirebaseMessaging.instance.getToken();
      if (realFcmToken == null) {
        debugPrint('⚠️ FCM 토큰이 없어 토큰 등록 생략');
      } else {
        final success = await _apiClient.registerTokens(
          fcmToken: realFcmToken,
          accessToken: _identityToken!,
          refreshToken: null,
          service: serviceName,
          emailAddress: _email, // 없어도 서버에서 sub 기반으로 fallback
        );

        if (success) {
          debugPrint('✅ apple 토큰 등록 성공');
        } else {
          debugPrint('❌ apple 토큰 등록 실패');
        }
      }

      return {
        'accessToken': _identityToken,
        'refreshToken': null,
        'sub': sub,
        'email': _email,
      };
    } catch (e) {
      debugPrint('❌ Apple 로그인 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    _email = null;
    _identityToken = null;
    await _storage.delete(key: 'icloud_sub');
    await _storage.delete(key: 'icloud_user_email');
    // 서버 로그아웃은 별도 모듈에서 처리
  }

  @override
  Future<String?> getCurrentUserEmail() async {
    return _storage.read(key: 'icloud_user_email');
  }

  @override
  Future<Map<String, String?>> refreshTokens() async {
    if (_identityToken == null) {
      throw Exception('identityToken이 없어 토큰 갱신이 불가능합니다.');
    }
    return {
      'accessToken': _identityToken,
      'refreshToken': null,
    };
  }

  // Apple 로그인용 nonce 생성기
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
