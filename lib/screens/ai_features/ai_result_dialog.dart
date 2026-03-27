import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/ai_service.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;

/// Result dialog with REAL image/video preview and download-to-save.
class AIResultDialog extends StatefulWidget {
  final String featureTitle;
  final Uint8List? originalBytes; // original file bytes for "Before" preview
  final String? originalFileName;
  final Map<String, dynamic> result;
  final VoidCallback onRerun;
  final bool isImageResult;
  final bool isVideoResult;

  const AIResultDialog({
    super.key,
    required this.featureTitle,
    this.originalBytes,
    this.originalFileName,
    required this.result,
    required this.onRerun,
    this.isImageResult = false,
    this.isVideoResult = false,
  });

  @override
  State<AIResultDialog> createState() => _AIResultDialogState();
}

class _AIResultDialogState extends State<AIResultDialog> {
  bool _saving = false;

  String? get _outputUrl {
    final url = widget.result['output_url'] as String?;
    if (url == null) return null;
    return AiService.getOutputUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.result['metadata'] as Map<String, dynamic>? ?? {};
    final hasOutput = _outputUrl != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 520,
        ),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── IMAGE PREVIEW ──
                    if (widget.isImageResult && hasOutput)
                      _buildImagePreview(),

                    // ── VIDEO PREVIEW ──
                    if (widget.isVideoResult && hasOutput)
                      _buildVideoPreview(),

                    // ── Metadata ──
                    const SizedBox(height: 16),
                    _buildMetadataSection(metadata),

                    // ── Scenes ──
                    if (metadata.containsKey('scenes'))
                      _buildScenesList(metadata['scenes'] as List),

                    // ── Highlights ──
                    if (metadata.containsKey('highlights') && metadata['highlights'] is List)
                      _buildHighlightsList(metadata['highlights'] as List),

