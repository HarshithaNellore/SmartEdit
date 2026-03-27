import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../services/api_service.dart';
import '../../services/ai_service.dart';

class AIAgentScreen extends StatefulWidget {
  const AIAgentScreen({super.key});

  @override
  State<AIAgentScreen> createState() => _AIAgentScreenState();
}

class _AIAgentScreenState extends State<AIAgentScreen> with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  Uint8List? _fileBytes;
  String _fileName = '';
  bool _isImage = false;

  // Processing state
  bool _processing = false;
  String _statusMessage = '';
  List<Map<String, dynamic>> _stepLogs = [];
  Map<String, dynamic>? _result;
  List<String>? _parsedSteps;
  int _currentStep = 0;

  final ImagePicker _picker = ImagePicker();

  final List<String> _examplePrompts = [
    'Enhance image and remove background',
    'Flip the image horizontally',
    'Rotate 90 degrees and enhance',
    'Blur the background (portrait mode)',
    'Make colors more vibrant and warm',
    'Change the direction of head to opposite',
    'Make it look professional',
    'Remove bg and blur background',
    'Reframe video for Instagram (9:16)',
    'Find highlights and suggest edits',
  ];

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // ─── File Selection ───
  Future<void> _pickFile({required bool isImage}) async {
    if (isImage) {
      final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _fileBytes = bytes;
        _fileName = xfile.name;
        _isImage = true;
        _result = null;
      });
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      if (picked.bytes == null) return;
      setState(() {
        _fileBytes = picked.bytes;
        _fileName = picked.name;
        _isImage = false;
        _result = null;
      });
    }
  }

  // ─── Execute Agent ───
  Future<void> _runAgent() async {
    if (_fileBytes == null) {
      _showSnack('Please select a file first');
      return;
    }
    if (_promptController.text.trim().isEmpty) {
      _showSnack('Please enter an editing prompt');
      return;
    }

    setState(() {
      _processing = true;
      _statusMessage = '🧠 Understanding your request...';
      _stepLogs = [];
      _result = null;
      _parsedSteps = null;
      _currentStep = 0;
    });

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/ai/agent-edit');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        _fileBytes!,
        filename: _fileName,
      ));
      request.fields['prompt'] = _promptController.text.trim();

      final token = await ApiService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Simulate step-by-step progress
      setState(() => _statusMessage = '📤 Uploading file...');
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() => _statusMessage = '⚡ Processing with AI pipeline...');

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 15),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        setState(() {
          _result = data;
          _parsedSteps = (data['parsed_steps'] as List?)?.cast<String>() ?? [];
          _stepLogs = (data['step_logs'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _statusMessage = '✅ Done! ${data['steps_succeeded']}/${data['steps_executed']} steps completed';
          _processing = false;
        });
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        setState(() {
          _statusMessage = '⚠️ ${data['message'] ?? 'Could not parse prompt'}';
          _processing = false;
        });
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['detail'] ?? 'Server error ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Error: ${e.toString().replaceAll('Exception: ', '')}';
        _processing = false;
      });
    }
  }

  // ─── Download Result ───
  Future<void> _downloadResult() async {
    final outputUrl = _result?['output_url'] as String?;
    if (outputUrl == null) {
      _showSnack('No output file to save');
      return;
    }

    final fullUrl = AiService.getOutputUrl(outputUrl);
    try {
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode != 200) throw Exception('Download failed');

      final blob = html.Blob([response.bodyBytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      final ext = outputUrl.split('.').last;
      final name = 'ai_agent_result.$ext';

      html.AnchorElement(href: blobUrl)
        ..setAttribute('download', name)
        ..click();
      html.Url.revokeObjectUrl(blobUrl);

      _showSnack('✅ Downloaded: $name');
    } catch (e) {
      _showSnack('Download failed: $e', isError: true);
    }
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
                      _buildHeroBanner(),
                      const SizedBox(height: 20),
                      _buildFileUpload(),
                      const SizedBox(height: 16),
                      _buildPromptInput(),
                      const SizedBox(height: 12),
                      _buildExamplePrompts(),
                      const SizedBox(height: 20),
                      _buildRunButton(),
                      const SizedBox(height: 20),
                      if (_processing || _statusMessage.isNotEmpty)
                        _buildProgressSection(),
                      if (_result != null)
                        _buildResultSection(),
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
            Expanded(child: Text('AI Agent Editor', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFE040FB)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text('Agent', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFE040FB), Color(0xFF667EEA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFFE040FB).withAlpha(50), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Natural Language Editing', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Describe what you want in plain English. The AI agent will parse your request, choose the right tools, and execute them automatically.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
          ])),
          const SizedBox(width: 16),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.smart_toy_rounded, size: 32, color: Colors.white),
          ),
        ]),
      ),
    );
  }

  Widget _buildFileUpload() {
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Choose a file', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _uploadButton('📷 Pick Image', () => _pickFile(isImage: true), AppTheme.primaryPurple)),
              const SizedBox(width: 10),
              Expanded(child: _uploadButton('🎬 Pick Video', () => _pickFile(isImage: false), AppTheme.accentOrange)),
            ]),
            if (_fileBytes != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.accentCyan.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(_isImage ? Icons.image : Icons.videocam, size: 18, color: AppTheme.accentCyan),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_fileName, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis)),
                  Text('${(_fileBytes!.length / 1024).toStringAsFixed(0)} KB', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted)),
                ]),
              ),
              // Thumbnail for images
              if (_isImage) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_fileBytes!, height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _uploadButton(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: _processing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Center(child: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
      ),
    );
  }

  Widget _buildPromptInput() {
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('2. Describe your edit', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha(10)),
            ),
            child: TextField(
              controller: _promptController,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. "Enhance image and remove background"',
                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                suffixIcon: _promptController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted), onPressed: () { setState(() => _promptController.clear()); })
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildExamplePrompts() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _examplePrompts.map((p) => GestureDetector(
        onTap: () => setState(() => _promptController.text = p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withAlpha(8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withAlpha(15))),
          child: Text(p, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
        ),
      )).toList(),
    );
  }

  Widget _buildRunButton() {
    final ready = _fileBytes != null && _promptController.text.trim().isNotEmpty && !_processing;
    return FadeInUp(
      delay: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: ready ? _runAgent : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: ready
                ? const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFE040FB)])
                : null,
            color: ready ? null : Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(14),
            boxShadow: ready ? [BoxShadow(color: const Color(0xFFE040FB).withAlpha(40), blurRadius: 16, offset: const Offset(0, 6))] : null,
          ),
          child: Center(
            child: _processing
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    const SizedBox(width: 10),
                    Text('Processing...', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ])
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Run AI Agent', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return FadeInUp(
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Agent Status', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          // Status message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.darkElevated, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              if (_processing) ...[
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentCyan)),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(_statusMessage, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary))),
            ]),
          ),
          // AI Intent explanation
          if (_result != null && _result!['intent'] != null && (_result!['intent'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primaryPurple.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.primaryPurple.withAlpha(30))),
              child: Row(children: [
                const Icon(Icons.psychology, size: 16, color: AppTheme.primaryPurple),
                const SizedBox(width: 8),
                Expanded(child: Text('AI: ${_result!['intent']}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary))),
              ]),
            ),
          ],
          // Fallback notice
          if (_result != null && _result!['fallback'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.accentOrange.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.accentOrange.withAlpha(30))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.accentOrange),
                const SizedBox(width: 8),
                Expanded(child: Text('${_result!['fallback']}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentOrange))),
              ]),
            ),
          ],
          // Parsed steps
          if (_parsedSteps != null && _parsedSteps!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Executed Steps:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: _parsedSteps!.asMap().entries.map((e) {
              final idx = e.key;
              final tool = e.value;
              final log = idx < _stepLogs.length ? _stepLogs[idx] : null;
              final success = log?['status'] == 'success';
              final failed = log?['status'] == 'failed';

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: success ? const Color(0xFF00E676).withAlpha(20) : failed ? Colors.redAccent.withAlpha(20) : AppTheme.primaryPurple.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: success ? const Color(0xFF00E676).withAlpha(60) : failed ? Colors.redAccent.withAlpha(60) : AppTheme.primaryPurple.withAlpha(40)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${idx + 1}. ', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.textMuted)),
                  Text(tool.replaceAll('_', ' '), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: success ? const Color(0xFF00E676) : failed ? Colors.redAccent : AppTheme.textPrimary)),
                  if (success) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.check_circle, size: 12, color: Color(0xFF00E676))),
                  if (failed) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.error, size: 12, color: Colors.redAccent)),
                  if (log != null && log['processing_time'] != null) Text(' ${log['processing_time']}s', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: AppTheme.textMuted)),
                ]),
              );
            }).toList()),
          ],
        ]),
      ),
    );
  }

  Widget _buildResultSection() {
    final outputUrl = _result?['output_url'] as String?;
    final fullUrl = outputUrl != null ? AiService.getOutputUrl(outputUrl) : null;
    final totalTime = _result?['total_processing_time'];

    return FadeInUp(
      child: Column(children: [
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.check_circle, size: 20, color: Color(0xFF00E676)),
              const SizedBox(width: 8),
              Expanded(child: Text('Result', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
              if (totalTime != null)
                Text('${totalTime}s', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.accentCyan)),
            ]),
            // Message from agent
            if (_result!['message'] != null) ...[
              const SizedBox(height: 8),
              Text('${_result!['message']}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 12),

            // Image preview
            if (fullUrl != null && _isImage)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Before/After
                if (_fileBytes != null) ...[
                  Row(children: [
                    Expanded(child: Column(children: [
                      Text('Before', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
                      const SizedBox(height: 4),
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_fileBytes!, height: 160, fit: BoxFit.contain)),
                    ])),
                    const SizedBox(width: 10),
                    Expanded(child: Column(children: [
                      Text('After', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.accentCyan)),
                      const SizedBox(height: 4),
                      ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(fullUrl, height: 160, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(height: 160, color: AppTheme.darkElevated, child: const Center(child: Icon(Icons.broken_image, color: AppTheme.textMuted))))),
                    ])),
                  ]),
                ] else
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(fullUrl, height: 220, width: double.infinity, fit: BoxFit.contain)),
                const SizedBox(height: 12),
              ]),

            // Video link
            if (fullUrl != null && !_isImage)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.darkElevated, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.play_circle, color: AppTheme.accentCyan, size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Processed video ready', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary))),
                  TextButton(
                    child: Text('Open', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accentCyan)),
                    onPressed: () => html.window.open(fullUrl, '_blank'),
                  ),
                ]),
              ),

            // No output (metadata-only features)
            if (fullUrl == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.darkElevated, borderRadius: BorderRadius.circular(12)),
                child: Text('This pipeline produced metadata/analysis results only (no output file).', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(children: [
              if (fullUrl != null)
                Expanded(child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: Text('Download Result', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _downloadResult,
                )),
              if (fullUrl != null) const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.edit, size: 16),
                label: Text('Edit & Retry', style: GoogleFonts.inter(fontSize: 12)),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentOrange, side: const BorderSide(color: AppTheme.accentOrange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => setState(() => _result = null),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }
}
