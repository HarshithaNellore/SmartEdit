import 'package:flutter/foundation.dart';

/// Global debug logger for SmartCut.
/// Categorized logs with timestamps for API, collaboration, export, and AI.
class DebugLogger {
  /// Master switch — set to false to silence all debug logs.
  static bool enabled = kDebugMode;

  static const String _reset = '\x1B[0m';
  static const Map<String, String> _colors = {
    'API': '\x1B[36m',     // cyan
    'COLLAB': '\x1B[35m',  // magenta
    'EXPORT': '\x1B[33m',  // yellow
    'AI': '\x1B[32m',      // green
    'ERROR': '\x1B[31m',   // red
    'INFO': '\x1B[37m',    // white
  };

  /// Log a debug message with category and optional data.
  ///
  /// Example:
  /// ```dart
  /// DebugLogger.log('API', 'POST /api/projects/123/collaborators', data: {'email': 'a@b.com'});
  /// ```
  static void log(String category, String message, {Object? data}) {
    if (!enabled) return;
    final color = _colors[category.toUpperCase()] ?? _colors['INFO']!;
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final prefix = '$color[$timestamp] [$category]$_reset';
    debugPrint('$prefix $message');
    if (data != null) {
      debugPrint('$color  └─ $data$_reset');
    }
  }

  /// Log an error with stack trace.
  static void error(String category, String message, {Object? error, StackTrace? stack}) {
    if (!enabled) return;
    final color = _colors['ERROR']!;
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('$color[$timestamp] [${category}_ERROR] $message$_reset');
    if (error != null) {
      debugPrint('$color  └─ Error: $error$_reset');
    }
    if (stack != null) {
      debugPrint('$color  └─ Stack: ${stack.toString().split('\n').take(3).join('\n    ')}$_reset');
    }
  }

  /// Log an API request.
  static void apiRequest(String method, String url, {Object? body}) {
    log('API', '$method $url', data: body);
  }

  /// Log an API response.
  static void apiResponse(String url, int statusCode, {String? body}) {
    final status = statusCode >= 200 && statusCode < 300 ? '✅' : '❌';
    log('API', '$status Response $statusCode from $url',
        data: body != null && body.length > 200 ? '${body.substring(0, 200)}...' : body);
  }
}
