import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiClient {
  static final _baseUrl = dotenv.env['SERVER_BASE_URL']!;

  // 토큰 검증 기능은 서버에 /validate_token 엔드포인트가 없으므로 주석 처리
  Future<bool> validateToken(String accessToken, String service) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/validate_token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'access_token': accessToken,
          'service': service, // 'gmail' 또는 'outlook'
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['valid'] == true;
      }
      return false;
    } catch (e) {
      print('토큰 검증 오류: $e');
      return false;
    }
  }

  Future<bool> registerTokens({
    required String fcmToken,
    required String accessToken,
    required String? refreshToken,
    required String service,
  }) async {
    // ↓ Outlook용 clientState를 가져옵니다 (예: secure storage 에 저장해둔 키)
    String? clientState;
    if (service == 'outlook') {
      clientState = await FlutterSecureStorage().read(key: 'outlook_client_state');
    }

    try {
      final body = {
        'fcm_token':    fcmToken,
        'accessToken':  accessToken,
        'refreshToken': refreshToken,
        'service':      service,
        // Outlook일 때만 client_state 필드 추가
        if (service == 'outlook' && clientState != null)
          'client_state': clientState,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/api/update_tokens'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      print('토큰 등록 응답: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('토큰 등록 오류: $e');
      return false;
    }
  }
}