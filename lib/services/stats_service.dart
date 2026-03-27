import 'package:shared_preferences/shared_preferences.dart';

/// Tracks app usage stats (export count, share count) using SharedPreferences.
class StatsService {
  static const _exportCountKey = 'export_count';
  static const _shareCountKey = 'share_count';

  static Future<int> getExportCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_exportCountKey) ?? 0;
  }

  static Future<void> incrementExportCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_exportCountKey) ?? 0;
    await prefs.setInt(_exportCountKey, current + 1);
  }

  static Future<int> getShareCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_shareCountKey) ?? 0;
  }

  static Future<void> incrementShareCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_shareCountKey) ?? 0;
    await prefs.setInt(_shareCountKey, current + 1);
  }
}
