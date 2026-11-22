import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zing/config/env.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => 'ApiException($status): $message';
}

/// Thin client for the Node API (Railway). Sends the Supabase access token.
class ApiClient {
  ApiClient._();

  static Map<String, String> get _headers {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Uri _uri(String path, [Map<String, String>? query]) {
    if (Env.apiBaseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not set. Run with --dart-define-from-file=.env');
    }
    return Uri.parse('${Env.apiBaseUrl}$path').replace(queryParameters: query);
  }

  static dynamic _decode(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      throw ApiException(
          r.statusCode, body is Map ? '${body['error'] ?? r.body}' : r.body);
    }
    return body;
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) async =>
      _decode(await http.get(_uri(path, query), headers: _headers));

  static Future<dynamic> post(String path, Map<String, dynamic> body) async =>
      _decode(await http.post(_uri(path), headers: _headers, body: jsonEncode(body)));

  static Future<dynamic> delete(String path) async =>
      _decode(await http.delete(_uri(path), headers: _headers));
}
