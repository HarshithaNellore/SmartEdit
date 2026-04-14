import 'dart:convert';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  // Enable demo mode for testing without backend
  // Set to true to use offline credentials
  static const demoMode = false; // 👈 CHANGE THIS TO false WHEN BACKEND IS READY
  
  // Demo credentials (valid only in demoMode)
  static const demoEmail = 'test@smartcut.app';
  static const demoPassword = 'password123';
  static const demoToken = 'demo_token_12345_offline_testing_mode';

  /// Demo user data for offline testing
  static UserModel _getDemoUser() {
    return UserModel(
      id: 'demo_user_001',
      name: 'Test User',
      email: demoEmail,
      avatarColor: '#6C63FF',
    );
  }

  /// Register a new user. Returns {token, user} on success.
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // Demo mode: Create user locally
    if (demoMode) {
      if (email == demoEmail) {
        throw Exception('Email already registered');
      }
      // Accept any other registration in demo mode
      await ApiService.setToken(demoToken);
      final user = UserModel(
        id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        avatarColor: '#6C63FF',
      );
      return {
        'token': demoToken,
        'user': user,
      };
    }

    // Normal mode: Call API
    final response = await ApiService.post(
      '/api/auth/register',
      body: {'name': name, 'email': email, 'password': password},
      auth: false,
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await ApiService.setToken(data['token']);
      return {
        'token': data['token'],
        'user': UserModel.fromJson(data['user']),
      };
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Registration failed');
    }
  }

  /// Login with email/password. Returns {token, user} on success.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    // Demo mode: Check hardcoded credentials
    if (demoMode) {
      if (email == demoEmail && password == demoPassword) {
        await ApiService.setToken(demoToken);
        return {
          'token': demoToken,
          'user': _getDemoUser(),
        };
      } else if (demoMode) {
        // In demo mode, reject with helpful message
        throw Exception('Demo login: Use $demoEmail / $demoPassword');
      }
    }

    // Normal mode: Call API
    final response = await ApiService.post(
      '/api/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await ApiService.setToken(data['token']);
      return {
        'token': data['token'],
        'user': UserModel.fromJson(data['user']),
      };
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? 'Login failed');
    }
  }

  /// Get current user from token.
  static Future<UserModel> getMe() async {
    // Demo mode: Return demo user
    if (demoMode) {
      final token = await ApiService.getToken();
      if (token == demoToken) {
        return _getDemoUser();
      }
      throw Exception('Not authenticated');
    }

    // Normal mode: Call API
    final response = await ApiService.get('/api/auth/me');
    if (response.statusCode == 200) {
      return UserModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Not authenticated');
    }
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
