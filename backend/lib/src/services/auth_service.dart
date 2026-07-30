import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/user.dart';
import '../repositories/user_repository.dart';
import 'app_exceptions.dart';

/// Thrown for authentication failures specifically (bad credentials, or no
/// session for an endpoint that requires one). Maps to HTTP 401. See
/// [ForbiddenException] in app_exceptions.dart for "authenticated but not
/// permitted".
class AuthException extends AppException {
  AuthException(String message) : super(message, 401);
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
  static const minPasswordLength = 8;
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final UserRepository _userRepository;
  final Map<String, Session> _sessionsByToken = {};
  final Random _random = Random.secure();

  AuthService(this._userRepository);

  /// Generates a fresh random salt, encoded as URL-safe base64. Used when
  /// creating a user.
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
    return (user, _createSession(user));
  }

  /// Creates a new account and, on success, logs it straight in (mirrors
  /// [login]'s return shape so the controller/UI treats them the same
  /// way). Validates the fields that matter for a working account —
  /// there's no separate "register" use case per the spec, so this is
  /// plumbing, not a place for elaborate business rules.
  Future<(User, String)> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ValidationException('Name is required');
    }
    final normalizedEmail = email.trim();
    if (!_emailPattern.hasMatch(normalizedEmail)) {
      throw ValidationException('Enter a valid email address');
    }
    if (password.length < minPasswordLength) {
      throw ValidationException(
        'Password must be at least $minPasswordLength characters',
      );
    }
    final existing = await _userRepository.findByEmail(normalizedEmail);
    if (existing != null) {
      throw ValidationException('An account with that email already exists');
    }

    final salt = generateSalt();
    final user = User(
      id: _generateUserId(),
      name: trimmedName,
      email: normalizedEmail,
      role: role,
      salt: salt,
      passwordHash: hashPassword(password, salt),
    );
    await _userRepository.insert(user);
    return (user, _createSession(user));
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

  String _createSession(User user) {
    final token = _generateToken();
    _sessionsByToken[token] = Session(
      token: token,
      userId: user.id,
      createdAt: DateTime.now(),
    );
    return token;
  }

  String _generateToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _generateUserId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final suffix = _random.nextInt(1 << 32);
    return 'user_${timestamp}_$suffix';
  }
}