                    // ── Suggestions ──
                    if (metadata.containsKey('suggestions'))
                      _buildSuggestionsList(metadata['suggestions'] as List),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  REAL IMAGE PREVIEW — Before vs After
  // ═══════════════════════════════════════════
  Widget _buildImagePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          widget.originalBytes != null ? 'Before → After' : 'Processed Result',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 10),
        if (widget.originalBytes != null)
          // Side-by-side Before/After
          Row(
            children: [
              Expanded(child: _imageColumn('Before', Image.memory(
                widget.originalBytes!,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _brokenPlaceholder(),
              ))),
              const SizedBox(width: 10),
              Expanded(child: _imageColumn('After', Image.network(
                _outputUrl!,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _brokenPlaceholder(),
              ))),
            ],
          )
        else
          // Full-width processed image
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              _outputUrl!,
              width: double.infinity,
              height: 250,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _brokenPlaceholder(height: 250),
            ),
          ),
      ],
    );
  }

  Widget _imageColumn(String label, Widget image) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: label == 'After' ? AppTheme.accentCyan : AppTheme.textMuted,
        )),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: Colors.black26,
            child: image,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  REAL VIDEO PREVIEW
  // ═══════════════════════════════════════════
  Widget _buildVideoPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text('Processed Video', style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary,
        )),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme.darkElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.accentCyan.withAlpha(40)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_filled, size: 48, color: AppTheme.accentCyan),
              const SizedBox(height: 8),
              SelectableText(
                _outputUrl!,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: AppTheme.accentCyan),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text('Open in Browser', style: GoogleFonts.inter(fontSize: 11)),
                style: TextButton.styleFrom(foregroundColor: AppTheme.accentCyan),
                onPressed: () {
                  html.window.open(_outputUrl!, '_blank');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _brokenPlaceholder({double height = 180}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.darkElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Icon(Icons.broken_image, color: AppTheme.textMuted, size: 32)),
    );
  }

  // ═══════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(10))),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.accentCyan, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${widget.featureTitle} — Result',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  METADATA
  // ═══════════════════════════════════════════
  Widget _buildMetadataSection(Map<String, dynamic> metadata) {
    final displayKeys = metadata.keys.where((k) =>
        k != 'subtitles' && k != 'srt_content' && k != 'scenes' &&
        k != 'highlights' && k != 'suggestions' && k != 'cuts' &&
        k != 'output_path' && k != 'srt_path');
    if (displayKeys.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Processing Details', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.darkElevated, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: displayKeys.map((key) {
              final val = metadata[key];
              final label = key.replaceAll('_', ' ').replaceFirstMapped(RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted))),
                  Text(val is Map || val is List ? '...' : '$val',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.accentCyan)),
                ]),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildScenesList(List scenes) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text('Detected Scenes (${scenes.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      ...scenes.take(10).map((s) => _infoTile('Scene ${s['index']}', '${s['start_timecode']} → ${s['end_timecode']} (${s['duration_sec']}s)', Icons.movie_filter_rounded, AppTheme.accentOrange)),
    ]);
  }

  Widget _buildHighlightsList(List highlights) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text('Highlights (${highlights.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      ...highlights.map((h) => _infoTile('Highlight ${h['index']}', '${h['timestamp_sec']}s — score: ${h['score']}', Icons.star_rounded, const Color(0xFFFFD700))),
    ]);
  }

  Widget _buildSuggestionsList(List suggestions) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text('Suggestions (${suggestions.length})', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      const SizedBox(height: 8),
      ...suggestions.map((s) => _infoTile(s['type']?.toString().toUpperCase() ?? 'TIP', s['suggestion'] ?? '', Icons.lightbulb_rounded, const Color(0xFFFF6B6B))),
    ]);
  }

  Widget _infoTile(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(30))),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted), maxLines: 3, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  // ═══════════════════════════════════════════
  //  ACTIONS — Cancel / Re-run / Accept & Save
  // ═══════════════════════════════════════════
  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withAlpha(10)))),
      child: Row(children: [
        // Cancel / Close
        Expanded(child: OutlinedButton.icon(
          icon: const Icon(Icons.close, size: 16),
          label: Text(widget.featureTitle == 'Smart Edit Suggestions' ? 'Close' : 'Cancel', style: GoogleFonts.inter(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textMuted,
            side: BorderSide(color: Colors.white.withAlpha(20)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => Navigator.pop(context),
        )),
        if (widget.featureTitle != 'Smart Edit Suggestions') ...[
          const SizedBox(width: 8),
          // Re-run
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: Text('Re-run', style: GoogleFonts.inter(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentOrange,
              side: const BorderSide(color: AppTheme.accentOrange),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () { Navigator.pop(context); widget.onRerun(); },
          )),
          const SizedBox(width: 8),
        // REAL Accept & Download
        Expanded(child: ElevatedButton.icon(
          icon: _saving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.download_rounded, size: 16),
          label: Text(_saving ? 'Saving...' : 'Accept & Save',
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: _saving ? null : _handleSave,
        )),
        ],
      ]),
    );
  }

  // ═══════════════════════════════════════════
  //  REAL DOWNLOAD — fetches blob and triggers browser download
  // ═══════════════════════════════════════════
  Future<void> _handleSave() async {
    if (_outputUrl == null) {
      _showSnack('No output file to save', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      // Fetch the processed file as bytes
      final response = await http.get(Uri.parse(_outputUrl!));
      if (response.statusCode != 200) {
        throw Exception('Failed to download file (${response.statusCode})');
      }

      final bytes = response.bodyBytes;
      final blob = html.Blob([bytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);

      // Determine filename
      final ext = _outputUrl!.split('.').last;
      final name = '${widget.featureTitle.replaceAll(' ', '_').toLowerCase()}_result.$ext';

      // Trigger browser download
      final anchor = html.AnchorElement(href: blobUrl)
        ..setAttribute('download', name)
        ..click();

      html.Url.revokeObjectUrl(blobUrl);

      if (mounted) {
        Navigator.pop(context);
        _showSnack('✅ File saved: $name');
      }
    } catch (e) {
      _showSnack('Download failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
}
