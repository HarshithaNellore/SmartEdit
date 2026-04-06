import 'dart:io';
import 'package:flutter/foundation.dart'; // Add kIsWeb
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit_config.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_button.dart';
import '../../services/stats_service.dart';
import '../../services/debug_logger.dart'; // Add logger
import '../editor/video_editor_screen.dart';

class ExportScreen extends StatefulWidget {
  final List<VideoClip>? clips;
  final String? audioPath;
  final int audioTrimStartMs;
  final int audioTrimEndMs;
  final List<VideoTextOverlay>? textOverlays;

  const ExportScreen({
    super.key,
    this.clips,
    this.audioPath,
    this.audioTrimStartMs = 0,
    this.audioTrimEndMs = 0,
    this.textOverlays,
  });

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  int _selectedQuality = 1;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  String? _exportError;

  final _qualities = ['720p', '1080p', '4K'];
  final _formats = ['MP4', 'MOV', 'WebM'];
  int _selectedFormat = 0;
  double _fps = 30;

  void _startExport() async {
    if (kIsWeb) {
      _showErrorDialog(
          'Video export is currently only supported on the SmartCut mobile and desktop apps. Web export is coming soon!');
      return;
    }

    if (widget.clips == null || widget.clips!.isEmpty) {
      _showErrorDialog('No video clips found to export.');
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _exportError = null;
    });

    try {
      // ─── Get Output Path (Safe for Windows) ───
      Directory? appDir;
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        appDir = await getDownloadsDirectory();
      } else {
        appDir = await getApplicationDocumentsDirectory();
      }
      appDir ??= await getTemporaryDirectory();
      
      final formats = ['mp4', 'mov', 'webm'];
      final ext = formats[_selectedFormat];
      final outputPath = '${appDir.path}/smartcut_export_${DateTime.now().millisecondsSinceEpoch}.$ext';
      
      // Determine user-selected target resolution
      final targetHeights = [720, 1080, 2160];
      final targetWidths = [1280, 1920, 3840];
      final targetH = targetHeights[_selectedQuality];
      final targetW = targetWidths[_selectedQuality];
      
      DebugLogger.log('EXPORT', 'Starting export to $outputPath | Res: ${targetW}x$targetH | FPS: $_fps');

      List<String> inputs = [];
      String filterComplex = '';
      
      // Calculate total expected duration for real progress tracking
      double totalDurationSec = 0.0;

      // ─── FFprobe Clips to identify missing audio tracks (Issue 3 Fix) ───
      for (int i = 0; i < widget.clips!.length; i++) {
        final clip = widget.clips![i];
        inputs.add('-i');
        inputs.add(clip.filePath);
        
        bool hasAudio = false;
        double clipDuration = 0.0;
        
        try {
          if (Platform.isWindows) {
             final result = await Process.run('ffprobe', ['-v', 'error', '-show_entries', 'stream=codec_type', '-of', 'default=nw=1:nk=1', clip.filePath], runInShell: true);
             hasAudio = result.stdout.toString().contains('audio');
             final durationResult = await Process.run('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=nw=1:nk=1', clip.filePath], runInShell: true);
             clipDuration = double.tryParse(durationResult.stdout.toString().trim()) ?? 5.0;
          } else {
            final probeSession = await FFprobeKit.getMediaInformation(clip.filePath);
            final info = probeSession.getMediaInformation();
            if (info != null) {
              clipDuration = double.tryParse(info.getDuration() ?? '0') ?? 0.0;
              final streams = info.getStreams();
              hasAudio = streams.any((s) => s.getType() == 'audio');
            }
          }
        } catch (e) {
          DebugLogger.error('EXPORT', 'FFprobe failed on clip $i', error: e);
        }

        if (clipDuration == 0.0) clipDuration = 5.0; // Fallback if probe fails
        totalDurationSec += clipDuration;

        DebugLogger.log('EXPORT', 'Clip $i: hasAudio=$hasAudio, duration=$clipDuration');

        // Scale to common resolution, padding cleanly to maintain aspect ratio
        filterComplex += '[$i:v]scale=$targetW:$targetH:force_original_aspect_ratio=decrease,pad=$targetW:$targetH:(ow-iw)/2:(oh-ih)/2,setsar=1[v$i];';
        
