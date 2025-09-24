// lib/api/api_client.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mail_push_app/models/email.dart';

class ApiClient {
  static final _baseUrl = dotenv.env['SERVER_BASE_URL']!;

  /// 디바이스/알람 설정 UPSERT
  /// - deviceId 필수
  /// - platform/fcmToken/emailAddress/flags 는 옵션 (null이면 서버에서 기존값 유지)
  /// - overwrite: 서버 라우트가 받지는 않지만, 상위 모듈 호환을 위해 시그니처만 유지
  Future<bool> upsertAlarmSetting({
    required String deviceId,
    String? platform, // 'ios' | 'android' | ''(미변경)
    String? fcmToken,
    String? emailAddress,
    bool? normalOn,
    bool? criticalOn,
    bool? criticalUntilStopped,
    bool overwrite = false, // ← 라우트에 전달하지 않음(호환성 유지용)
  }) async {
    try {
      final body = <String, dynamic>{
        'device_id': deviceId,
        if (platform != null) 'platform': platform,
        if (fcmToken != null) 'fcm_token': fcmToken,
        if (emailAddress != null) 'email_address': emailAddress,
        if (normalOn != null) 'normal_on': normalOn,
        if (criticalOn != null) 'critical_on': criticalOn,
        if (criticalUntilStopped != null) 'critical_until_stopped': criticalUntilStopped,
        // 'overwrite'는 서버가 받지 않으므로 전송하지 않습니다.
      };

      final resp = await http.post(
        Uri.parse('$_baseUrl/api/alarm_setting/upsert'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      debugPrint('🔔 upsertAlarmSetting resp: ${resp.statusCode} ${resp.body}');
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('❌ upsertAlarmSetting error: $e');
      return false;
    }
  }

  /// 디바이스/알람 설정 조회
  /// - 성공 시 서버의 JSON(Map)을 그대로 반환 (예: {found:true, normal_on:..., ...})
  /// - 레코드 없음/에러 시 null 반환
  Future<Map<String, dynamic>?> getAlarmSetting({
    required String deviceId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/alarm_setting')
          .replace(queryParameters: {'device_id': deviceId});

      final resp = await http.get(uri, headers: {'Accept': 'application/json'});
      debugPrint('🔔 getAlarmSetting resp: ${resp.statusCode} ${resp.body}');

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ getAlarmSetting error: $e');
      return null;
    }
  }

  // 토큰 검증 (서버에 /validate_token 이 있을 때만 유효)
  Future<bool> validateToken(String accessToken, String service) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/validate_token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'access_token': accessToken,
          'service': service, // 'gmail' | 'outlook' | 'icloud'
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valid'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('토큰 검증 오류: $e');
      return false;
    }
  }

  /// FCM/액세스토큰/리프레시토큰 등록 (서비스별 부가 필드 포함)
  Future<bool> registerTokens({
    required String fcmToken,
    required String accessToken,
    required String? refreshToken,
    required String service,
    String? emailAddress, // Gmail용 이메일 주소
  }) async {
    final storage = const FlutterSecureStorage();

    // Outlook용 clientState
    String? clientState;
    if (service == 'outlook') {
      clientState = await storage.read(key: 'outlook_client_state');
    }

    // Gmail 이메일 주소
    String? email;
    if (service == 'gmail') {
      email = emailAddress ?? await storage.read(key: 'gmail_user_email');
      if (email == null) {
        debugPrint('Gmail 이메일 주소 누락');
        return false;
      }
    }

    // iCloud용 sub (고유 식별)
    String? sub;
    if (service == 'icloud') {
      sub = await storage.read(key: 'icloud_sub');
      if (sub == null) {
        debugPrint('❌ iCloud sub 누락');
        return false;
      }
    }

    try {
      final body = {
        'fcm_token': fcmToken,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'service': service,
        if (service == 'gmail' && email != null) 'email_address': email,
        if (service == 'outlook' && clientState != null) 'client_state': clientState,
        if (service == 'icloud' && sub != null) 'sub': sub,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/update_tokens'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      debugPrint('토큰 등록 응답: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('토큰 등록 오류: $e');
      return false;
    }
  }

  /// 메일 목록 조회
  Future<List<Email>> fetchEmails(
    String service,
    String emailAddress, {
    String? since, // ISO8601 문자열. 이후 메일만 가져오기 위해 사용
    int? limit, // 최대 가져올 개수
  }) async {
    try {
      final queryParams = <String, String>{
        'service': service,
        'email_address': emailAddress,
        if (since != null) 'since': since,
        if (limit != null) 'limit': limit.toString(),
      };
      final uri =
          Uri.parse('$_baseUrl/api/emails').replace(queryParameters: queryParams);
      debugPrint('🔔 Requesting: $uri');

      final response = await http.get(uri);
      debugPrint('🔔 Email load 응답: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList
            .map((json) => Email.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Failed to load emails: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ fetchEmails 오류: $e');
      rethrow;
    }
  }
}
