/// The role a [User] holds, used to gate what a session may do.
enum UserRole {
  student,
  staff,
  coordinator;

  static UserRole fromJson(String value) =>
      UserRole.values.firstWhere((r) => r.name == value);

  String toJson() => name;
}

/// A registered account. Staff additionally have a [StaffProfile]
/// (see staff_profile.dart) keyed by [id].
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;

  /// Random per-user salt, stored alongside the hash it was used to produce.
  final String salt;

  /// Salted SHA-256 hex digest of the user's password. Never the plaintext.
  final String passwordHash;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.salt,
    required this.passwordHash,
  });

  User copyWith({
    String? name,
    String? email,
    UserRole? role,
    String? salt,
    String? passwordHash,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      salt: salt ?? this.salt,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromJson(json['role'] as String),
      salt: json['salt'] as String,
      passwordHash: json['passwordHash'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.toJson(),
      'salt': salt,
      'passwordHash': passwordHash,
    };
  }

  /// Representation safe to send to clients: never includes [salt] or
  /// [passwordHash].
  Map<String, dynamic> toPublicJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.toJson(),
    };
  }
}
