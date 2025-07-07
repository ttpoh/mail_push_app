import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mail_push_app/models/email.dart';

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
    String? emailAddress, // Gmail용 이메일 주소 추가
  }) async {
    // Outlook용 clientState를 가져옵니다
    String? clientState;
    if (service == 'outlook') {
      clientState = await FlutterSecureStorage().read(key: 'outlook_client_state');
    }

    // Gmail일 경우 저장된 이메일 주소를 가져오거나 파라미터 사용
    String? email;
    if (service == 'gmail') {
      email = emailAddress ?? await FlutterSecureStorage().read(key: 'gmail_user_email');
      if (email == null) {
        print('Gmail 이메일 주소 누락');
        return false;
      }
    }

    try {
      final body = {
        'fcm_token': fcmToken,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'service': service,
        'email_address': email,
        // Gmail일 경우 email_address 추가
        if (service == 'gmail' && email != null) 'email_address': email,
        // Outlook일 경우 client_state 추가
        if (service == 'outlook' && clientState != null) 'client_state': clientState,
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


  Future<List<Email>> fetchEmails(String service, String emailAddress) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/emails?service=$service&email_address=${Uri.encodeComponent(emailAddress)}');
      print('🔔 Requesting: $uri');
      final response = await http.get(uri);
      print('🔔 Email load 응답: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((json) => Email.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Failed to load emails: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ fetchEmails 오류: $e');
      rethrow;
    }
  }
}