import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  /// Sanitize error messages so raw PlatformExceptions aren't shown to users.
  static String _friendlyError(dynamic e) {
    final raw = e.toString();
    if (raw.contains('PlatformException') || raw.contains('channel-error')) {
      return 'Unable to connect. Please restart the app and try again.';
    }
    if (raw.contains('TimeoutException') || raw.contains('timed out')) {
      return 'Server is starting up, please wait a moment and try again.';
    }
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      return 'No internet connection. Please check your network.';
    }
    return raw.replaceAll('Exception: ', '');
  }

  /// Try to restore session from stored token.
  Future<bool> tryAutoLogin() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!loggedIn) return false;

      _user = await AuthService.getMe();
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (_) {
      try {
        await AuthService.logout();
      } catch (_) {
        // SharedPreferences may be unavailable; ignore cleanup errors
      }
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await AuthService.register(
        name: name,
        email: email,
        password: password,
      );
      _user = result['user'] as UserModel;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await AuthService.login(
        email: email,
        password: password,
      );
      _user = result['user'] as UserModel;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendlyError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await AuthService.logout();
    } catch (_) {
      // Ignore errors during logout cleanup
    }
    _user = null;
    _isAuthenticated = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
