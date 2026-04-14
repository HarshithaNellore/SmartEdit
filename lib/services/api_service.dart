import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Route connections directly to local backend to resolve timeout issues
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (Platform.isAndroid) return 'http://192.168.2.19:5000';
    return 'http://localhost:5000';
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

  // Longer timeout (300s) to account for Render free-tier cold starts
  static const _timeout = Duration(seconds: 300);

  static Future<http.Response> get(String path, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return http.get(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(_timeout);
  }

  static Future<http.Response> post(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
  }

  static Future<http.Response> put(String path,
      {Map<String, dynamic>? body, bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(_timeout);
  }

  static Future<http.Response> delete(String path, {bool auth = true}) async {
    final headers = await _headers(auth: auth);
    return http.delete(Uri.parse('$baseUrl$path'), headers: headers)
        .timeout(_timeout);
  }
}