        // Handle audio tracks safely
        if (hasAudio) {
          filterComplex += '[$i:a]volume=${clip.volume}[a$i];';
        } else {
          filterComplex += 'aevalsrc=0:d=$clipDuration[a$i];'; // Generate exactly `d` seconds of silence
        }
      }
      
      // Concatenate all normalized streams
      for (int i = 0; i < widget.clips!.length; i++) {
        filterComplex += '[v$i][a$i]';
      }
      
      // If we have text overlays, we need to apply them to the concatenated video
      // concat -> [rawv][outa]; [rawv] drawtext=... -> [outv]
      bool hasText = widget.textOverlays != null && widget.textOverlays!.isNotEmpty;
      filterComplex += 'concat=n=${widget.clips!.length}:v=1:a=1[${hasText ? "rawv" : "outv"}][outa]';
      
      if (hasText) {
        filterComplex += ';[rawv]';
        for (int i = 0; i < widget.textOverlays!.length; i++) {
          final textO = widget.textOverlays![i];
          // Basic drawtext (note: in production FFmpeg requires a fontfile, but some distros have defaults.
          // Using a simple x,y coordinate mapping without custom font to ensure compatibility).
          final safeText = textO.text.replaceAll(':', '\\:').replaceAll('\'', '\\\'');
          filterComplex += 'drawtext=text=\'$safeText\':fontcolor=white:fontsize=48:x=${textO.offset.dx}:y=${textO.offset.dy}';
          if (i < widget.textOverlays!.length - 1) {
            filterComplex += ',';
          }
        }
        filterComplex += '[outv]';
      }

      List<String> args = [];
      args.addAll(inputs);
      
      // Handle background audio mixing
      bool hasBackgroundAudio = widget.audioPath != null;
      if (hasBackgroundAudio) {
        if (widget.audioTrimEndMs > 0) {
          final startSec = widget.audioTrimStartMs / 1000.0;
          final durationSec = (widget.audioTrimEndMs - widget.audioTrimStartMs) / 1000.0;
          args.add('-ss');
          args.add(startSec.toStringAsFixed(3));
          args.add('-t');
          args.add(durationSec.toStringAsFixed(3));
        }
        args.add('-i');
        args.add(widget.audioPath!);
        // Mix background audio with concat output audio
        filterComplex += ';[outa][${widget.clips!.length}:a]amix=inputs=2:duration=first[finala]';
      }

      args.add('-filter_complex');
      args.add(filterComplex);
      args.add('-map');
      args.add('[outv]');
      args.add('-map');
      args.add(hasBackgroundAudio ? '[finala]' : '[outa]');
      
      // ─── Encoding settings derived from UI ───
      args.add('-c:v'); 
      args.add(_formats[_selectedFormat] == 'WebM' ? 'libvpx-vp9' : 'libx264');
      args.add('-preset'); 
      args.add('ultrafast'); // fast encode for mobile
      args.add('-crf'); 
      args.add('28'); // constant rate factor for balanced quality/size
      args.add('-r');
      args.add(_fps.toInt().toString());
      args.add('-c:a'); 
      args.add('aac');
      args.add('-b:a'); 
      args.add('128k');
      args.add('-y');
      args.add(outputPath);

      final command = args.map((e) => '"$e"').join(' ');
      DebugLogger.log('EXPORT', 'Executing FFmpeg command...');

      if (Platform.isWindows) {
        // Native process execution for Windows
        try {
          final process = await Process.start('ffmpeg', args, runInShell: true);
          
          process.stderr.transform(SystemEncoding().decoder).listen((data) {
             if (mounted && _isExporting) {
                setState(() {
                  _exportProgress = (_exportProgress + 0.05).clamp(0.0, 0.95);
                });
             }
          });

          final exitCode = await process.exitCode;
          if (exitCode == 0) {
            DebugLogger.log('EXPORT', '✅ Export successful! Saved to $outputPath');
            if (mounted) {
              setState(() {
                _exportProgress = 1.0;
                _isExporting = false;
              });
              await StatsService.incrementExportCount();
              _showExportCompleteDialog(outputPath);
            }
          } else {
             throw Exception('FFmpeg process exited with code $exitCode');
          }
        } catch (e) {
           throw Exception('Failed to run FFmpeg on Windows. Is it installed in your PATH? Error: $e');
        }
      } else {
        // ─── Real Progress Tracking (Mobile) ───
        FFmpegKitConfig.enableStatisticsCallback((stats) {
          if (totalDurationSec > 0) {
            final timeInMs = stats.getTime();
            if (timeInMs > 0) {
              final double percentage = (timeInMs / 1000.0) / totalDurationSec;
              if (mounted && _isExporting) {
                setState(() {
                  _exportProgress = percentage.clamp(0.0, 0.99);
                });
              }
            }
          }
        });

        await FFmpegKit.execute(command).then((session) async {
          FFmpegKitConfig.enableStatisticsCallback(null);
          final returnCode = await session.getReturnCode();
          final logs = await session.getLogsAsString();

          if (ReturnCode.isSuccess(returnCode)) {
            DebugLogger.log('EXPORT', '✅ Export successful! Saved to $outputPath');
            if (mounted) {
              setState(() {
                _exportProgress = 1.0;
                _isExporting = false;
              });
              await StatsService.incrementExportCount();
              _showExportCompleteDialog(outputPath);
            }
          } else {
            DebugLogger.error('EXPORT', 'FFmpeg failed with code $returnCode.\nLogs: $logs');
            if (mounted) {
              setState(() {
                _isExporting = false;
              });
              _showErrorDialog('Export failed during encoding. Please check your video format.');
            }
          }
        });
      }
    } catch (e, stack) {
      FFmpegKitConfig.enableStatisticsCallback(null);
      DebugLogger.error('EXPORT', 'Technical error during export', error: e, stack: stack);
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportError = e.toString();
        });
        _showErrorDialog('Technical error: ${_exportError ?? 'Unknown'}');
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text('Export Error', style: GoogleFonts.outfit(color: Colors.redAccent)),
        content: Text(message, style: GoogleFonts.inter(color: AppTheme.textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  void _showExportCompleteDialog(String filePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppTheme.accentCyan, size: 40),
              ),
              const SizedBox(height: 20),
              Text('Export Complete!', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Your video is ready.', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await StatsService.incrementShareCount();
                        await Share.shareXFiles([XFile(filePath)], text: 'Check out my video made with SmartCut! 🎬');
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: Text('Share', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryPurple,
                        side: const BorderSide(color: AppTheme.primaryPurple),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      text: 'Done',
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
                      if (_isExporting) _buildExportProgress() else ...[
                        const SizedBox(height: 24),
                        _buildQualitySection(),
                        const SizedBox(height: 24),
                        _buildFormatSection(),
                        const SizedBox(height: 24),
                        _buildFPSSection(),
                        const SizedBox(height: 24),
                        _buildSummary(),
                        const SizedBox(height: 32),
                        _buildExportButton(),
                      ],
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
            Expanded(child: Text('Export', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
          ],
        ),
      ),
    );
  }

  Widget _buildExportProgress() {
    return FadeIn(
      duration: const Duration(milliseconds: 400),
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(height: 40),
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: _exportProgress,
                    strokeWidth: 8,
                    backgroundColor: AppTheme.darkElevated,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                  ),
                  Center(
                    child: Text(
                      '${(_exportProgress * 100).toInt()}%',
                      style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Exporting...', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('Please wait while your project is being exported', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _exportInfoRow('Format', _formats[_selectedFormat]),
                  const SizedBox(height: 8),
                  _exportInfoRow('Quality', _qualities[_selectedQuality]),
                  const SizedBox(height: 8),
                  _exportInfoRow('FPS', '${_fps.toInt()}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    );
  }

  // Platform Presets were removed by User Request

  Widget _buildQualitySection() {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: const Duration(milliseconds: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quality', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: _qualities.asMap().entries.map((e) {
              final isSelected = _selectedQuality == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedQuality = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryPurple.withAlpha(30) : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppTheme.primaryPurple : Colors.white.withAlpha(15)),
                    ),
                    child: Center(
                      child: Text(e.value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.primaryPurple : AppTheme.textMuted)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSection() {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Format', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: _formats.asMap().entries.map((e) {
              final isSelected = _selectedFormat == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedFormat = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentCyan.withAlpha(30) : Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppTheme.accentCyan : Colors.white.withAlpha(15)),
                    ),
                    child: Center(
                      child: Text(e.value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFPSSection() {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Frame Rate', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text('${_fps.toInt()} FPS', style: GoogleFonts.jetBrainsMono(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _fps,
            min: 24,
            max: 60,
            divisions: 3,
            onChanged: (v) => setState(() => _fps = v),
            activeColor: AppTheme.primaryPurple,
            inactiveColor: AppTheme.darkElevated,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('24', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              Text('30', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              Text('48', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
              Text('60', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: const Duration(milliseconds: 400),
      child: GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Summary', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 14),
            _summaryRow('Resolution', _selectedQuality == 0 ? "720p" : _selectedQuality == 1 ? "1080p" : "4K"),
            _summaryRow('Format', _formats[_selectedFormat]),
            _summaryRow('Quality', _qualities[_selectedQuality]),
            _summaryRow('Frame Rate', '${_fps.toInt()} FPS'),
            _summaryRow('Est. Size', '~${_selectedQuality == 2 ? "250" : _selectedQuality == 1 ? "80" : "35"} MB'),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted)),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      delay: const Duration(milliseconds: 500),
      child: SizedBox(
        width: double.infinity,
        child: GradientButton(
          text: 'Export Now',
          icon: Icons.file_download_rounded,
          onPressed: _startExport,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
    );
  }
}
