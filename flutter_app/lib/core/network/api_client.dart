import 'dart:convert';

import 'package:http/http.dart' as http;

import 'token_storage.dart';

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._storage);

  final TokenStorage _storage;
  final http.Client _client = http.Client();

  Future<dynamic> get(String url) async {
    final response = await _client.get(Uri.parse(url), headers: await _headers());
    return _process(response);
  }

  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? jsonBody,
    Map<String, String>? formBody,
  }) async {
    final headers = await _headers(
      contentType:
          formBody != null ? 'application/x-www-form-urlencoded' : 'application/json',
    );
    final body = formBody ?? (jsonBody == null ? null : jsonEncode(jsonBody));
    final response = await _client.post(Uri.parse(url), headers: headers, body: body);
    return _process(response);
  }

  Future<dynamic> patch(String url, {Map<String, dynamic>? jsonBody}) async {
    final headers = await _headers(contentType: 'application/json');
    final response = await _client.patch(
      Uri.parse(url),
      headers: headers,
      body: jsonBody == null ? null : jsonEncode(jsonBody),
    );
    return _process(response);
  }

  Future<Map<String, String>> _headers({String? contentType}) async {
    final token = _storage.read();
    return {
      'Accept': 'application/json',
      if (contentType != null) 'Content-Type': contentType,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _process(http.Response response) {
    final isOk = response.statusCode >= 200 && response.statusCode < 300;

    if (response.body.isEmpty) {
      if (isOk) return null;
      throw ApiException('Request failed (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map && decoded.containsKey('success')) {
      if (decoded['success'] == true) return decoded['data'];
      final message = (decoded['message'] ?? 'Request failed').toString();
      throw ApiException(message);
    }

    String message = 'Request failed (${response.statusCode})';
    if (decoded is Map && decoded['detail'] != null) {
      final detail = decoded['detail'];
      if (detail is List) {
        message = detail.map((e) => e['msg'] ?? e.toString()).join(', ');
      } else {
        message = detail.toString();
      }
    }
    if (!isOk) throw ApiException(message);
    return decoded;
  }
}
