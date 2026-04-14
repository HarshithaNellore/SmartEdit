import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';

/// High-performance thumbnail extraction service with built-in caching.
/// Generates sequential thumbnails from video files for filmstrip timelines.
class ThumbnailService {
  // In-memory cache: key = "filePath_timestampMs", value = file path
  static final Map<String, String> _cache = {};
  static String? _cacheDir;

  /// Get or create the thumbnail cache directory.
  static Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final dir = await getTemporaryDirectory();
    final thumbDir = Directory('${dir.path}/smartcut_thumbnails');
    if (!await thumbDir.exists()) {
      await thumbDir.create(recursive: true);
    }
    _cacheDir = thumbDir.path;
    return _cacheDir!;
  }

  /// Generate a single thumbnail at a specific timestamp.
  /// Returns the file path of the generated thumbnail, or null on failure.
  static Future<String?> getThumbnailAt({
    required String videoPath,
    required int timestampMs,
    int width = 80,
    int height = 56,
  }) async {
    if (kIsWeb) return null;

    final cacheKey = '${videoPath.hashCode}_${timestampMs}_${width}x$height';

    // Check in-memory cache first
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (await File(cached).exists()) {
        return cached;
      } else {
        _cache.remove(cacheKey);
      }
    }

    try {
      final cacheDir = await _getCacheDir();
      final outputPath = '$cacheDir/thumb_${cacheKey.hashCode}.jpg';

      // Check if file already exists on disk
      if (await File(outputPath).exists()) {
        _cache[cacheKey] = outputPath;
        return outputPath;
      }

      final timestampSec = timestampMs / 1000.0;

      if (Platform.isWindows) {
        // Use native ffmpeg process on Windows
        final result = await Process.run('ffmpeg', [
          '-ss', timestampSec.toStringAsFixed(3),
          '-i', videoPath,
          '-vframes', '1',
          '-vf', 'scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:-1:-1:color=black',
          '-q:v', '8',
          '-y',
          outputPath,
        ], runInShell: true);

        if (result.exitCode == 0 && await File(outputPath).exists()) {
          _cache[cacheKey] = outputPath;
          return outputPath;
        }
      } else {
        // Use FFmpegKit on mobile
        final command =
            '-ss ${timestampSec.toStringAsFixed(3)} '
            '-i "$videoPath" '
            '-vframes 1 '
            '-vf "scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:-1:-1:color=black" '
            '-q:v 8 '
            '-y "$outputPath"';

        final session = await FFmpegKit.execute(command);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode) && await File(outputPath).exists()) {
          _cache[cacheKey] = outputPath;
          return outputPath;
        }
      }
    } catch (e) {
      debugPrint('ThumbnailService: Failed to extract thumbnail at ${timestampMs}ms: $e');
    }

    return null;
  }

  /// Generate thumbnails at fixed intervals for a video clip.
  /// Returns a list of thumbnail file paths (some may be null if extraction failed).
  /// [intervalMs] controls density — smaller = more thumbnails.
  static Future<List<String?>> generateThumbnails({
    required String videoPath,
    required int durationMs,
    required double trimStart,
    required double trimEnd,
    int intervalMs = 1000,
    int width = 80,
    int height = 56,
  }) async {
    if (kIsWeb || durationMs <= 0) return [];

    final startMs = (trimStart * durationMs).round();
    final endMs = (trimEnd * durationMs).round();
    final activeDurationMs = endMs - startMs;

    if (activeDurationMs <= 0) return [];

    // Calculate number of thumbnails
    final numThumbnails = (activeDurationMs / intervalMs).ceil().clamp(1, 60);
    final actualInterval = activeDurationMs / numThumbnails;

    final List<String?> thumbnails = [];

    // Generate thumbnails sequentially to avoid overwhelming the device
    for (int i = 0; i < numThumbnails; i++) {
      final ts = startMs + (i * actualInterval).round();
      final path = await getThumbnailAt(
        videoPath: videoPath,
        timestampMs: ts,
        width: width,
        height: height,
      );
      thumbnails.add(path);
    }

    return thumbnails;
  }

  /// Clear the thumbnail cache (both in-memory and disk).
  static Future<void> clearCache() async {
    _cache.clear();
    try {
      final cacheDir = await _getCacheDir();
      final dir = Directory(cacheDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('ThumbnailService: Failed to clear cache: $e');
    }
  }

  /// Get the number of cached thumbnails.
  static int get cacheSize => _cache.length;
}
