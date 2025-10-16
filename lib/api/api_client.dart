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
  Future<bool> upsertAlarmSetting({
    required String deviceId,
    String? platform,
    String? fcmToken,
    String? emailAddress,
    bool? normalOn,
    bool? criticalOn,
    bool? criticalUntilStopped,
    bool overwrite = false, // 서버에 보내지 않음(호환용)
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

  // 토큰 검증
  Future<bool> validateToken(String accessToken, String service) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/validate_token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'access_token': accessToken,
          'service': service,
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

  /// FCM/액세스토큰/리프레시토큰 등록
  Future<bool> registerTokens({
    required String fcmToken,
    required String accessToken,
    required String? refreshToken,
    required String service,
    String? emailAddress, // Gmail용
  }) async {
    final storage = const FlutterSecureStorage();

    String? clientState;
    if (service == 'outlook') {
      clientState = await storage.read(key: 'outlook_client_state');
    }

    String? email;
    if (service == 'gmail') {
      email = emailAddress ?? await storage.read(key: 'gmail_user_email');
      if (email == null) {
        debugPrint('Gmail 이메일 주소 누락');
        return false;
      }
    }

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
  /// - 서버가 alarm, message_id를 반환하면 Email 모델에 매핑되도록 전처리
  Future<List<Email>> fetchEmails(
    String service,
    String emailAddress, {
    String? since,
    int? limit,
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
        return jsonList.map((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          // 서버가 message_id를 내려주면 → Email.fromJson에서 기대하는 키로 맞춤
          m['messageId'] = m['messageId'] ?? m['message_id'] ?? m['id']?.toString();
          // 서버가 alarm을 내려주면 → ruleAlarm으로 맞춤
          if (m['alarm'] != null && (m['ruleAlarm'] == null)) {
            m['ruleAlarm'] = m['alarm'];
          }
          // received_at 문자열 보정(있으면 그대로)
          return Email.fromJson(m);
        }).toList();
      } else {
        throw Exception(
            'Failed to load emails: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ fetchEmails 오류: $e');
      rethrow;
    }
  }

  /// 메일 읽음 표시
  /// - 서버의 /api/emails/mark-read 사용
  Future<bool> markEmailRead({
    required String service,
    required String emailAddress,
    required String messageId, // ✅ 항상 원본 messageId 사용
    required bool read,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/emails/mark-read');
      final body = json.encode({
        'service': service,
        'email_address': emailAddress,
        'message_id': messageId, // ✅ 표준화
        'read': read,
      });
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      debugPrint('📮 markEmailRead resp: ${resp.statusCode} ${resp.body}');
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('❌ markEmailRead error: $e');
      return false;
    }
  }
}
