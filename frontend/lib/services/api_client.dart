import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Thrown when the backend returns a non-2xx response. Carries the
/// server's own error message (if any) and status code, so the UI can
/// show something meaningful instead of a generic failure.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => message;
}

/// Thin HTTP client wrapping the backend's JSON API over dart:io's
/// [http.Client]. Holds the current bearer token (set after login) and
/// centralizes request/response handling so screens never touch
/// `package:http` directly.
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  String? _token;

  ApiClient({required this.baseUrl, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// The Android emulator can't reach the host machine via `localhost` —
  /// it needs the special alias `10.0.2.2`. iOS simulators and desktop
  /// builds can use `localhost` directly.
  static String defaultBaseUrl({int port = 8080}) {
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:$port';
    }
    return 'http://localhost:$port';
  }

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = _buildUri(path, query);
    final response = await _httpClient.get(uri, headers: _headers);
    return _decode(response);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final uri = _buildUri(path, null);
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final uri = _buildUri(path, null);
    final response = await _httpClient.patch(
      uri,
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> delete(String path, {Map<String, String>? query}) async {
    final uri = _buildUri(path, query);
    final response = await _httpClient.delete(uri, headers: _headers);
    return _decode(response);
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  dynamic _decode(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    final hasBody = response.body.isNotEmpty;
    final decoded = hasBody ? jsonDecode(response.body) : null;

    if (!isSuccess) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Request failed with status ${response.statusCode}';
      throw ApiException(response.statusCode, message);
    }
    return decoded;
  }

  void close() => _httpClient.close();
}
