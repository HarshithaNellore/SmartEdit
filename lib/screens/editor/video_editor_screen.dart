import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import '../../theme/app_theme.dart';

class VideoEditorScreen extends StatefulWidget {
  const VideoEditorScreen({super.key});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen>
    with TickerProviderStateMixin {
  // ── Core state ──
  final ImagePicker _picker = ImagePicker();
  final List<VideoClip> _videoClips = [];
  int? _selectedClipIndex;
  VideoPlayerController? _controller;
  VideoPlayerController? _audioController;
  bool _isLoading = false;
  String? _errorMessage;

  // ── Playback tracking ──
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  Duration get _globalDuration {
    int totalMs = 0;
    for (var clip in _videoClips) {
      if (clip.duration.inMilliseconds > 0) {
        totalMs += (clip.duration.inMilliseconds * (clip.trimEndFraction - clip.trimStartFraction) / clip.speed).round();
      }
    }
    return Duration(milliseconds: totalMs);
  }

  Duration get _globalPosition {
    if (_selectedClipIndex == null) return Duration.zero;
    
    int msBefore = 0;
    for (int i = 0; i < _selectedClipIndex!; i++) {
      final c = _videoClips[i];
      if (c.duration.inMilliseconds > 0) {
        msBefore += (c.duration.inMilliseconds * (c.trimEndFraction - c.trimStartFraction) / c.speed).round();
      }
    }
    
    int currentActiveMs = 0;
    if (_controller != null && _controller!.value.isInitialized && _duration.inMilliseconds > 0) {
      final c = _videoClips[_selectedClipIndex!];
      final currentPosMs = _position.inMilliseconds;
      final startMs = (c.trimStartFraction * c.duration.inMilliseconds).round();
      final endMs = (c.trimEndFraction * c.duration.inMilliseconds).round();
      
      final elapsedMs = currentPosMs.clamp(startMs, endMs) - startMs;
      if (elapsedMs > 0) {
        currentActiveMs = (elapsedMs / c.speed).round();
      }
    }
    
    return Duration(milliseconds: msBefore + currentActiveMs);
  }

  void _seekGlobal(Duration pos) {
    if (_videoClips.isEmpty) return;
    
    int targetMs = pos.inMilliseconds;
    int accumulatedMs = 0;
    
    for (int i = 0; i < _videoClips.length; i++) {
      final c = _videoClips[i];
      if (c.duration.inMilliseconds == 0) continue;
      
      int clipActiveMs = (c.duration.inMilliseconds * (c.trimEndFraction - c.trimStartFraction) / c.speed).round();
      
      if (targetMs <= accumulatedMs + clipActiveMs || i == _videoClips.length - 1) {
        if (_selectedClipIndex != i) {
          setState(() => _selectedClipIndex = i);
          _loadVideoForClip(i).then((_) {
            final localElapsedMs = ((targetMs - accumulatedMs) * c.speed).round();
            final localTargetMs = (c.trimStartFraction * c.duration.inMilliseconds).round() + localElapsedMs;
            _controller?.seekTo(Duration(milliseconds: localTargetMs));
            if (_audioDuration.inMilliseconds > 0) {
              _audioController?.seekTo(Duration(milliseconds: pos.inMilliseconds + (_audioTrimStart * _audioDuration.inMilliseconds).round()));
            } else {
              _audioController?.seekTo(pos);
            }
          });
          return;
        } else {
          final localElapsedMs = ((targetMs - accumulatedMs) * c.speed).round();
          final localTargetMs = (c.trimStartFraction * c.duration.inMilliseconds).round() + localElapsedMs;
          _seekTo(Duration(milliseconds: localTargetMs));
          if (_audioDuration.inMilliseconds > 0) {
            _audioController?.seekTo(Duration(milliseconds: pos.inMilliseconds + (_audioTrimStart * _audioDuration.inMilliseconds).round()));
          } else {
            _audioController?.seekTo(pos);
          }
          return;
        }
      }
      accumulatedMs += clipActiveMs;
    }
  }

  // ── Text overlays for selected clip ──
  final List<TextOverlay> _textOverlays = [];

  // ── Background audio ──
  String? _backgroundAudioPath;
  double _audioTrimStart = 0.0;
  double _audioTrimEnd = 1.0;
  Duration _audioDuration = Duration.zero;

  // ── Active tool panel ──
  String? _activePanel; // 'trim', 'text', 'filters', 'speed', 'volume', 'brightness'

  // ── Trim state ──
  double _trimStart = 0.0;
  double _trimEnd = 1.0;

  // ── Animations ──
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // ── Filter definitions ──
  static const List<String> _filterNames = [
    'Original', 'Vivid', 'Warm', 'Cool', 'B&W',
    'Vintage', 'Cinematic', 'Dreamy', 'Neon',
  ];

  static final List<ColorFilter?> _filters = [
    null,
    ColorFilter.mode(Colors.pinkAccent.withAlpha(60), BlendMode.colorBurn),
    ColorFilter.mode(Colors.orange.withAlpha(60), BlendMode.colorBurn),
    ColorFilter.mode(Colors.blue.withAlpha(60), BlendMode.colorBurn),
    const ColorFilter.mode(Colors.grey, BlendMode.saturation),
    ColorFilter.mode(Colors.brown.withAlpha(60), BlendMode.colorBurn),
    ColorFilter.mode(Colors.teal.withAlpha(60), BlendMode.colorBurn),
    ColorFilter.mode(Colors.purple.withAlpha(60), BlendMode.hardLight),
    ColorFilter.mode(Colors.greenAccent.withAlpha(60), BlendMode.colorBurn),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  bool _initializedWithArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedWithArgs) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('initialVideoPath')) {
        _initializedWithArgs = true;
        final path = args['initialVideoPath'] as String;
        final name = args['initialVideoName'] as String;
        
        // Add the initial clip
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _addInitialClip(path, name);
        });
      }
    }
  }

  Future<void> _addInitialClip(String path, String name) async {
    final clip = VideoClip(
      fileName: name,
      filePath: path,
    );
    setState(() {
      _videoClips.add(clip);
      _selectedClipIndex = _videoClips.length - 1;
    });
    await _loadVideoForClip(_videoClips.length - 1);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _audioController?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  VIDEO LIFECYCLE — THE CRITICAL FIX
  // ═══════════════════════════════════════════════════════

  void _onVideoUpdate() {
    if (!mounted || _controller == null) return;
    final ctrl = _controller!;
    final newPos = ctrl.value.position;
    final newPlaying = ctrl.value.isPlaying;

    if (_audioDuration.inMilliseconds > 0 && _audioController != null && _audioController!.value.isPlaying) {
      final audioEndMs = (_audioTrimEnd * _audioDuration.inMilliseconds).round();
      if (_audioController!.value.position.inMilliseconds >= audioEndMs - 50) {
        _audioController!.pause();
      }
    }

    if (_duration.inMilliseconds > 0) {
      final endMs = (_trimEnd * _duration.inMilliseconds).round();
      final startMs = (_trimStart * _duration.inMilliseconds).round();
      
      // Enforce trim boundaries during playback
      if (newPlaying && newPos.inMilliseconds >= endMs - 50) {
        ctrl.pause();
        
        if (_selectedClipIndex != null && _selectedClipIndex! < _videoClips.length - 1) {
          final nextIndex = _selectedClipIndex! + 1;
          setState(() => _selectedClipIndex = nextIndex);
          _loadVideoForClip(nextIndex);
        } else {
          ctrl.seekTo(Duration(milliseconds: startMs));
          _audioController?.pause();
          if (_audioDuration.inMilliseconds > 0) {
            _audioController?.seekTo(Duration(milliseconds: (_audioTrimStart * _audioDuration.inMilliseconds).round()));
          } else {
            _audioController?.seekTo(Duration.zero);
          }
          setState(() {
            _isPlaying = false;
            _position = Duration(milliseconds: startMs);
          });
        }
        return;
      }
    }

    if (newPos != _position || newPlaying != _isPlaying) {
      setState(() {
        _position = newPos;
        _isPlaying = newPlaying;
      });
    }
  }

  Future<void> _pickAndAddVideo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      for (var file in result.files) {
        if (file.path == null) continue;
        final clip = VideoClip(
          fileName: file.name,
          filePath: file.path!,
        );
        _videoClips.add(clip);
      }

      setState(() {
        _selectedClipIndex = _videoClips.length - 1;
      });

      await _loadVideoForClip(_videoClips.length - 1);
    } catch (e) {
      _showError('Failed to pick video: $e');
    }
  }

  Future<void> _loadVideoForClip(int index) async {
    if (index < 0 || index >= _videoClips.length) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Dispose old controller
    _controller?.removeListener(_onVideoUpdate);
    await _controller?.dispose();
    _controller = null;

    try {
      final clip = _videoClips[index];
      VideoPlayerController newController;

      if (kIsWeb) {
        newController = VideoPlayerController.networkUrl(Uri.parse(clip.filePath));
      } else {
        final file = File(clip.filePath);
        if (!await file.exists()) {
          throw Exception('File not found: ${clip.filePath}');
        }
        newController = VideoPlayerController.file(file);
      }

      // Initialize with timeout
      await newController.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Video took too long to load');
        },
      );

      if (!mounted) {
        newController.dispose();
        return;
      }

      // Apply clip settings
      newController.setVolume(clip.volume);
      newController.setPlaybackSpeed(clip.speed);

      // Add listener BEFORE setting state
      newController.addListener(_onVideoUpdate);

      setState(() {
        _controller = newController;
        _duration = newController.value.duration;
        clip.duration = _duration;
        _position = Duration.zero;
        _isPlaying = false;
        _isLoading = false;
        _trimStart = clip.trimStartFraction;
        _trimEnd = clip.trimEndFraction;
      });

      // Seek to trim start and auto-play
      final startPos = Duration(
        milliseconds: (_trimStart * _duration.inMilliseconds).round(),
      );
      await newController.seekTo(startPos);
      await newController.play();
      if (_audioDuration.inMilliseconds > 0) {
        _audioController?.seekTo(Duration(milliseconds: _globalPosition.inMilliseconds + (_audioTrimStart * _audioDuration.inMilliseconds).round()));
      } else {
        _audioController?.seekTo(_globalPosition);
      }
      _audioController?.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _friendlyError(e);
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout')) return 'Video took too long to load. Try a smaller file.';
    if (msg.contains('not found')) return 'Video file was not found.';
    if (msg.contains('format') || msg.contains('codec')) {
      return 'Unsupported video format. Try MP4 or MOV.';
    }
    return 'Failed to load video. Please try another file.';
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _backgroundAudioPath = result.files.single.path;
          _isLoading = true;
        });
        
        _audioController?.dispose();
        _audioController = VideoPlayerController.file(File(_backgroundAudioPath!));
        await _audioController!.initialize();
        setState(() {
          _audioDuration = _audioController!.value.duration;
          _audioTrimStart = 0.0;
          _audioTrimEnd = 1.0;
        });
        if (_isPlaying) {
          _audioController!.play();
        }
        
        setState(() {
          _isLoading = false;
        });
        _showFeedback('Audio track added');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to pick audio: $e');
    }
  }

  // ═══════════════════════════════════════════════════════
  //  PLAYBACK CONTROLS
  // ═══════════════════════════════════════════════════════

  void _togglePlayPause() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _audioController?.pause();
    } else {
      _controller!.play();
      _audioController?.play();
    }
  }

  void _seekTo(Duration pos) {
    _controller?.seekTo(pos);
  }

  void _replay() {
    if (_videoClips.isEmpty) return;
    if (_selectedClipIndex != 0) {
      setState(() => _selectedClipIndex = 0);
      _loadVideoForClip(0);
    } else if (_controller != null) {
      final startMs = (_trimStart * _duration.inMilliseconds).round();
      _controller!.seekTo(Duration(milliseconds: startMs));
      if (_audioDuration.inMilliseconds > 0) {
        _audioController?.seekTo(Duration(milliseconds: (_audioTrimStart * _audioDuration.inMilliseconds).round()));
      } else {
        _audioController?.seekTo(Duration.zero);
      }
      _controller!.play();
      _audioController?.play();
    }
  }

  // ═══════════════════════════════════════════════════════
  //  CLIP MANAGEMENT
  // ═══════════════════════════════════════════════════════

  void _removeClip(int index) {
    setState(() {
      _videoClips.removeAt(index);
      if (_videoClips.isEmpty) {
        _selectedClipIndex = null;
        _controller?.removeListener(_onVideoUpdate);
        _controller?.dispose();
        _controller = null;
        _activePanel = null;
      } else if (_selectedClipIndex == index) {
        _selectedClipIndex = 0;
        _loadVideoForClip(0);
      } else if (_selectedClipIndex != null && _selectedClipIndex! > index) {
        _selectedClipIndex = _selectedClipIndex! - 1;
      }
    });
  }

  void _duplicateClip(int index) {
    setState(() {
      _videoClips.insert(index + 1, VideoClip.copy(_videoClips[index]));
    });
  }

  void _splitClipAtPosition() {
    if (_selectedClipIndex == null || _controller == null) {
      _showFeedback('Select a clip and play to a split point');
      return;
    }
    final clip = _videoClips[_selectedClipIndex!];
    final totalMs = _duration.inMilliseconds;
    if (totalMs == 0) return;

    final splitFrac = _position.inMilliseconds / totalMs;
    // Must playhead be strictly within the trim boundaries to split
    if (splitFrac <= clip.trimStartFraction + 0.01 ||
        splitFrac >= clip.trimEndFraction - 0.01) {
      _showFeedback('Playhead must be inside the active clip to split');
      return;
    }

    final clip1 = VideoClip.copy(clip)..trimEndFraction = splitFrac;
    final clip2 = VideoClip.copy(clip)..trimStartFraction = splitFrac;

    setState(() {
      _videoClips[_selectedClipIndex!] = clip1;
      _videoClips.insert(_selectedClipIndex! + 1, clip2);
    });
    _showFeedback('Clip split into two parts');
  }

  void _reorderClip(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final clip = _videoClips.removeAt(oldIndex);
      _videoClips.insert(newIndex, clip);
      if (_selectedClipIndex == oldIndex) {
        _selectedClipIndex = newIndex;
      }
    });
  }

  // ═══════════════════════════════════════════════════════
  //  TEXT OVERLAY MANAGEMENT
  // ═══════════════════════════════════════════════════════

  void _addTextOverlay() {
    final controller = TextEditingController(text: 'Your Text');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add Text Overlay',
            style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: AppTheme.textPrimary),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter text...',
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.darkElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _textOverlays.add(TextOverlay(
                    text: controller.text.trim(),
                    offset: const Offset(100, 100), // Raw pixels instead of fraction
                    fontSize: 24,
                    color: Colors.white,
                  ));
                });
              }
              Navigator.pop(ctx);
            },
            child: Text('Add',
                style: GoogleFonts.inter(
                    color: AppTheme.primaryPurple, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _removeTextOverlay(int index) {
    setState(() => _textOverlays.removeAt(index));
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(children: [
              _buildTopBar(),
              Expanded(child: _buildPreviewArea()),
              if (_activePanel != null) _buildActivePanel(),
              _buildTimeline(),
              _buildToolbar(),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Top App Bar ──
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _iconButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Video Editor',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text('${_videoClips.length} clip${_videoClips.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
          ]),
        ),
        if (_videoClips.isNotEmpty)
          GestureDetector(
            onTap: () => Navigator.pushNamed(
              context, 
              '/export',
              arguments: {
                'clips': _videoClips.map((c) => VideoClip.copy(c)).toList(),
                'audioPath': _backgroundAudioPath,
                'audioTrimStartMs': (_audioTrimStart * _audioDuration.inMilliseconds).round(),
                'audioTrimEndMs': (_audioTrimEnd * _audioDuration.inMilliseconds).round(),
              },
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Export',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
      ]),
    );
  }

  // ── Preview Area ──
  Widget _buildPreviewArea() {
    // Empty state
    if (_videoClips.isEmpty) {
      return _buildEmptyPreview();
    }

    // Loading state
    if (_isLoading) {
      return _buildLoadingPreview();
    }

    // Error state
    if (_errorMessage != null) {
      return _buildErrorPreview();
    }

    // No controller yet
    if (_controller == null || !_controller!.value.isInitialized) {
      return _buildErrorPreview();
    }

    return _buildVideoPreview();
  }

  Widget _buildEmptyPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.videocam_rounded, size: 64, color: Colors.white.withAlpha(50)),
          const SizedBox(height: 12),
          Text('Add video clips to start editing',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withAlpha(120))),
          const SizedBox(height: 16),
          _gradientChip(Icons.video_call, 'Add Video', _pickAndAddVideo),
        ]),
      ),
    );
  }

  Widget _buildLoadingPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
            ),
          ),
          const SizedBox(height: 16),
          Text('Loading video...',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withAlpha(120))),
          const SizedBox(height: 8),
          Text('This may take a moment for large files',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withAlpha(60))),
        ]),
      ),
    );
  }

  Widget _buildErrorPreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withAlpha(40)),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withAlpha(180)),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Failed to load video',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withAlpha(180)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _gradientChip(Icons.refresh, 'Retry', () {
                if (_selectedClipIndex != null) {
                  _loadVideoForClip(_selectedClipIndex!);
                }
              }),
              const SizedBox(width: 12),
              _gradientChip(Icons.video_call, 'Pick New', _pickAndAddVideo),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    final clip = _selectedClipIndex != null ? _videoClips[_selectedClipIndex!] : null;
    final filterIndex = clip?.filterIndex ?? 0;
    final brightness = clip?.brightness ?? 0.0;
    final contrast = clip?.contrast ?? 1.0;

    // Build video player with physical overlays for Web compatibility
    Widget videoWidget = AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(_controller!),
          
          // Brightness overlays works 100% on HTML view
          if (brightness > 0)
            Container(color: Colors.white.withOpacity(brightness)),
          if (brightness < 0)
            Container(color: Colors.black.withOpacity(-brightness)),
            
          // Contrast overlay simulation
          if (contrast < 1.0)
            Container(color: Colors.grey.withOpacity(1.0 - contrast)),
          if (contrast > 1.0)
            Container(color: Colors.transparent), // High contrast requires active shader
        ],
      ),
    );

    // Apply filter using supported ColorFilter.mode instead of unsupported .matrix
    if (_filters[filterIndex] != null) {
      videoWidget = ColorFiltered(
        colorFilter: _filters[filterIndex]!,
        child: videoWidget,
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(fit: StackFit.expand, children: [
          // Video with filters
          Center(child: videoWidget),

          // Text overlays
          ..._textOverlays.asMap().entries.map((entry) {
            final overlay = entry.value;
            return Positioned(
              left: overlay.offset.dx,
              top: overlay.offset.dy,
              child: GestureDetector(
                onLongPress: () => _removeTextOverlay(entry.key),
                onPanUpdate: (details) {
                  setState(() {
                    overlay.offset = Offset(
                      overlay.offset.dx + details.delta.dx,
                      overlay.offset.dy + details.delta.dy,
                    );
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    overlay.text,
                    style: GoogleFonts.inter(
                      fontSize: overlay.fontSize,
                      color: overlay.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),

          // Playback controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87],
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Progress bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppTheme.primaryPurple,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppTheme.primaryPurple,
                    overlayColor: AppTheme.primaryPurple.withAlpha(40),
                  ),
                  child: Slider(
                    value: _globalDuration.inMilliseconds > 0
                        ? _globalPosition.inMilliseconds.clamp(0, _globalDuration.inMilliseconds).toDouble()
                        : 0,
                    min: 0,
                    max: _globalDuration.inMilliseconds > 0
                        ? _globalDuration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: (val) {
                      _seekGlobal(Duration(milliseconds: val.round()));
                    },
                  ),
                ),
                // Controls row
                Row(children: [
                  _controlButton(
                    Icons.replay_rounded,
                    _replay,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  _controlButton(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    _togglePlayPause,
                    isPrimary: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_formatDuration(_globalPosition)} / ${_formatDuration(_globalDuration)}',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ),
                  // Speed indicator
                  if (clip != null && clip.speed != 1.0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${clip.speed.toStringAsFixed(1)}x',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppTheme.accentCyan, fontWeight: FontWeight.w600)),
                    ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Active Tool Panel ──
  Widget _buildActivePanel() {
    switch (_activePanel) {
      case 'trim':
        return _buildTrimPanel();
      case 'text':
        return _buildTextPanel();
      case 'filters':
        return _buildFilterPanel();
      case 'speed':
        return _buildSpeedPanel();
      case 'volume':
        return _buildVolumePanel();
      case 'brightness':
        return _buildBrightnessPanel();
      case 'audio_trim':
        return _buildAudioTrimPanel();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAudioTrimPanel() {
    if (_backgroundAudioPath == null) {
      return _panelWrap('Audio Trim', 'No background audio', const SizedBox.shrink());
    }
    return _panelWrap(
      'Trim Audio',
      'Set start and end points for the audio track',
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text('Start: ${_formatDuration(Duration(milliseconds: (_audioTrimStart * _audioDuration.inMilliseconds).round()))}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
          const Spacer(),
          Text('End: ${_formatDuration(Duration(milliseconds: (_audioTrimEnd * _audioDuration.inMilliseconds).round()))}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        const SizedBox(height: 4),
        RangeSlider(
          values: RangeValues(_audioTrimStart, _audioTrimEnd),
          min: 0,
          max: 1,
          activeColor: AppTheme.primaryPurple,
          inactiveColor: AppTheme.darkElevated,
          onChanged: (values) {
            setState(() {
              _audioTrimStart = values.start;
              _audioTrimEnd = values.end;
            });
          },
          onChangeEnd: (values) {
            final startMs = (values.start * _audioDuration.inMilliseconds).round();
            _audioController?.seekTo(Duration(milliseconds: startMs));
          },
        ),
      ]),
    );
  }

  Widget _buildTrimPanel() {
    if (_selectedClipIndex == null || _controller == null) {
      return _panelWrap('Trim', 'Select a clip first', const SizedBox.shrink());
    }
    final clip = _videoClips[_selectedClipIndex!];
    return _panelWrap(
      'Trim Clip',
      'Set start and end points',
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text('Start: ${_formatDuration(Duration(milliseconds: (_trimStart * _duration.inMilliseconds).round()))}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
          const Spacer(),
          Text('End: ${_formatDuration(Duration(milliseconds: (_trimEnd * _duration.inMilliseconds).round()))}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
        ]),
        const SizedBox(height: 4),
        RangeSlider(
          values: RangeValues(_trimStart, _trimEnd),
          min: 0,
          max: 1,
          activeColor: AppTheme.primaryPurple,
          inactiveColor: AppTheme.darkElevated,
          onChanged: (values) {
            setState(() {
              _trimStart = values.start;
              _trimEnd = values.end;
            });
          },
          onChangeEnd: (values) {
            clip.trimStartFraction = values.start;
            clip.trimEndFraction = values.end;
            // Seek to new start
            final startMs = (values.start * _duration.inMilliseconds).round();
            _controller?.seekTo(Duration(milliseconds: startMs));
          },
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _smallButton('Set Start to Here', () {
            if (_duration.inMilliseconds > 0) {
              final frac = _position.inMilliseconds / _duration.inMilliseconds;
              if (frac < _trimEnd - 0.05) {
                setState(() => _trimStart = frac);
                clip.trimStartFraction = frac;
              }
            }
          }),
          _smallButton('Set End to Here', () {
            if (_duration.inMilliseconds > 0) {
              final frac = _position.inMilliseconds / _duration.inMilliseconds;
              if (frac > _trimStart + 0.05) {
                setState(() => _trimEnd = frac);
                clip.trimEndFraction = frac;
              }
            }
          }),
        ]),
      ]),
    );
  }

  Widget _buildTextPanel() {
    return _panelWrap(
      'Text Overlays',
      '${_textOverlays.length} overlays',
      Column(mainAxisSize: MainAxisSize.min, children: [
        if (_textOverlays.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No text overlays yet',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted)),
          )
        else
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _textOverlays.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_textOverlays[i].text,
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textPrimary)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _removeTextOverlay(i),
                    child: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                  ),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 8),
        _smallButton('+ Add Text', _addTextOverlay),
      ]),
    );
  }

  Widget _buildFilterPanel() {
    if (_selectedClipIndex == null) {
      return _panelWrap('Filters', 'Select a clip first', const SizedBox.shrink());
    }
    final clip = _videoClips[_selectedClipIndex!];
    return _panelWrap(
      'Filters',
      _filterNames[clip.filterIndex],
      SizedBox(
        height: 70,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _filterNames.length,
          itemBuilder: (_, i) {
            final isSelected = clip.filterIndex == i;
            return GestureDetector(
              onTap: () => setState(() => clip.filterIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 60,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryPurple.withAlpha(30)
                      : AppTheme.darkElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryPurple : Colors.white.withAlpha(15),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.filter,
                      size: 20,
                      color: isSelected ? AppTheme.primaryPurple : AppTheme.textMuted),
                  const SizedBox(height: 4),
                  Text(_filterNames[i],
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        color: isSelected ? AppTheme.primaryPurple : AppTheme.textMuted,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSpeedPanel() {
    if (_selectedClipIndex == null) {
      return _panelWrap('Speed', 'Select a clip first', const SizedBox.shrink());
    }
    final clip = _videoClips[_selectedClipIndex!];
    return _panelWrap(
      'Playback Speed',
      '${clip.speed.toStringAsFixed(1)}x',
      Column(mainAxisSize: MainAxisSize.min, children: [
        Slider(
          value: clip.speed,
          min: 0.25,
          max: 3.0,
          divisions: 11,
          activeColor: AppTheme.primaryPurple,
          inactiveColor: AppTheme.darkElevated,
          onChanged: (v) {
            setState(() => clip.speed = v);
            _controller?.setPlaybackSpeed(v);
          },
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('0.25x', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
          Text('1x', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
          Text('2x', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
          Text('3x', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted)),
        ]),
      ]),
    );
  }

  Widget _buildVolumePanel() {
    if (_selectedClipIndex == null) {
      return _panelWrap('Volume', 'Select a clip first', const SizedBox.shrink());
    }
    final clip = _videoClips[_selectedClipIndex!];
    return _panelWrap(
      'Volume',
      '${(clip.volume * 100).toStringAsFixed(0)}%',
      Slider(
        value: clip.volume,
        min: 0.0,
        max: 1.0,
        activeColor: AppTheme.primaryPurple,
        inactiveColor: AppTheme.darkElevated,
        onChanged: (v) {
          setState(() => clip.volume = v);
          _controller?.setVolume(v);
        },
      ),
    );
  }

  Widget _buildBrightnessPanel() {
    if (_selectedClipIndex == null) {
      return _panelWrap('Brightness', 'Select a clip first', const SizedBox.shrink());
    }
    final clip = _videoClips[_selectedClipIndex!];
    return _panelWrap(
      'Brightness & Contrast',
      '',
      Column(mainAxisSize: MainAxisSize.min, children: [
        _labeledSlider('Brightness', clip.brightness, -0.5, 0.5, (v) {
          setState(() => clip.brightness = v);
        }),
        _labeledSlider('Contrast', clip.contrast, 0.5, 2.0, (v) {
          setState(() => clip.contrast = v);
        }),
      ]),
    );
  }

  Widget _panelWrap(String title, String subtitle, Widget child) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(top: BorderSide(color: Colors.white.withAlpha(10))),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(width: 8),
          Text(subtitle,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _activePanel = null),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Widget _buildAudioTrack() {
    final fileName = _backgroundAudioPath!.split(RegExp(r'[/\\]')).last;
    return GestureDetector(
      onTap: () => _openPanel('audio_trim'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _activePanel == 'audio_trim' ? AppTheme.primaryPurple.withAlpha(40) : AppTheme.primaryPurple.withAlpha(20),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryPurple.withAlpha(50), width: _activePanel == 'audio_trim' ? 2 : 1),
        ),
        child: Row(
        children: [
          const Icon(Icons.music_note_rounded, color: AppTheme.primaryPurple, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fileName,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _backgroundAudioPath = null;
                _audioController?.dispose();
                _audioController = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Timeline ──
  Widget _buildTimeline() {
    return Container(
      height: _backgroundAudioPath != null ? 145 : 120,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withAlpha(8)),
        ),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Icon(Icons.timeline_rounded, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            Text('Timeline',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const Spacer(),
            _miniButton(Icons.add, 'Add', _pickAndAddVideo),
            const SizedBox(width: 8),
            _miniButton(Icons.content_cut, 'Split', _splitClipAtPosition),
          ]),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 2,
          child: _videoClips.isEmpty
              ? Center(
                  child: Text('Tap + to add video clips',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
                )
              : ReorderableListView(
                  scrollDirection: Axis.horizontal,
                  onReorder: _reorderClip,
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 8,
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: child,
                    );
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (int i = 0; i < _videoClips.length; i++)
                      _buildTimelineClip(i),
                  ],
                ),
        ),
        if (_backgroundAudioPath != null) _buildAudioTrack(),
      ]),
    );
  }

  Widget _buildTimelineClip(int index) {
    final clip = _videoClips[index];
    final isSelected = _selectedClipIndex == index;

    // Show playback position indicator for the selected clip
    double? playbackFrac;
    if (isSelected && _duration.inMilliseconds > 0) {
      playbackFrac = _position.inMilliseconds / _duration.inMilliseconds;
    }

    return GestureDetector(
      key: ValueKey('clip_$index'),
      onTap: () {
        setState(() => _selectedClipIndex = index);
        _loadVideoForClip(index);
      },
      onLongPress: () => _showClipOptions(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withAlpha(40),
                    AppTheme.primaryPurple.withAlpha(20),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : AppTheme.darkElevated,
          border: Border.all(
            color: isSelected ? AppTheme.primaryPurple : Colors.white.withAlpha(15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(fit: StackFit.expand, children: [
            // Clip content
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.videocam,
                  color: isSelected ? AppTheme.primaryPurple : AppTheme.textMuted,
                  size: 22),
              const SizedBox(height: 2),
              Text('Clip ${index + 1}',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: isSelected ? AppTheme.textPrimary : Colors.white54,
                    fontWeight: FontWeight.w600,
                  )),
              if (clip.speed != 1.0)
                Text('${clip.speed.toStringAsFixed(1)}x',
                    style: GoogleFonts.inter(
                        fontSize: 7, color: AppTheme.accentCyan)),
            ]),

            // Trim indicators
            if (clip.trimStartFraction > 0.01 || clip.trimEndFraction < 0.99)
              Positioned(
                top: 2,
                left: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withAlpha(150),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Icon(Icons.content_cut, size: 8, color: Colors.white),
                ),
              ),

            // Playback position indicator
            if (playbackFrac != null)
              Positioned(
                left: playbackFrac * 96,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Colors.white.withAlpha(200),
                ),
              ),

            // Index badge
            Positioned(
              bottom: 2,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.black38,
                child: Text('${index + 1}/${_videoClips.length}',
                    style: GoogleFonts.inter(
                        fontSize: 7, color: Colors.white70, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ),
            ),

            // Delete button (X mark)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => _removeClip(index),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 10, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Bottom Toolbar ──
  Widget _buildToolbar() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withAlpha(200),
        border: Border(top: BorderSide(color: Colors.white.withAlpha(8))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _toolItem('Add', Icons.video_call, _pickAndAddVideo,
              color: AppTheme.accentCyan),
          _toolItem('Audio', Icons.music_note, _pickAudio,
              color: const Color(0xFF00F2EA)),
          _toolItem('Trim', Icons.content_cut, () => _openPanel('trim'),
              color: AppTheme.accentOrange),
          _toolItem('Split', Icons.call_split, _splitClipAtPosition,
              color: AppTheme.primaryPink),
          _toolItem('Speed', Icons.speed, () => _openPanel('speed')),
          _toolItem('Volume', Icons.volume_up, () => _openPanel('volume')),
          _toolItem('Filters', Icons.filter_vintage, () => _openPanel('filters'),
              color: const Color(0xFFE040FB)),
          _toolItem('Bright', Icons.brightness_6, () => _openPanel('brightness')),
          _toolItem('Text', Icons.text_fields, () => _openPanel('text'),
              color: const Color(0xFF00E676)),
        ],
      ),
    );
  }

  void _openPanel(String panel) {
    if (_selectedClipIndex == null && panel != 'text') {
      _showFeedback('Select a clip first');
      return;
    }
    setState(() {
      _activePanel = _activePanel == panel ? null : panel;
    });
  }

  // ── Clip Options Bottom Sheet ──
  void _showClipOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Clip ${index + 1}',
              style: GoogleFonts.outfit(
                  fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          _optionTile('Select & Play', Icons.play_circle, () {
            setState(() => _selectedClipIndex = index);
            _loadVideoForClip(index);
            Navigator.pop(ctx);
          }),
          if (index > 0)
            _optionTile('Move Left', Icons.arrow_back, () {
              _reorderClip(index, index - 1);
              Navigator.pop(ctx);
            }),
          if (index < _videoClips.length - 1)
            _optionTile('Move Right', Icons.arrow_forward, () {
              _reorderClip(index, index + 2);
              Navigator.pop(ctx);
            }),
          _optionTile('Duplicate', Icons.copy, () {
            _duplicateClip(index);
            Navigator.pop(ctx);
          }),
          _optionTile('Remove', Icons.delete, () {
            _removeClip(index);
            Navigator.pop(ctx);
          }, color: Colors.redAccent),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 18),
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onTap,
      {bool isPrimary = false, double size = 22}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isPrimary ? 10 : 8),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primaryPurple : Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(isPrimary ? 12 : 8),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  Widget _gradientChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _toolItem(String label, IconData icon, VoidCallback onTap,
      {Color? color}) {
    final isActive = _activePanel == label.toLowerCase();
    final c = color ?? AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 65,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isActive ? c.withAlpha(30) : Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? c : Colors.white.withAlpha(15),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: Icon(icon, color: isActive ? c : AppTheme.textSecondary, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: isActive ? c : AppTheme.textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _miniButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.primaryPurple.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppTheme.primaryPurple),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
        ]),
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryPurple.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryPurple.withAlpha(60)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppTheme.primaryPurple, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _optionTile(String label, IconData icon, VoidCallback? onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.textSecondary),
      title: Text(label,
          style: GoogleFonts.inter(
            color: color ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          )),
      onTap: onTap,
      enabled: onTap != null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _labeledSlider(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
        Text(value.toStringAsFixed(2),
            style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textMuted)),
      ]),
      Slider(
        value: value,
        min: min,
        max: max,
        activeColor: AppTheme.primaryPurple,
        inactiveColor: AppTheme.darkElevated,
        onChanged: onChanged,
      ),
    ]);
  }

  // ── Helpers ──
  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _showFeedback(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
      backgroundColor: AppTheme.darkCard,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showError(String msg) {
    _showFeedback(msg);
  }
}

// ═══════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════

class VideoClip {
  String fileName;
  String filePath;
  double speed;
  double volume;
  double brightness;
  double contrast;
  int filterIndex;
  double trimStartFraction;
  double trimEndFraction;
  Duration duration;

  VideoClip({
    required this.fileName,
    required this.filePath,
    this.speed = 1.0,
    this.volume = 1.0,
    this.brightness = 0.0,
    this.contrast = 1.0,
    this.filterIndex = 0,
    this.trimStartFraction = 0.0,
    this.trimEndFraction = 1.0,
    this.duration = Duration.zero,
  });

  factory VideoClip.copy(VideoClip other) {
    return VideoClip(
      fileName: other.fileName,
      filePath: other.filePath,
      speed: other.speed,
      volume: other.volume,
      brightness: other.brightness,
      contrast: other.contrast,
      filterIndex: other.filterIndex,
      trimStartFraction: other.trimStartFraction,
      trimEndFraction: other.trimEndFraction,
      duration: other.duration,
    );
  }
}

class TextOverlay {
  String text;
  Offset offset;
  double fontSize;
  Color color;

  TextOverlay({
    required this.text,
    required this.offset,
    this.fontSize = 24,
    this.color = Colors.white,
  });
}
