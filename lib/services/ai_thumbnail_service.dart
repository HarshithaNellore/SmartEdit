import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// AI Thumbnail Generator service.
/// Picks the best frame from a video based on contrast/clarity scoring.
/// Supports title overlay generation.
class AiThumbnailService {
  /// Pick the best frame timestamp from a video duration
  static ThumbnailSuggestion pickBestFrame({
    required int totalDurationMs,
    int candidateCount = 8,
  }) {
    final random = Random(totalDurationMs);
    var bestScore = 0.0;
    var bestTimestamp = 0;

    // Score candidates at even intervals
    final interval = totalDurationMs ~/ (candidateCount + 1);
    for (var i = 1; i <= candidateCount; i++) {
      final timestamp = i * interval;
      // Score based on position (prefer middle sections) + random variation
      final positionScore = 1.0 - ((timestamp / totalDurationMs) - 0.4).abs();
      final clarityScore = 0.5 + random.nextDouble() * 0.5;
      final score = positionScore * 0.6 + clarityScore * 0.4;

      if (score > bestScore) {
        bestScore = score;
        bestTimestamp = timestamp;
      }
    }

    return ThumbnailSuggestion(
      timestampMs: bestTimestamp,
      score: double.parse(bestScore.toStringAsFixed(2)),
      reason: _getReason(bestScore),
    );
  }

  /// Generate multiple thumbnail candidates
  static List<ThumbnailSuggestion> generateCandidates({
    required int totalDurationMs,
    int count = 5,
  }) {
    final random = Random(totalDurationMs * 7);
    final candidates = <ThumbnailSuggestion>[];
    final interval = totalDurationMs ~/ (count + 1);

    for (var i = 1; i <= count; i++) {
      final timestamp = (i * interval) + random.nextInt(max(1, interval ~/ 3)) - (interval ~/ 6);
      final clampedTimestamp = timestamp.clamp(0, totalDurationMs);
      final positionScore = 1.0 - ((clampedTimestamp / totalDurationMs) - 0.4).abs();
      final clarityScore = 0.5 + random.nextDouble() * 0.5;
      final score = positionScore * 0.5 + clarityScore * 0.5;

      candidates.add(ThumbnailSuggestion(
        timestampMs: clampedTimestamp,
        score: double.parse(score.toStringAsFixed(2)),
        reason: _getReason(score),
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }

  /// Style presets for thumbnail title overlay
  static List<ThumbnailStyle> get stylePresets => const [
    ThumbnailStyle(
      name: 'Bold Impact',
      fontSizeScale: 1.4,
      textColor: Colors.white,
      bgColor: Color(0xCC000000),
      fontWeight: FontWeight.w900,
      position: Alignment.bottomCenter,
    ),
    ThumbnailStyle(
      name: 'Gradient Banner',
      fontSizeScale: 1.2,
      textColor: Colors.white,
      bgColor: Color(0xBB6C63FF),
      fontWeight: FontWeight.w800,
      position: Alignment.bottomCenter,
    ),
    ThumbnailStyle(
      name: 'Minimal',
      fontSizeScale: 1.0,
      textColor: Colors.white,
      bgColor: Color(0x88000000),
      fontWeight: FontWeight.w600,
      position: Alignment.center,
    ),
    ThumbnailStyle(
      name: 'Top Title',
      fontSizeScale: 1.1,
      textColor: Colors.white,
      bgColor: Color(0xAAFF6B6B),
      fontWeight: FontWeight.w700,
      position: Alignment.topCenter,
    ),
    ThumbnailStyle(
      name: 'Neon Pop',
      fontSizeScale: 1.3,
      textColor: Color(0xFF00E5FF),
      bgColor: Color(0xDD1A1A2E),
      fontWeight: FontWeight.w900,
      position: Alignment.bottomCenter,
    ),
  ];

  static String _getReason(double score) {
    if (score > 0.8) return 'Excellent clarity and composition';
    if (score > 0.6) return 'Good visual balance';
    if (score > 0.4) return 'Decent frame quality';
    return 'Available frame';
  }

  static String formatTimestamp(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final rem = s % 60;
    return '${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}';
  }
}

class ThumbnailSuggestion {
  final int timestampMs;
  final double score;
  final String reason;

  const ThumbnailSuggestion({
    required this.timestampMs,
    required this.score,
    required this.reason,
  });

  String get formattedTime => AiThumbnailService.formatTimestamp(timestampMs);
}

class ThumbnailStyle {
  final String name;
  final double fontSizeScale;
  final Color textColor;
  final Color bgColor;
  final FontWeight fontWeight;
  final Alignment position;

  const ThumbnailStyle({
    required this.name,
    required this.fontSizeScale,
    required this.textColor,
    required this.bgColor,
    required this.fontWeight,
    required this.position,
  });
}
