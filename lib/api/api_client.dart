import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiClient {
  static const String _baseUrl = 'https://mail-push.xtect.net';

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
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/update_tokens'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fcm_token': fcmToken,
          'accessToken': accessToken,
          'refreshToken': refreshToken,
          'service': service, // 'gmail' 또는 'outlook'
        }),
      );
      print('토큰 등록 응답: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        return true;
      } else {
        print('토큰 등록 실패: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('토큰 등록 오류: $e');
      return false;
    }
  }
}