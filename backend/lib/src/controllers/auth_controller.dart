import 'dart:io';

import '../models/user.dart';
import '../services/app_exceptions.dart';
import '../services/auth_service.dart';
import '../services/staff_service.dart';
import 'http_helpers.dart';

/// Handles POST /api/login, POST /api/logout, and POST /api/register.
///
/// Registration wasn't in the original design's use-case list (login/
/// register aren't modelled as use cases in their own right), but it is
/// real plumbing the app needs to create accounts, so it lives here
/// alongside login/logout.
class AuthController {
  final AuthService _authService;
  final StaffService _staffService;

  AuthController(this._authService, this._staffService);

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

  /// Body: `{name, email, password, role, office?}`. `office` is only
  /// used when `role` is `"staff"`, to create that staff member's
  /// canonical profile (FR4) alongside their account.
  Future<void> register(HttpRequest request) async {
    try {
      final body = await readJsonBody(request);
      final name = body['name'] as String?;
      final email = body['email'] as String?;
      final password = body['password'] as String?;
      final roleValue = body['role'] as String?;
      if (name == null || email == null || password == null || roleValue == null) {
        throw ValidationException('name, email, password and role are required');
      }
      final role = _parseRole(roleValue);

      final (user, token) = await _authService.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );

      if (role == UserRole.staff) {
        final office = (body['office'] as String?)?.trim() ?? '';
        await _staffService.createProfile(userId: user.id, office: office);
      }

      await writeJson(request, 201, {
        'token': token,
        'user': user.toPublicJson(),
      });
    } catch (e) {
      await writeError(request, e);
    }
  }

  UserRole _parseRole(String value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    throw ValidationException('Invalid role: $value');
  }
}
