import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/smart_highlight_service.dart';
import '../../services/ai_caption_service.dart';
import '../../services/ai_filter_service.dart';
import '../../services/ai_thumbnail_service.dart';
import '../../services/api_service.dart';
import '../../widgets/before_after_preview.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../../utils/download_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

class AIFeaturesScreen extends StatefulWidget {
  const AIFeaturesScreen({super.key});

  @override
  State<AIFeaturesScreen> createState() => _AIFeaturesScreenState();
}

class _AIFeaturesScreenState extends State<AIFeaturesScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  int _processingIndex = -1;

  // ─── Tool definitions ───
  final List<_AITool> _tools = [
    _AITool(
      title: 'Smart Auto Highlight',
      desc: 'Detect key moments and suggest best highlight clips',
      icon: Icons.auto_awesome_motion_rounded,
      color: const Color(0xFFFFD700),
      tags: ['Video', 'Auto-Edit'],
      mediaType: 'video',
    ),
    _AITool(
      title: 'AI Filter Recommendation',
      desc: 'Get filter suggestions based on image mood & brightness',
      icon: Icons.auto_fix_high_rounded,
      color: const Color(0xFFE040FB),
      tags: ['Photo', 'Filters'],
      mediaType: 'image',
    ),
    _AITool(
      title: 'AI Thumbnail Generator',
      desc: 'Pick the best frame and add a stylish title overlay',
      icon: Icons.image_search_rounded,
      color: const Color(0xFFFF6B6B),
      tags: ['Video', 'Thumbnail'],
      mediaType: 'video',
    ),
    _AITool(
      title: 'Photo Enhance',
      desc: 'Deep AI enhancement for blurry or low-res photos',
      icon: Icons.hd_rounded,
      color: const Color(0xFF4CAF50),
      tags: ['Photo', 'Enhance', 'API'],
      mediaType: 'image',
      apiEndpoint: '/api/ai/photo-enhance',
    ),
    _AITool(
      title: 'Background Removal',
      desc: 'Instantly strip backgrounds producing transparent PNGs',
      icon: Icons.person_remove_rounded,
      color: const Color(0xFFFF5722),
      tags: ['Photo', 'Remove BG', 'API'],
      mediaType: 'image',
      apiEndpoint: '/api/ai/remove-bg',
    ),
  ];

  // ─── Process each tool ───
  Future<void> _runTool(int index) async {
    final tool = _tools[index];
    setState(() => _processingIndex = index);

    try {
      if (tool.mediaType == 'image') {
        // Image picker with its own error handling
        XFile? xfile;
        try {
          xfile = await _picker.pickImage(
              source: ImageSource.gallery, imageQuality: 95);
        } catch (e) {
          debugPrint('Image picker error in AI tools: $e');
          _showSnack('Failed to open gallery. Please check app permissions.', isError: true);
          return;
        }
        if (xfile == null) {
          setState(() => _processingIndex = -1);
          return;
        }

        final bytes = await xfile.readAsBytes();
        if (tool.title == 'AI Filter Recommendation') {
          _showFilterResults(bytes, xfile.name);
        } else if (tool.apiEndpoint != null) {
          try {
            final data = await _processRealApiTool(tool, bytes, xfile.name);
            _showSuccessDialog(xfile.name, tool.title, data['output_url'], data['metadata'] ?? {}, originalBytes: bytes);
          } catch (e) {
            _showSnack('AI processing failed. The server may be unavailable, please try again later.', isError: true);
            debugPrint('API error: $e');
          }
        }
      } else {
        // File picker — do NOT use withData:true for video (causes OOM on Android)
        PlatformFile? picked;
        try {
          final result = await FilePicker.platform
              .pickFiles(type: FileType.video, withData: false);
          if (result == null || result.files.isEmpty) {
            setState(() => _processingIndex = -1);
            return;
          }
          picked = result.files.single;
        } catch (e) {
          debugPrint('FilePicker error in AI tools: $e');
          _showSnack('Failed to open file picker. Please check app permissions.', isError: true);
          return;
        }

        if (tool.apiEndpoint != null) {
          // Read bytes from path for API upload
          Uint8List? fileBytes;
          if (picked.path != null) {
            fileBytes = await File(picked.path!).readAsBytes();
          } else if (picked.bytes != null) {
            fileBytes = picked.bytes!;
          }
          if (fileBytes != null) {
            try {
              final data = await _processRealApiTool(tool, fileBytes, picked.name);
              _showSuccessDialog(picked.name, tool.title, data['output_url'], data['metadata'] ?? {}, originalBytes: fileBytes);
            } catch (e) {
              _showSnack('AI processing failed. Please check your connection and try again.', isError: true);
              debugPrint('API error: $e');
            }
          } else {
            _showSnack('Could not read the selected file.', isError: true);
          }
          return;
        }

        // Local AI processing — get duration from file
        int demoDuration = 120000; // fallback 2 min
        if (picked.path != null && !kIsWeb) {
          try {
            final videoCtrl = VideoPlayerController.file(File(picked.path!));
            await videoCtrl.initialize();
            demoDuration = videoCtrl.value.duration.inMilliseconds;
            videoCtrl.dispose();
          } catch(_) { /* use fallback */ }
        }

        if (index == 0) {
          _showHighlightResults(demoDuration, picked.name);
        } else if (index == 2) {
          _showThumbnailResults(demoDuration, picked.name);
        }
      }
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processingIndex = -1);
    }
  }

  Future<Map<String, dynamic>> _processRealApiTool(_AITool tool, Uint8List fileBytes, String fileName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}${tool.apiEndpoint}'));
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
      
      // Short timeout — don't hang user if server is unreachable
      final response = await request.send().timeout(const Duration(seconds: 15));
      final respStr = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        return jsonDecode(respStr) as Map<String, dynamic>;
      } else {
        throw Exception('Server error (${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Server is not reachable. This tool requires a network connection.');
    } on SocketException {
      throw Exception('No network connection. This tool requires internet access.');
    } catch (e) {
      throw Exception('Network request failed: $e');
    }
  }

  void _showSuccessDialog(String fileName, String toolTitle, String? outputUrl, Map<String, dynamic> md, {Uint8List? originalBytes}) {
    if (!mounted) return;
    
    final fullUrl = outputUrl != null ? '${ApiService.baseUrl}$outputUrl' : null;
    final isVideo = outputUrl?.toLowerCase().endsWith('.mp4') ?? outputUrl?.toLowerCase().endsWith('.mov') ?? false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('$toolTitle Complete!', style: GoogleFonts.outfit(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (fullUrl != null) ...[
                if (isVideo)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _VideoPreviewWidget(url: fullUrl),
                  )
                else if (originalBytes != null)
                  BeforeAfterPreview(originalBytes: originalBytes, processedUrl: fullUrl)
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(fullUrl, fit: BoxFit.contain, height: 250),
                  ),
                const SizedBox(height: 16),
              ],
              Text('Processed: $fileName', style: GoogleFonts.inter(color: AppTheme.textPrimary, fontSize: 13)),
              const SizedBox(height: 8),
              if (fullUrl != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withAlpha(10), borderRadius: BorderRadius.circular(8)),
                  child: SelectableText('Download Link (Right-click preview to save, or copy this URL):\n$fullUrl', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              if (md.isNotEmpty)
                 Text('Metadata: ${md.toString()}', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ),
        actions: [
          if (fullUrl != null)
             TextButton.icon(
               icon: const Icon(Icons.download_rounded, size: 16, color: AppTheme.primaryPurple),
               label: Text('Save', style: GoogleFonts.inter(color: AppTheme.primaryPurple, fontWeight: FontWeight.bold)),
               onPressed: () async {
                 if (kIsWeb) {
                   downloadFile(fullUrl, '${toolTitle.replaceAll(' ', '_')}_output');
                   _showSnack('Downloading $toolTitle result...');
                   return;
                 }
                 
                 _showSnack('Saving $toolTitle result to Gallery...');
                 try {
                   final response = await http.get(Uri.parse(fullUrl));
                   final tempDir = await getTemporaryDirectory();
                   final ext = isVideo ? '.mp4' : '.png';
                   final file = File('${tempDir.path}/ai_result_${DateTime.now().millisecondsSinceEpoch}$ext');
                   await file.writeAsBytes(response.bodyBytes);
                   
                   if (Platform.isAndroid || Platform.isIOS) {
                     final hasAccess = await Gal.requestAccess(toAlbum: true);
                     if (hasAccess) {
                       if (isVideo) {
                         await Gal.putVideo(file.path, album: 'SmartEdit');
                       } else {
                         await Gal.putImage(file.path, album: 'SmartEdit');
                       }
                       if (mounted) _showSnack('Saved to Gallery successfully!');
                     }
                   }
                 } catch (e) {
                   if (mounted) _showSnack('Failed to save to Gallery: $e', isError: true);
                 }
               },
             ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close', style: GoogleFonts.inter(color: AppTheme.textSecondary))),
        ],
      )
    );
  }

  // ─── Result Dialogs ───

  void _showHighlightResults(int durationMs, String fileName) {
    final highlights = SmartHighlightService.detectHighlights(
      totalDurationMs: durationMs,
      intervalMs: 4000,
      maxHighlights: 6,
    );
    final summary = SmartHighlightService.generateSummary(highlights);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        title: '🎬 Smart Highlights',
        subtitle: fileName,
        summary: summary,
        child: Column(
          children: highlights.map((h) => _highlightTile(h)).toList(),
        ),
      ),
    );
  }

  Widget _highlightTile(HighlightClip h) {
    final scoreColor = h.score > 0.7
        ? const Color(0xFF00E676)
        : h.score > 0.5
            ? const Color(0xFFFFD740)
            : AppTheme.textMuted;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.getElevatedColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scoreColor.withAlpha(40)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scoreColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${(h.score * 100).toInt()}',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scoreColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.label,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(h.timeRange,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, color: AppTheme.textMuted)),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scoreColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${h.duration.inSeconds}s',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scoreColor)),
        ),
      ]),
    );
  }

  void _showApiCaptionResults(Map<String, dynamic> metadata, String fileName) {
    final subs = metadata['subtitles'] as List<dynamic>? ?? [];
    final srtContent = metadata['srt_content'] as String? ?? '';
    final detectedLang = metadata['language'] ?? 'unknown';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        title: '📝 AI Captions',
        subtitle: fileName,
        summary: '${subs.length} captions generated • Source: $detectedLang • Auto-translated to English',
        child: Column(children: [
          ...subs.map((c) {
            return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getElevatedColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                   // just show start time
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26C6DA).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${c['start']}s',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: const Color(0xFF26C6DA))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c['text'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textPrimary)),
                  ),
                ]),
              );
            }),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF26C6DA).withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF26C6DA).withAlpha(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SRT Preview',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF26C6DA))),
                const SizedBox(height: 6),
                Text(
                  srtContent.length > 400 ? '${srtContent.substring(0, 400)}...' : srtContent,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showCaptionResults(int durationMs, String fileName) {
    final captions = AiCaptionService.generateCaptions(
      totalDurationMs: durationMs,
      segmentMs: 3000,
    );
    final srt = AiCaptionService.toSrt(captions);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        title: '📝 AI Captions',
        subtitle: fileName,
        summary: '${captions.length} captions generated • SRT ready',
        child: Column(children: [
          ...captions.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.getElevatedColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26C6DA).withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(c.timeRange,
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: const Color(0xFF26C6DA))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.text,
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textPrimary)),
                  ),
                ]),
              )),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF26C6DA).withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF26C6DA).withAlpha(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SRT Preview',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF26C6DA))),
                const SizedBox(height: 6),
                Text(
                  srt.length > 400 ? '${srt.substring(0, 400)}...' : srt,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showFilterResults(Uint8List imageBytes, String fileName) {
    final filters = AiFilterService.recommendFilters(imageBytes);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        title: '🎨 Filter Recommendations',
        subtitle: fileName,
        summary: '${filters.length} filters recommended based on image analysis',
        child: Column(
          children: filters.map((f) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: f.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(f.icon, color: f.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(f.name,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: f.color.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(f.confidenceLabel,
                                  style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: f.color)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(f.description,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textMuted)),
                        ]),
                  ),
                  // Preview swatch
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: f.color.withAlpha(60)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.matrix(f.matrix),
                        child: Image.memory(imageBytes,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(color: f.color.withAlpha(30))),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showThumbnailResults(int durationMs, String fileName) {
    final candidates = AiThumbnailService.generateCandidates(
      totalDurationMs: durationMs,
      count: 5,
    );
    final styles = AiThumbnailService.stylePresets;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResultSheet(
        title: '🖼️ Thumbnail Generator',
        subtitle: fileName,
        summary:
            '${candidates.length} candidates • ${styles.length} style presets',
        child: Column(children: [
          Text('Best Frame Candidates',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          ...candidates.asMap().entries.map((e) {
            final c = e.value;
            final isTop = e.key == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.getElevatedColor(context),
                borderRadius: BorderRadius.circular(12),
                border: isTop
                    ? Border.all(
                        color: const Color(0xFFFF6B6B).withAlpha(60))
                    : null,
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: isTop
                        ? const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFE040FB)])
                        : null,
                    color: isTop ? null : Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: isTop
                        ? const Icon(Icons.star_rounded,
                            color: Colors.white, size: 20)
                        : Text(
                            '${e.key + 1}',
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textMuted),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTop
                              ? '⭐ Best Frame — ${c.formattedTime}'
                              : 'Frame at ${c.formattedTime}',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary),
                        ),
                        Text(c.reason,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textMuted)),
                      ]),
                ),
                Text('${(c.score * 100).toInt()}%',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF6B6B))),
              ]),
            );
          }),
          const SizedBox(height: 16),
          Text('Style Presets',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: styles.map((s) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: s.bgColor.withAlpha(60),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: s.textColor.withAlpha(40)),
                ),
                child: Text(s.name,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: s.fontWeight,
                        color: s.textColor)),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: isError ? Colors.redAccent : AppTheme.accentCyan,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, gradient: AppTheme.getBackgroundGradient(context)),
        child: SafeArea(
          child: Column(children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildBanner(),
                    const SizedBox(height: 24),
                    Text('AI Tools',
                        style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text('All processing runs locally — instant results',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 16),
                    ..._tools.asMap().entries.map((e) => FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          delay: Duration(milliseconds: e.key * 80),
                          child: _buildToolCard(e.key, e.value),
                        )),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return FadeInDown(
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: AppTheme.textPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('AI Tools',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFF6B6B),
                ]),
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text('Local AI',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildBanner() {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF667EEA).withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Practical AI Tools',
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a file and let AI analyze it instantly. No server, no waiting — works offline.',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.white70),
                  ),
                ]),
          ),
          const SizedBox(width: 16),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(16)),
            child:
                const Icon(Icons.bolt_rounded, size: 32, color: Colors.white),
          ),
        ]),
      ),
    );
  }

  Widget _buildToolCard(int index, _AITool tool) {
    final isProcessing = _processingIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: tool.color.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(tool.icon, color: tool.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tool.title,
                        style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(tool.desc,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppTheme.textMuted),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isProcessing ? null : () => _runTool(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isProcessing
                      ? null
                      : LinearGradient(
                          colors: [tool.color, tool.color.withAlpha(180)]),
                  color: isProcessing ? Colors.white.withAlpha(10) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('Run',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            ...tool.tags.map((tag) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tool.color.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tag,
                      style: GoogleFonts.inter(
                          fontSize: 10,
                          color: tool.color,
                          fontWeight: FontWeight.w500)),
                )),
            const Spacer(),
            Icon(tool.apiEndpoint != null ? Icons.cloud_rounded : Icons.bolt_rounded, size: 12, color: tool.color),
            const SizedBox(width: 4),
            Text(tool.apiEndpoint != null ? 'Cloud' : 'Offline',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: tool.color,
                    fontWeight: FontWeight.w500)),
          ]),
        ]),
      ),
    );
  }
}

// ─── Models ───

class _AITool {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final List<String> tags;
  final String mediaType;
  final String? apiEndpoint;

  const _AITool({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.tags,
    required this.mediaType,
    this.apiEndpoint,
  });
}

// ─── Shared Result Bottom Sheet ───

class _ResultSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final String summary;
  final Widget child;

  const _ResultSheet({
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppTheme.getElevatedColor(context),
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF00E676).withAlpha(30)),
                ),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: Color(0xFF00E676)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(summary,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF00E676))),
                  ),
                ]),
              ),
            ],
          ),
        ),
        Divider(color: AppTheme.getElevatedColor(context), height: 1),
        // Content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: child,
          ),
        ),
      ]),
    );
  }
}

class _VideoPreviewWidget extends StatefulWidget {
  final String url;
  const _VideoPreviewWidget({required this.url});

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container(height: 200, color: Colors.black26, child: const Center(child: CircularProgressIndicator()));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
