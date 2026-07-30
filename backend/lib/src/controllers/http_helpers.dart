import 'dart:convert';
import 'dart:io';

import '../models/user.dart';
import '../services/app_exceptions.dart';
import '../services/auth_service.dart';

/// Shared plumbing for the Controller layer: reading/writing JSON over
/// dart:io's [HttpRequest]/[HttpResponse], extracting the bearer token,
/// and translating Service-layer [AppException]s into HTTP responses.
/// Every controller uses these instead of hand-rolling this logic.

/// Reads and JSON-decodes the request body. Returns an empty map for an
/// empty body (useful for endpoints with no required fields).
Future<Map<String, dynamic>> readJsonBody(HttpRequest request) async {
  final content = await utf8.decoder.bind(request).join();
  if (content.trim().isEmpty) return {};
  final decoded = jsonDecode(content);
  if (decoded is! Map<String, dynamic>) {
    throw ValidationException('Request body must be a JSON object');
  }
  return decoded;
}

/// Writes [body] as JSON with [statusCode] and closes the response.
/// Pass a null [body] for responses with no content (e.g. 204).
Future<void> writeJson(HttpRequest request, int statusCode, Object? body) async {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json;
  if (body != null) {
    request.response.write(jsonEncode(body));
  }
  await request.response.close();
}

/// Maps a caught error to an HTTP response: [AppException]s use their own
/// [AppException.statusCode]/message, anything else becomes a generic 500
/// so an unexpected bug never leaks internal detail to the client.
Future<void> writeError(HttpRequest request, Object error) async {
  if (error is AppException) {
    await writeJson(request, error.statusCode, {'error': error.message});
    return;
  }
  await writeJson(request, 500, {'error': 'Internal server error'});
}

/// Extracts the token from an `Authorization: Bearer <token>` header, or
/// null if absent/malformed.
String? bearerToken(HttpRequest request) {
  final header = request.headers.value(HttpHeaders.authorizationHeader);
  if (header == null || !header.startsWith('Bearer ')) return null;
  final token = header.substring('Bearer '.length).trim();
  return token.isEmpty ? null : token;
}

/// Resolves the request's bearer token to a [User] via [authService], or
/// throws [AuthException] (401) if there is no valid session. Every
/// controller endpoint that requires a logged-in caller starts with this.
Future<User> requireAuthenticatedUser(
  HttpRequest request,
  AuthService authService,
) async {
  final token = bearerToken(request);
  final user = await authService.userForToken(token);
  if (user == null) {
    throw AuthException('Authentication required');
  }
  return user;
}
