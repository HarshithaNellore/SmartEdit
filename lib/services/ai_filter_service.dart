import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';

/// AI Filter Recommendation service.
/// Analyzes image brightness and color tone to recommend filter presets.
/// All processing is local — no API needed.
class AiFilterService {
  /// Analyze image bytes and recommend filters
  static List<FilterRecommendation> recommendFilters(Uint8List imageBytes) {
    // Analyze basic brightness from raw bytes (simplified)
    final brightness = _estimateBrightness(imageBytes);
    final warmth = _estimateWarmth(imageBytes);

    final recommendations = <FilterRecommendation>[];

    // Always recommend based on analysis
    if (brightness < 0.35) {
      recommendations.add(FilterRecommendation(
        name: 'Brighten',
        description: 'Your image is dark — brighten it for clarity',
        icon: Icons.wb_sunny_rounded,
        color: const Color(0xFFFFD700),
        matrix: _brightenMatrix,
        confidence: 0.9,
      ));
    }

    if (brightness > 0.7) {
      recommendations.add(FilterRecommendation(
        name: 'Moody',
        description: 'High brightness detected — try a moody look',
        icon: Icons.nights_stay_rounded,
        color: const Color(0xFF5C6BC0),
        matrix: _moodyMatrix,
        confidence: 0.85,
      ));
    }

    if (warmth > 0.5) {
      recommendations.add(FilterRecommendation(
        name: 'Cool Tone',
        description: 'Warm image — cool tones would add contrast',
        icon: Icons.ac_unit_rounded,
        color: const Color(0xFF26C6DA),
        matrix: _coolMatrix,
        confidence: 0.8,
      ));
    } else {
      recommendations.add(FilterRecommendation(
        name: 'Warm Glow',
        description: 'Cool image — warm tones add life',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF7043),
        matrix: _warmMatrix,
        confidence: 0.8,
      ));
    }

    // Always offer these universal filters
    recommendations.addAll([
      FilterRecommendation(
        name: 'Cinematic',
        description: 'Film-like color grading with teal & orange',
        icon: Icons.movie_filter_rounded,
        color: const Color(0xFFE040FB),
        matrix: _cinematicMatrix,
        confidence: 0.75,
      ),
      FilterRecommendation(
        name: 'Vibrant',
        description: 'Boost saturation for punchy colors',
        icon: Icons.palette_rounded,
        color: const Color(0xFF66BB6A),
        matrix: _vibrantMatrix,
        confidence: 0.7,
      ),
      FilterRecommendation(
        name: 'B&W Classic',
        description: 'Timeless black & white',
        icon: Icons.monochrome_photos_rounded,
        color: const Color(0xFF78909C),
        matrix: _bwMatrix,
        confidence: 0.6,
      ),
      FilterRecommendation(
        name: 'Vintage',
        description: 'Retro faded look with warm highlights',
        icon: Icons.filter_vintage_rounded,
        color: const Color(0xFFBCAAA4),
        matrix: _vintageMatrix,
        confidence: 0.65,
      ),
    ]);

    // Sort by confidence
    recommendations.sort((a, b) => b.confidence.compareTo(a.confidence));
    return recommendations;
  }

  static double _estimateBrightness(Uint8List bytes) {
    if (bytes.length < 100) return 0.5;
    // Sample bytes to estimate average luminance
    double sum = 0;
    int count = 0;
    final step = max(1, bytes.length ~/ 500);
    for (var i = 0; i < bytes.length; i += step) {
      sum += bytes[i] / 255.0;
      count++;
    }
    return count > 0 ? sum / count : 0.5;
  }

  static double _estimateWarmth(Uint8List bytes) {
    if (bytes.length < 300) return 0.5;
    // Very rough: compare early bytes (often R channel heavy) vs later
    double warmSum = 0;
    int count = 0;
    final step = max(3, bytes.length ~/ 200);
    for (var i = 0; i + 2 < bytes.length; i += step) {
      final r = bytes[i];
      final b = bytes[min(i + 2, bytes.length - 1)];
      warmSum += (r - b) / 255.0;
      count++;
    }
    return count > 0 ? (warmSum / count + 1) / 2 : 0.5; // Normalize to 0-1
  }

  // ─── Color Matrices (5x4 format for ColorFilter.matrix) ───

  static const _brightenMatrix = <double>[
    1.2, 0, 0, 0, 30,
    0, 1.2, 0, 0, 30,
    0, 0, 1.2, 0, 30,
    0, 0, 0, 1, 0,
  ];

  static const _moodyMatrix = <double>[
    0.9, 0, 0, 0, -20,
    0, 0.85, 0, 0, -10,
    0, 0, 1.1, 0, 10,
    0, 0, 0, 1, 0,
  ];

  static const _coolMatrix = <double>[
    0.9, 0, 0, 0, 0,
    0, 0.95, 0, 0, 0,
    0, 0, 1.2, 0, 20,
    0, 0, 0, 1, 0,
  ];

  static const _warmMatrix = <double>[
    1.2, 0, 0, 0, 15,
    0, 1.05, 0, 0, 5,
    0, 0, 0.85, 0, -10,
    0, 0, 0, 1, 0,
  ];

  static const _cinematicMatrix = <double>[
    1.1, 0.05, 0, 0, -10,
    0, 1.0, 0.05, 0, 0,
    0.05, 0.1, 1.1, 0, 15,
    0, 0, 0, 1, 0,
  ];

  static const _vibrantMatrix = <double>[
    1.3, -0.1, -0.1, 0, 0,
    -0.1, 1.3, -0.1, 0, 0,
    -0.1, -0.1, 1.3, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const _bwMatrix = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static const _vintageMatrix = <double>[
    0.9, 0.15, 0.05, 0, 20,
    0.05, 0.85, 0.1, 0, 10,
    0.05, 0.1, 0.75, 0, 30,
    0, 0, 0, 1, 0,
  ];
}

class FilterRecommendation {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final List<double> matrix;
  final double confidence;

  const FilterRecommendation({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.matrix,
    required this.confidence,
  });

  String get confidenceLabel => '${(confidence * 100).toInt()}% match';
}
