import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  // Offline mode: app works fully without any backend
  static const demoMode = false;

  static const _offlineToken = 'offline_token_smartedit';

  /// Register a new user. Returns {token, user} on success.
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // Offline-first: create user locally
    await ApiService.setToken(_offlineToken);
    final user = UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      avatarColor: '#6C63FF',
    );
    return {
      'token': _offlineToken,
      'user': user,
    };
  }

  /// Login with email/password. Returns {token, user} on success.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    // Offline-first: accept any credentials
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    await ApiService.setToken(_offlineToken);
    final user = UserModel(
      id: 'user_${email.hashCode.abs()}',
      name: email.split('@').first,
      email: email,
      avatarColor: '#6C63FF',
    );
    return {
      'token': _offlineToken,
      'user': user,
    };
  }

  /// Get current user from token.
  static Future<UserModel> getMe() async {
    final token = await ApiService.getToken();
    if (token != null && token.isNotEmpty) {
      return UserModel(
        id: 'user_001',
        name: 'SmartEdit User',
        email: 'user@smartedit.app',
        avatarColor: '#6C63FF',
      );
    }
    throw Exception('Not authenticated');
  }

  /// Clear the stored token.
  static Future<void> logout() async {
    await ApiService.removeToken();
  }

  /// Check if user has a stored token.
  static Future<bool> isLoggedIn() async {
    final token = await ApiService.getToken();
    return token != null && token.isNotEmpty;
  }
}
