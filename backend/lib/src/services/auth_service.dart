import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/user.dart';
import '../repositories/user_repository.dart';

/// Thrown for any authentication/authorization failure. Controllers map
/// this to an HTTP 401 (bad credentials / no session) or 403 (session ok,
/// but not permitted) response.
class AuthException implements Exception {
  final String message;
  final int statusCode;
  AuthException(this.message, {this.statusCode = 401});
  @override
  String toString() => message;
}

/// A live in-memory session, created on login and looked up on every
/// authenticated request. Sessions are not persisted — restarting the
/// server logs everyone out, which is acceptable for this prototype
/// (NFR6 only requires no *scheduled* downtime).
class Session {
  final String token;
  final String userId;
  final DateTime createdAt;

  Session({required this.token, required this.userId, required this.createdAt});
}

/// Salted SHA-256 password hashing plus a simple in-memory session-token
/// store. This is the only place in the app that deals with credentials.
class AuthService {
  final UserRepository _userRepository;
  final Map<String, Session> _sessionsByToken = {};
  final Random _random = Random.secure();

  AuthService(this._userRepository);

  /// Generates a fresh random salt, encoded as URL-safe base64. Used when
  /// creating a user (including seed data).
  static String generateSalt([int byteLength = 16]) {
    final bytes = List<int>.generate(byteLength, (_) => Random.secure().nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Combines [password] with [salt] and returns the SHA-256 hex digest.
  static String hashPassword(String password, String salt) {
    final digest = sha256.convert(utf8.encode('$salt:$password'));
    return digest.toString();
  }

  /// Verifies [email]/[password] against the stored user record and, on
  /// success, creates a new session. Throws [AuthException] on any
  /// mismatch — deliberately the same message for "no such user" and
  /// "wrong password" so login doesn't leak which emails are registered.
  Future<(User, String)> login(String email, String password) async {
    final user = await _userRepository.findByEmail(email);
    if (user == null) {
      throw AuthException('Invalid email or password');
    }
    final candidateHash = hashPassword(password, user.salt);
    if (candidateHash != user.passwordHash) {
      throw AuthException('Invalid email or password');
    }
    final token = _generateToken();
    _sessionsByToken[token] = Session(
      token: token,
      userId: user.id,
      createdAt: DateTime.now(),
    );
    return (user, token);
  }

  /// Invalidates [token], if it exists. Idempotent.
  void logout(String token) {
    _sessionsByToken.remove(token);
  }

  /// Resolves a bearer [token] to the [User] who owns the session, or
  /// null if the token is missing/unknown. Controllers use this to
  /// authenticate a request before handing off to a Service method.
  Future<User?> userForToken(String? token) async {
    if (token == null) return null;
    final session = _sessionsByToken[token];
    if (session == null) return null;
    return _userRepository.findById(session.userId);
  }

  String _generateToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
