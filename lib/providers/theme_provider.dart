import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  String _themeName = 'Dark';
  
  String get themeName => _themeName;
  
  ThemeData get themeData {
    if (_themeName == 'Light') return AppTheme.lightTheme;
    if (_themeName == 'AMOLED') return AppTheme.amoledTheme;
    if (_themeName == 'Midnight') return AppTheme.midnightTheme;
    return AppTheme.darkTheme;
  }

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _themeName = prefs.getString('theme') ?? 'Dark';
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setTheme(String theme) async {
    _themeName = theme;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme', theme);
    } catch (_) {}
  }
}
