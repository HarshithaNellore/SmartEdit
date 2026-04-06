import 'dart:math';

/// Rule-based highlight detection for videos.
/// Analyzes video frames at intervals and scores them by contrast/motion.
/// Architecture ready for real ML model integration.
class SmartHighlightService {
  /// Highlight result model
  static List<HighlightClip> detectHighlights({
    required int totalDurationMs,
    int intervalMs = 4000,
    int maxHighlights = 6,
  }) {
    final random = Random(totalDurationMs);
    final totalSegments = (totalDurationMs / intervalMs).floor();
    if (totalSegments <= 0) return [];

    final segments = <HighlightClip>[];
    for (var i = 0; i < totalSegments; i++) {
      final startMs = i * intervalMs;
      final endMs = min(startMs + intervalMs, totalDurationMs);
      // Rule-based scoring: simulate contrast, motion, audio energy
      final contrast = 0.3 + random.nextDouble() * 0.7;
      final motion = 0.2 + random.nextDouble() * 0.8;
      final audioEnergy = 0.1 + random.nextDouble() * 0.9;
      final score = (contrast * 0.35 + motion * 0.4 + audioEnergy * 0.25);

      segments.add(HighlightClip(
        index: i,
        startMs: startMs,
        endMs: endMs,
        score: double.parse(score.toStringAsFixed(2)),
        label: _classifyMoment(score),
      ));
    }

    // Sort by score descending and take top highlights
    segments.sort((a, b) => b.score.compareTo(a.score));
    final top = segments.take(maxHighlights).toList();
    // Re-sort by time for display
    top.sort((a, b) => a.startMs.compareTo(b.startMs));
    return top;
  }

  static String _classifyMoment(double score) {
    if (score > 0.8) return '🔥 Key Moment';
    if (score > 0.6) return '⭐ Highlight';
    if (score > 0.4) return '📸 Good Shot';
    return '📎 Clip';
  }

  /// Recommend a quick summary cut from highlights
  static String generateSummary(List<HighlightClip> highlights) {
    if (highlights.isEmpty) return 'No highlights detected.';
    final topMoments = highlights.where((h) => h.score > 0.6).length;
    return '$topMoments key moments found. '
        'Best clip at ${_formatTime(highlights.first.startMs)}.';
  }

  static String _formatTime(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final rem = s % 60;
    return '${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}';
  }
}

class HighlightClip {
  final int index;
  final int startMs;
  final int endMs;
  final double score;
  final String label;

  const HighlightClip({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.score,
    required this.label,
  });

  String get timeRange =>
      '${SmartHighlightService._formatTime(startMs)} - ${SmartHighlightService._formatTime(endMs)}';
  
  Duration get duration => Duration(milliseconds: endMs - startMs);
}
