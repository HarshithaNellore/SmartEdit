import 'dart:math';

/// Local AI caption/subtitle generation service.
/// Generates demo captions with timestamps. Architecture ready for real
/// speech-to-text (e.g., Whisper, Google STT) integration.
class AiCaptionService {
  /// Generate demo captions for a video
  static List<Caption> generateCaptions({
    required int totalDurationMs,
    int segmentMs = 3000,
  }) {
    final random = Random(totalDurationMs);
    final phrases = _samplePhrases;
    final captions = <Caption>[];
    var currentMs = 0;
    var phraseIndex = 0;

    while (currentMs < totalDurationMs) {
      final gap = 200 + random.nextInt(800); // natural pause
      final startMs = currentMs + gap;
      final duration = 1500 + random.nextInt(2500);
      final endMs = min(startMs + duration, totalDurationMs);
      if (startMs >= totalDurationMs) break;

      captions.add(Caption(
        index: captions.length,
        startMs: startMs,
        endMs: endMs,
        text: phrases[phraseIndex % phrases.length],
      ));

      currentMs = endMs;
      phraseIndex++;
    }

    return captions;
  }

  /// Generate SRT format string from captions
  static String toSrt(List<Caption> captions) {
    final buf = StringBuffer();
    for (var i = 0; i < captions.length; i++) {
      buf.writeln('${i + 1}');
      buf.writeln('${_srtTime(captions[i].startMs)} --> ${_srtTime(captions[i].endMs)}');
      buf.writeln(captions[i].text);
      buf.writeln();
    }
    return buf.toString();
  }

  static String _srtTime(int ms) {
    final hours = (ms ~/ 3600000).toString().padLeft(2, '0');
    final mins = ((ms ~/ 60000) % 60).toString().padLeft(2, '0');
    final secs = ((ms ~/ 1000) % 60).toString().padLeft(2, '0');
    final millis = (ms % 1000).toString().padLeft(3, '0');
    return '$hours:$mins:$secs,$millis';
  }

  static const _samplePhrases = [
    'Welcome to this amazing video',
    'Let me show you something incredible',
    'Pay attention to this detail',
    'This is the key moment',
    'Notice the lighting here',
    'The composition is perfect',
    'Watch what happens next',
    'This transition is seamless',
    'Here comes the best part',
    'And that wraps it up beautifully',
    'Thanks for watching',
    'Don\'t forget to subscribe',
    'See you in the next one',
    'Leave your thoughts below',
    'This was a great experience',
  ];
}

class Caption {
  final int index;
  final int startMs;
  final int endMs;
  final String text;

  const Caption({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  String get timeRange =>
      '${_fmt(startMs)} → ${_fmt(endMs)}';

  static String _fmt(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final rem = s % 60;
    return '${m.toString().padLeft(2, '0')}:${rem.toString().padLeft(2, '0')}';
  }

  Duration get duration => Duration(milliseconds: endMs - startMs);
}
