import 'dart:io';

import 'package:supervisor_finder_backend/src/data/json_store.dart';
import 'package:supervisor_finder_backend/src/models/user.dart';
import 'package:supervisor_finder_backend/src/repositories/user_repository.dart';
import 'package:supervisor_finder_backend/src/services/app_exceptions.dart';
import 'package:supervisor_finder_backend/src/services/auth_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late AuthService authService;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('auth_service_test_');
    final store = JsonStore(File('${tempDir.path}/db.json'));
    await store.load();
    authService = AuthService(UserRepository(store));
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('registration', () {
    test('register creates a new account and returns a valid session',
        () async {
      final (user, token) = await authService.register(
        name: 'Jamie Student',
        email: 'jamie@uni.ac.uk',
        password: 'password123',
        role: UserRole.student,
      );

      expect(user.name, 'Jamie Student');
      expect(user.email, 'jamie@uni.ac.uk');
      expect(user.role, UserRole.student);

      final resolved = await authService.userForToken(token);
      expect(resolved?.id, user.id);
    });

    test('register rejects a duplicate email', () async {
      await authService.register(
        name: 'First Account',
        email: 'dupe@uni.ac.uk',
        password: 'password123',
        role: UserRole.student,
      );

      expect(
        () => authService.register(
          name: 'Second Account',
          email: 'dupe@uni.ac.uk',
          password: 'password123',
          role: UserRole.student,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('register rejects a password of 7 characters', () async {
      expect(
        () => authService.register(
          name: 'Short Password',
          email: 'short@uni.ac.uk',
          password: '1234567',
          role: UserRole.student,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('register accepts a password of 8 characters', () async {
      final (user, _) = await authService.register(
        name: 'Boundary Password',
        email: 'boundary@uni.ac.uk',
        password: '12345678',
        role: UserRole.student,
      );
      expect(user.email, 'boundary@uni.ac.uk');
    });

    test('register rejects a malformed email address', () async {
      expect(
        () => authService.register(
          name: 'Bad Email',
          email: 'not-an-email',
          password: 'password123',
          role: UserRole.student,
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('register rejects an empty name', () async {
      expect(
        () => authService.register(
          name: '   ',
          email: 'noname@uni.ac.uk',
          password: 'password123',
          role: UserRole.student,
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('login', () {
    test('login succeeds with the credentials just registered', () async {
      await authService.register(
        name: 'Login Test',
        email: 'login@uni.ac.uk',
        password: 'password123',
        role: UserRole.staff,
      );

      final (user, token) = await authService.login(
        'login@uni.ac.uk',
        'password123',
      );
      expect(user.email, 'login@uni.ac.uk');
      expect(await authService.userForToken(token), isNotNull);
    });

    test('login rejects an incorrect password', () async {
      await authService.register(
        name: 'Wrong Password Test',
        email: 'wrongpw@uni.ac.uk',
        password: 'password123',
        role: UserRole.student,
      );

      expect(
        () => authService.login('wrongpw@uni.ac.uk', 'not-the-password'),
        throwsA(isA<AuthException>()),
      );
    });

    test('login rejects an email with no matching account', () async {
      expect(
        () => authService.login('nobody@uni.ac.uk', 'password123'),
        throwsA(isA<AuthException>()),
      );
    });
  });
}
