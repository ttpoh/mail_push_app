// rules_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mail_push_app/models/rule_model.dart';

class RulesApi {
  final String baseUrl;
  final Map<String, String> defaultHeaders;

  RulesApi({
    String? baseUrlOverride,
    this.defaultHeaders = const {},
  }) : baseUrl = (baseUrlOverride ??
            "${dotenv.env['SERVER_BASE_URL']?.replaceAll(RegExp(r'/$'), '')}/api/rules")
          .replaceAll(RegExp(r'//$'), '/');

  Uri _buildUri(String pathSegment, [Map<String, String>? query]) {
    final cleanedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$cleanedBase$pathSegment').replace(queryParameters: query);
  }

  Future<List<MailRule>> fetchRules({String? fcmToken, String? authToken}) async {
    final uri = _buildUri('', { if (fcmToken != null) 'fcm_token': fcmToken });
    final headers = { 'Accept': 'application/json', ...defaultHeaders,
      if (authToken != null) 'Authorization': 'Bearer $authToken' };
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      final List<dynamic> arr = jsonDecode(resp.body);
      return arr.map((e) => MailRule.fromJson(e)).toList();
    } else {
      throw Exception('fetchRules failed ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<int> createRule(MailRule rule, {String? fcmToken, String? authToken}) async {
    final uri = _buildUri('');
    final headers = { 'Content-Type': 'application/json', ...defaultHeaders,
      if (authToken != null) 'Authorization': 'Bearer $authToken' };
    final body = {
      ...rule.toJson(),                // ✅ rule.sound 포함
      if (fcmToken != null) 'fcm_token': fcmToken,
    };
    final resp = await http.post(uri, headers: headers, body: jsonEncode(body));
    if (resp.statusCode == 201) {
      final Map<String, dynamic> parsed = jsonDecode(resp.body);
      return parsed['id'];
    } else {
      throw Exception('createRule failed ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<void> updateRule(MailRule rule, {String? fcmToken, String? authToken}) async {
    if (rule.id == null) throw ArgumentError('rule.id is required for update');
    final uri = _buildUri('/${rule.id}');
    final headers = { 'Content-Type': 'application/json', ...defaultHeaders,
      if (authToken != null) 'Authorization': 'Bearer $authToken' };
    final body = {
      ...rule.toJson(),                // ✅ rule.sound 포함
      if (fcmToken != null) 'fcm_token': fcmToken,
    };
    final resp = await http.put(uri, headers: headers, body: jsonEncode(body));
    if (resp.statusCode != 200) {
      throw Exception('updateRule failed ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<void> deleteRule(int id, {String? fcmToken, String? authToken}) async {
    final uri = _buildUri('/$id', { if (fcmToken != null) 'fcm_token': fcmToken });
    final headers = { ...defaultHeaders, if (authToken != null) 'Authorization': 'Bearer $authToken' };
    final resp = await http.delete(uri, headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('deleteRule failed ${resp.statusCode}: ${resp.body}');
    }
  }
}
