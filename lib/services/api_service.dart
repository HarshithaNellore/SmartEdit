import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ─── Backend URL Configuration ────────────────────────────────────────
  // For APK installs, the app needs to reach a real backend server.
  // Options:
  //   1. Local development: Use your PC's local-network IP (both devices on same WiFi)
  //   2. Deployed backend: Use a public URL (e.g., Render, Railway, etc.)
  //
  // ⚠️ IMPORTANT: If you're building an APK for distribution or demo,
  //    set _deployedUrl to your live backend URL, or leave it null to use local.
  //    Example: static const String? _deployedUrl = 'https://smartcut-api.onrender.com';

  // Set this to your deployed backend URL (null = use local network)
  static const String? _deployedUrl = 'https://smartedit.onrender.com';

  // Local development IPs
  static const String _localWebUrl = 'http://localhost:5000';
  static const String _localAndroidEmulatorUrl = 'http://10.0.2.2:5000';
  // ↓ Change this to your computer's IP on your WiFi network
  static const String _localAndroidDeviceUrl = 'http://192.168.2.19:5000';

  static String get baseUrl {
    // If a deployed URL is set, always use it
    if (_deployedUrl != null && _deployedUrl!.isNotEmpty) {
      return _deployedUrl!;
    }

    // Otherwise fall back to local network
    if (kIsWeb) return _localWebUrl;
    if (Platform.isAndroid) return _localAndroidDeviceUrl;
    return _localWebUrl;
  }

  // In-memory fallback when SharedPreferences is unavailable
  static String? _inMemoryToken;
  static bool _sharedPrefsAvailable = true;

  /// Get a SharedPreferences instance, or null if unavailable.
  static Future<SharedPreferences?> _getSafePrefs() async {
    if (!_sharedPrefsAvailable) return null;
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SharedPreferences unavailable, using in-memory fallback: $e');
      _sharedPrefsAvailable = false;
      return null;
    }
  }

  static Future<String?> getToken() async {
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      try {
        return prefs.getString('auth_token');
      } catch (e) {
        debugPrint('SharedPreferences getToken error: $e');
      }
    }
    return _inMemoryToken;
  }

  static Future<void> setToken(String token) async {
    _inMemoryToken = token;
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      try {
        await prefs.setString('auth_token', token);
      } catch (e) {
        debugPrint('SharedPreferences setToken error: $e');
      }
    }
  }

  static Future<void> removeToken() async {
    _inMemoryToken = null;
    final prefs = await _getSafePrefs();
    if (prefs != null) {
      try {
        await prefs.remove('auth_token');
      } catch (e) {
        debugPrint('SharedPreferences removeToken error: $e');
      }
    }
  }

  static Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ─── Timeouts & Retry Configuration ───────────────────────────────────
  // Initial request timeout: 30 seconds (reasonable for a responsive server)
  static const _initialTimeout = Duration(seconds: 30);
  // Max retries for connection failures
  static const int _maxRetries = 3;
  // Delay between retries (increases with each attempt)
  static const _retryBaseDelay = Duration(seconds: 2);

  /// Core request method with automatic retry on connection failures.
  /// Retries on SocketException / TimeoutException to handle:
  ///   - Server cold starts (Render free tier)
  ///   - Transient network issues
  ///   - Server not yet ready
  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function(Duration timeout) makeRequest,
  ) async {
    Exception? lastError;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        // On retries, give the server more time (escalating timeout)
        final timeout = Duration(
          seconds: _initialTimeout.inSeconds * (attempt + 1),
        );
        debugPrint(
          '[ApiService] Attempt ${attempt + 1}/$_maxRetries '
          '(timeout: ${timeout.inSeconds}s) → $baseUrl',
        );
        final response = await makeRequest(timeout);
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        debugPrint('[ApiService] Timeout on attempt ${attempt + 1}: $e');
      } on SocketException catch (e) {
        lastError = e;
        debugPrint('[ApiService] SocketException on attempt ${attempt + 1}: $e');
      } on HttpException catch (e) {
        lastError = e;
        debugPrint('[ApiService] HttpException on attempt ${attempt + 1}: $e');
      } catch (e) {
        // For non-network errors, don't retry — rethrow immediately
        rethrow;
      }

      // Wait before retrying (increasing delay: 2s, 4s, 6s, ...)
      if (attempt < _maxRetries - 1) {
        final delay = Duration(
          seconds: _retryBaseDelay.inSeconds * (attempt + 1),
        );
        debugPrint('[ApiService] Retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);

        // Try to wake up the server by hitting health endpoint
        try {
          debugPrint('[ApiService] Pinging health endpoint...');
          await http
              .get(Uri.parse('$baseUrl/health'))
              .timeout(const Duration(seconds: 10));
          debugPrint('[ApiService] Server is now reachable!');
        } catch (_) {
          debugPrint('[ApiService] Health check failed, will retry anyway...');
        }
      }
    }

    // All retries exhausted
    if (lastError is SocketException) {
      throw Exception(
        'Cannot connect to the server at $baseUrl. '
        'Please make sure the backend server is running and your device '
        'is on the same network.',
      );
    }
    throw Exception(
      'Server is not responding after $_maxRetries attempts. '
      'Please check your connection and try again.',
    );
  }

  static Future<http.Response> get(String path, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return _requestWithRetry((timeout) {
      return http
          .get(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(timeout);
    });
  }

  static Future<http.Response> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return _requestWithRetry((timeout) {
      return http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
    });
  }

  static Future<http.Response> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return _requestWithRetry((timeout) {
      return http
          .put(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
    });
  }

  static Future<http.Response> delete(String path, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return _requestWithRetry((timeout) {
      return http
          .delete(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(timeout);
    });
  }

  /// Quick connectivity check — returns true if the backend is reachable.
  static Future<bool> isServerReachable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
