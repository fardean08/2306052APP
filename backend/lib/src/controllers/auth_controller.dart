import 'dart:io';

import '../services/app_exceptions.dart';
import '../services/auth_service.dart';
import 'http_helpers.dart';

/// Handles POST /api/login and POST /api/logout.
///
/// Per the spec, login/logout are plumbing for authentication, not
/// design-level use cases — so this is a thin controller with no
/// corresponding "register" endpoint; accounts only come from seed data.
class AuthController {
  final AuthService _authService;

  AuthController(this._authService);

  Future<void> login(HttpRequest request) async {
    try {
      final body = await readJsonBody(request);
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      if (email == null || password == null) {
        throw ValidationException('email and password are required');
      }
      final (user, token) = await _authService.login(email, password);
      await writeJson(request, 200, {
        'token': token,
        'user': user.toPublicJson(),
      });
    } catch (e) {
      await writeError(request, e);
    }
  }

  Future<void> logout(HttpRequest request) async {
    try {
      final token = bearerToken(request);
      if (token != null) {
        _authService.logout(token);
      }
      await writeJson(request, 204, null);
    } catch (e) {
      await writeError(request, e);
    }
  }
}
