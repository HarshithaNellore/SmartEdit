import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/ai_service.dart';
import 'ai_result_dialog.dart';

class AIFeaturesScreen extends StatefulWidget {
  const AIFeaturesScreen({super.key});

  @override
  State<AIFeaturesScreen> createState() => _AIFeaturesScreenState();
}

class _AIFeaturesScreenState extends State<AIFeaturesScreen> {
  int _processingFeature = -1;
  final Map<int, double> _progress = {};

  // Each feature: title, desc, icon, color, tags, endpoint, mediaType ('image' or 'video')
  final List<_AIFeature> _features = [
    _AIFeature(
      title: 'AI Photo Enhancement',
      desc: 'Enhance photo quality — fix lighting, sharpness, and colors using AI',
      icon: Icons.auto_fix_high_rounded,
      color: AppTheme.primaryPurple,
      tags: ['Photo', 'Enhancement'],
      endpoint: 'photo-enhance',
      mediaType: 'image',
    ),
    _AIFeature(
      title: 'Background Removal',
      desc: 'Remove backgrounds from photos with AI-powered segmentation',
      icon: Icons.content_cut_rounded,
      color: AppTheme.primaryPink,
      tags: ['Photo', 'Video'],
      endpoint: 'remove-bg',
      mediaType: 'image',
    ),
    _AIFeature(
      title: 'Smart Auto-Reframe',
      desc: 'Crop and reframe videos for different aspect ratios (9:16, 1:1)',
      icon: Icons.crop_rotate_rounded,
      color: const Color(0xFFE040FB),
      tags: ['Video', 'Social Media'],
      endpoint: 'reframe',
      mediaType: 'video',
    ),
    _AIFeature(
      title: 'Highlight Detection',
      desc: 'Find the best moments based on motion and audio analysis',
      icon: Icons.star_rounded,
      color: const Color(0xFFFFD700),
      tags: ['Video', 'Auto-Edit'],
      endpoint: 'highlights',
      mediaType: 'video',
    ),
    _AIFeature(
      title: 'Smart Edit Suggestions',
      desc: 'Get AI recommendations for cuts, transitions, filters, and more',
      icon: Icons.lightbulb_rounded,
      color: const Color(0xFFFF6B6B),
      tags: ['Video', 'Photo', 'AI'],
      endpoint: 'suggestions',
      mediaType: 'video',
    ),
  ];

  final ImagePicker _picker = ImagePicker();

  // ─── Real AI processing flow ───
  void _startProcessing(int index) async {
    final feature = _features[index];
    Uint8List? fileBytes;
    String fileName = 'file';

    try {
      // 1. Pick file and get bytes — works on Web, Desktop, Mobile
      if (feature.mediaType == 'image') {
        final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
        if (xfile == null) {
          _showSnack('Please select an image first');
          return;
        }
        fileBytes = await xfile.readAsBytes();
        fileName = xfile.name;
      } else {
        // Use file_picker with withData: true to get bytes on all platforms
        final result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          _showSnack('Please select a video file first');
          return;
        }
        final picked = result.files.single;
        fileBytes = picked.bytes;
        if (fileBytes == null) {
          _showSnack('Could not read file data');
          return;
        }
        fileName = picked.name;
      }

      // 2. Start progress animation
      setState(() {
        _processingFeature = index;
        _progress[index] = 0.0;
      });

      // Animate progress while processing
      _animateProgress(index);

      // 3. Upload bytes and process via backend
      final result = await AiService.processFile(
        endpoint: feature.endpoint,
        fileBytes: fileBytes,
        fileName: fileName,
      );

      // 4. Stop progress
      setState(() {
        _progress[index] = 1.0;
        _processingFeature = -1;
      });

      if (!mounted) return;

      // 5. Show result dialog with REAL preview
      final hasOutputFile = result['output_url'] != null;
      showDialog(
        context: context,
        builder: (_) => AIResultDialog(
          featureTitle: feature.title,
          originalBytes: fileBytes,
          originalFileName: fileName,
          result: result,
          isImageResult: feature.mediaType == 'image' && hasOutputFile,
          isVideoResult: feature.mediaType == 'video' && hasOutputFile,
          onRerun: () => _startProcessing(index),
        ),
      );
    } catch (e) {
      setState(() => _processingFeature = -1);
      if (mounted) {
        _showSnack('Error: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
      }
    }
  }

  void _animateProgress(int index) {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted || _processingFeature != index) return false;
      final current = _progress[index] ?? 0;
      if (current >= 0.9) return false; // Cap at 90% until backend responds
      setState(() {
        // Slow exponential approach to 90%
        _progress[index] = current + (0.9 - current) * 0.04;
      });
      return true;
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: Column(
            children: [
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
                      const SizedBox(height: 16),
                      _buildAgentCard(),
                      const SizedBox(height: 24),
                      Text('AI Tools', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 16),
                      ..._features.asMap().entries.map((e) => FadeInUp(
                            duration: const Duration(milliseconds: 400),
                            delay: Duration(milliseconds: e.key * 80),
                            child: _buildFeatureCard(e.key, e.value),
                          )),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return FadeInDown(
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('AI Features', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.accentCyan.withAlpha(30), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: AppTheme.accentCyan),
                  const SizedBox(width: 4),
                  Text('Powered by ML', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentCyan)),
                ],
              ),
            ),
          ],
        ),
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
          boxShadow: [BoxShadow(color: const Color(0xFF667EEA).withAlpha(60), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Processing Pipeline', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    'Select a media file and choose an AI tool to process it. Results include before/after preview.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.psychology, size: 32, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildAgentCard() {
    return FadeInUp(
      duration: const Duration(milliseconds: 450),
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/ai-agent'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFE040FB), Color(0xFF667EEA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withAlpha(40), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.smart_toy_rounded, size: 26, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('AI Agent Editor', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Describe edits in plain English — AI executes automatically', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
            ])),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
          ]),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(int index, _AIFeature feature) {
    final isProcessing = _processingFeature == index;
    final progress = _progress[index] ?? 0.0;
    final isDone = progress >= 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(feature.icon, color: feature.color, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(feature.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(feature.desc, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: isProcessing ? null : () => _startProcessing(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isProcessing ? null : LinearGradient(colors: [feature.color, feature.color.withAlpha(180)]),
                      color: isProcessing ? Colors.white.withAlpha(10) : null,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isDone ? 'Done ✓' : isProcessing ? 'Processing...' : 'Run',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            if (isProcessing) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.darkElevated,
                  valueColor: AlwaysStoppedAnimation<Color>(feature.color),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.hourglass_top, size: 12, color: feature.color),
                  const SizedBox(width: 4),
                  Text('Uploading & processing on server...',
                      style: GoogleFonts.inter(fontSize: 10, color: feature.color)),
                  const Spacer(),
                  Text('${(progress * 100).toInt()}%', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: feature.color)),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: feature.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: feature.color.withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: Text(tag, style: GoogleFonts.inter(fontSize: 10, color: feature.color, fontWeight: FontWeight.w500)),
                  )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AIFeature {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final List<String> tags;
  final String endpoint;
  final String mediaType;
  const _AIFeature({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.tags,
    required this.endpoint,
    required this.mediaType,
  });
}
