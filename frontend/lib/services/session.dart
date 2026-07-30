import 'package:flutter/foundation.dart';

import '../models.dart';
import 'api_client.dart';

/// Holds the current authenticated user (if any) and coordinates login/
/// logout with the [ApiClient]. A [ChangeNotifier] so widgets can rebuild
/// when the session changes — e.g. switching between the login screen and
/// the role-appropriate home screen.
///
/// There is no local persistence of the session: it matches the backend's
/// in-memory session tokens, so restarting either the app or the server
/// simply requires logging in again.
class Session extends ChangeNotifier {
  final ApiClient apiClient;

  AppUser? _currentUser;
  String? _token;

  Session(this.apiClient);

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<void> login(String email, String password) async {
    final response = await apiClient.post(
      '/api/login',
      body: {'email': email, 'password': password},
    );
    _token = response['token'] as String;
    _currentUser = AppUser.fromJson(response['user'] as Map<String, dynamic>);
    apiClient.setToken(_token);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await apiClient.post('/api/logout');
    } finally {
      _token = null;
      _currentUser = null;
      apiClient.setToken(null);
      notifyListeners();
    }
  }
}
