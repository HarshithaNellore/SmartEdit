import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as dart_ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../theme/app_theme.dart';

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key});

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  int _selectedToolCategory = 0;
  int _selectedFilterIndex = 0;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  // Core Adjustments
  double _brightness = 0.0;
  double _contrast = 1.0;
  double _saturation = 1.0;
  double _warmth = 0.0;
  double _sharpness = 0.0;
  double _vignette = 0.0;

  // Pro Adjustments
  double _blur = 0.0;
  double _denoise = 0.0;
  double _highlight = 0.0;
  double _skintone = 0.0;
  double _bluetone = 0.0;

  // Text overlays
  final List<PhotoTextOverlay> _textOverlays = [];

  // Drawing state
  final List<DrawnPath> _drawnPaths = [];
  DrawnPath? _currentPath;
  Color _brushColor = Colors.white;
  final double _brushWidth = 4.0;
  bool _isDrawingMode = false;

  // Transform state
  final TransformationController _transformController =
      TransformationController();
  int _rotateAngle = 0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  double? _aspectRatio;

  // Edit history
  final List<_PhotoState> _undoStack = [];
  final List<_PhotoState> _redoStack = [];

  final CropController _cropController = CropController();
  final GlobalKey _repaintKey = GlobalKey();

  final List<_PhotoTool> _tools = [
    const _PhotoTool('Adjust', Icons.tune_rounded), // 0
    const _PhotoTool('Filters', Icons.filter_vintage_rounded), // 1
    const _PhotoTool('Crop & Zoom', Icons.crop_rounded), // 2
    const _PhotoTool('Transform', Icons.transform_rounded), // 3
    const _PhotoTool('Text', Icons.text_fields_rounded), // 4
    const _PhotoTool('AI', Icons.auto_awesome), // 5
    const _PhotoTool('Draw', Icons.brush_rounded), // 6
  ];

  final List<_PhotoFilter> _filters = [
    const _PhotoFilter('Original', null),
    const _PhotoFilter(
      'Vivid',
      ColorFilter.matrix(<double>[
        1.3,
        0,
        0,
        0,
        10,
        0,
        1.1,
        0,
        0,
        5,
        0,
        0,
        0.9,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    const _PhotoFilter(
      'Warm',
      ColorFilter.matrix(<double>[
        1.2,
        0.1,
        0,
        0,
        15,
        0,
        1.0,
        0,
        0,
        5,
        0,
        0,
        0.8,
        0,
        -10,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    const _PhotoFilter(
      'Cool',
      ColorFilter.matrix(<double>[
        0.8,
        0,
        0.1,
        0,
        -5,
        0,
        1.0,
        0.1,
        0,
        0,
        0.1,
        0,
        1.3,
        0,
        15,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    const _PhotoFilter(
      'B&W',
      ColorFilter.matrix(<double>[
        0.33,
        0.33,
        0.33,
        0,
        0,
        0.33,
        0.33,
        0.33,
        0,
        0,
        0.33,
        0.33,
        0.33,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    const _PhotoFilter(
      'Vintage',
      ColorFilter.matrix(<double>[
        0.9,
        0.2,
        0.1,
        0,
        20,
        0.1,
        0.8,
        0.1,
        0,
        15,
        0,
        0.1,
        0.6,
        0,
        -5,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    const _PhotoFilter(
      'Dreamy',
      ColorFilter.matrix(<double>[
        1.1,
        0.1,
        0.1,
        0,
        20,
        0.05,
        0.95,
        0.1,
        0,
        15,
        0.1,
        0.05,
        1.1,
        0,
        25,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
    const _PhotoFilter(
      'Noir',
      ColorFilter.matrix(<double>[
        0.4,
        0.4,
        0.4,
        0,
        -20,
        0.3,
        0.3,
        0.3,
        0,
        -15,
        0.2,
        0.2,
        0.2,
        0,
        -10,
        0,
        0,
        0,
        1,
        0,
      ]),
    ),
  ];

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    if (!kIsWeb &&
        source == ImageSource.camera &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      _showFeedback(
        'Camera capture is not supported on Desktop versions yet. Please import from Gallery.',
        isError: true,
      );
      return;
    }

    try {
      final file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() => _imageBytes = bytes);
      }
    } catch (e) {
      _showFeedback(
        'Failed to pick image. Please check app permissions and try again.',
        isError: true,
      );
      debugPrint('Image picker error: $e');
    }
  }

  void _saveState() {
    _undoStack.add(
      _PhotoState(
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        warmth: _warmth,
        sharpness: _sharpness,
        vignette: _vignette,
        blur: _blur,
        highlight: _highlight,
        skintone: _skintone,
        bluetone: _bluetone,
        filterIndex: _selectedFilterIndex,
        rotateAngle: _rotateAngle,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
      ),
    );
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(
      _PhotoState(
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        warmth: _warmth,
        sharpness: _sharpness,
        vignette: _vignette,
        blur: _blur,
        highlight: _highlight,
        skintone: _skintone,
        bluetone: _bluetone,
        filterIndex: _selectedFilterIndex,
        rotateAngle: _rotateAngle,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
      ),
    );
    final s = _undoStack.removeLast();
    setState(() {
      _brightness = s.brightness;
      _contrast = s.contrast;
      _saturation = s.saturation;
      _warmth = s.warmth;
      _sharpness = s.sharpness;
      _vignette = s.vignette;
      _blur = s.blur;
      _highlight = s.highlight;
      _skintone = s.skintone;
      _bluetone = s.bluetone;
      _selectedFilterIndex = s.filterIndex;
      _rotateAngle = s.rotateAngle;
      _flipHorizontal = s.flipHorizontal;
      _flipVertical = s.flipVertical;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(
      _PhotoState(
        brightness: _brightness,
        contrast: _contrast,
        saturation: _saturation,
        warmth: _warmth,
        sharpness: _sharpness,
        vignette: _vignette,
        blur: _blur,
        highlight: _highlight,
        skintone: _skintone,
        bluetone: _bluetone,
        filterIndex: _selectedFilterIndex,
        rotateAngle: _rotateAngle,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
      ),
    );
    final s = _redoStack.removeLast();
    setState(() {
      _brightness = s.brightness;
      _contrast = s.contrast;
      _saturation = s.saturation;
      _warmth = s.warmth;
      _sharpness = s.sharpness;
      _vignette = s.vignette;
      _blur = s.blur;
      _highlight = s.highlight;
      _skintone = s.skintone;
      _bluetone = s.bluetone;
      _selectedFilterIndex = s.filterIndex;
      _rotateAngle = s.rotateAngle;
      _flipHorizontal = s.flipHorizontal;
      _flipVertical = s.flipVertical;
    });
  }

  Future<void> _exportPhoto() async {
    if (_imageBytes == null) {
      _showFeedback('No photo to export!', isError: true);
      return;
    }
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(
        format: dart_ui.ImageByteFormat.png,
      );
      if (byteData == null) return;
      final pngBytes = byteData.buffer.asUint8List();

      final appDir = await getTemporaryDirectory();
      final filePath =
          '${appDir.path}/smartcut_photo_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final hasAccess = await Gal.requestAccess(toAlbum: true);
        if (hasAccess) {
          await Gal.putImage(filePath, album: 'SmartEdit');
        }
      }

      _showFeedback('Photo Exported Successfully to Gallery!');
    } catch (e) {
      _showFeedback('Export failed: $e', isError: true);
    }
  }

  ColorFilter _buildAdjustmentFilter() {
    // Pro-level translation logic
    double br = _brightness * 255;
    double wa = _warmth * 15;
    double hl = _highlight * 20;
    double st = _skintone * 15;
    double bt = _bluetone * 25;
    double s = _saturation;
    double c = _contrast;

    return ColorFilter.matrix(<double>[
      c * s + (1 - s) * 0.3,
      (1 - s) * 0.59 + st * 0.02,
      (1 - s) * 0.11,
      0,
      br + wa + hl + st,
      (1 - s) * 0.3,
      c * s + (1 - s) * 0.59,
      (1 - s) * 0.11,
      0,
      br + wa * 0.5 + hl + st * 0.5,
      (1 - s) * 0.3,
      (1 - s) * 0.59,
      c * s + (1 - s) * 0.11,
      0,
      br - wa + bt,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          gradient: AppTheme.getBackgroundGradient(context),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildPhotoPreview()),
              _buildToolbar(),
              _buildToolPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppTheme.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Photo Editor',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _barButton(
            Icons.undo_rounded,
            _undoStack.isNotEmpty ? _undo : null,
            _undoStack.isNotEmpty,
          ),
          const SizedBox(width: 8),
          _barButton(
            Icons.redo_rounded,
            _redoStack.isNotEmpty ? _redo : null,
            _redoStack.isNotEmpty,
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _exportPhoto,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barButton(IconData icon, VoidCallback? onTap, bool active) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: active ? AppTheme.textPrimary : AppTheme.textMuted,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    if (_imageBytes != null && _selectedToolCategory == 2) {
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CropImage(
            image: Image.memory(_imageBytes!),
            controller: _cropController,
            onCrop: (viewPortRect) {},
            scrimColor: Colors.black.withAlpha(150),
          ),
        ),
      );
    }

    final filterCF = _filters[_selectedFilterIndex].colorFilter;

    Widget imageContent = _imageBytes != null
        ? RepaintBoundary(
            key: _repaintKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Base Image + Transforms + Filters
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..rotateZ(_rotateAngle * math.pi / 180)
                    ..multiply(
                      Matrix4.diagonal3Values(
                        _flipHorizontal ? -1.0 : 1.0,
                        _flipVertical ? -1.0 : 1.0,
                        1.0,
                      ),
                    ),
                  child: ImageFiltered(
                    imageFilter: dart_ui.ImageFilter.blur(
                      sigmaX: _blur + _denoise * 0.8,
                      sigmaY: _blur + _denoise * 0.8,
                    ),
                    child: ColorFiltered(
                      colorFilter: _buildAdjustmentFilter(),
                      child: ColorFiltered(
                        colorFilter:
                            filterCF ??
                            const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            ),
                        child: Image.memory(_imageBytes!, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),

                // Drawing Layer
                CustomPaint(
                  painter: _DrawingPainter(
                    List.from(_drawnPaths)
                      ..addAll(_currentPath != null ? [_currentPath!] : []),
                  ),
                  size: Size.infinite,
                ),

                // Text Layer
                ..._textOverlays.asMap().entries.map((entry) {
                  final overlay = entry.value;
                  return Positioned(
                    left: overlay.offset.dx,
                    top: overlay.offset.dy,
                    child: GestureDetector(
                      onLongPress: () =>
                          setState(() => _textOverlays.removeAt(entry.key)),
                      onPanUpdate: (details) {
                        setState(() {
                          overlay.offset = Offset(
                            overlay.offset.dx + details.delta.dx,
                            overlay.offset.dy + details.delta.dy,
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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

                // Gesture overlay for Drawing
                if (_isDrawingMode && _selectedToolCategory == 6)
                  GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _currentPath = DrawnPath(
                          points: [details.localPosition],
                          color: _brushColor,
                          width: _brushWidth,
                        );
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _currentPath?.points.add(details.localPosition);
                      });
                    },
                    onPanEnd: (details) {
                      setState(() {
                        if (_currentPath != null) {
                          _drawnPaths.add(_currentPath!);
                          _currentPath = null;
                        }
                      });
                    },
                    child: Container(color: Colors.transparent),
                  ),
              ],
            ),
          )
        : Center(
            // Empty State
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.photo_rounded,
                  size: 64,
                  color: Colors.white.withAlpha(60),
                ),
                const SizedBox(height: 12),
                Text(
                  'No photo selected',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withAlpha(120),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _importButton(
                      'Gallery',
                      Icons.photo_library,
                      () => _pickImage(),
                    ),
                    const SizedBox(width: 12),
                    _importButton(
                      'Camera',
                      Icons.camera_alt,
                      () => _pickImage(source: ImageSource.camera),
                    ),
                  ],
                ),
              ],
            ),
          );

    Widget viewer = _imageBytes != null
        ? InteractiveViewer(
            transformationController: _transformController,
            panEnabled: _selectedToolCategory == 3, // Enable for transform
            scaleEnabled: _selectedToolCategory == 3,
            minScale: 1.0,
            maxScale: 6.0,
            clipBehavior: Clip.hardEdge,
            child: imageContent,
          )
        : imageContent;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: _imageBytes != null && _aspectRatio != null
              ? AspectRatio(aspectRatio: _aspectRatio!, child: viewer)
              : viewer,
        ),
      ),
    );
  }

  Widget _importButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 70,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _tools.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedToolCategory == index;
          final tool = _tools[index];
          return GestureDetector(
            onTap: () => setState(() {
              _selectedToolCategory = index;
              if (index != 6)
                _isDrawingMode =
                    false; // Turn off drawing mode if not on drawing tool
            }),
            child: Container(
              width: 68,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryPurple.withAlpha(40)
                          : Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryPurple)
                          : Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: Icon(
                      tool.icon,
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : AppTheme.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tool.name,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : AppTheme.textMuted,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolPanel() {
    switch (_selectedToolCategory) {
      case 0:
        return _buildAdjustPanel();
      case 1:
        return _buildFilterPanel();
      case 2:
        return _buildCropZoomPanel(); // Merged logic
      case 3:
        return _buildTransformPanel();
      case 4:
        return _buildTextPanel();
      case 5:
        return _buildAIPanel();
      case 6:
        return _buildDrawPanel();
      default:
        return const SizedBox(height: 100);
    }
  }

  Widget _buildAdjustPanel() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _adjustSlider('Brightness', _brightness, -0.5, 0.5, (v) {
            _saveState();
            setState(() => _brightness = v);
          }),
          _adjustSlider('Contrast', _contrast, 0.5, 2.0, (v) {
            _saveState();
            setState(() => _contrast = v);
          }),
          _adjustSlider('Saturation', _saturation, 0.0, 2.0, (v) {
            _saveState();
            setState(() => _saturation = v);
          }),
          _adjustSlider('Highlight', _highlight, -1.0, 1.0, (v) {
            _saveState();
            setState(() => _highlight = v);
          }),
          _adjustSlider('Warmth', _warmth, -1.0, 1.0, (v) {
            _saveState();
            setState(() => _warmth = v);
          }),
          _adjustSlider('Skintone', _skintone, -1.0, 1.0, (v) {
            _saveState();
            setState(() => _skintone = v);
          }),
          _adjustSlider('Bluetone', _bluetone, -1.0, 1.0, (v) {
            _saveState();
            setState(() => _bluetone = v);
          }),
          _adjustSlider('Sharpness', _sharpness, 0.0, 1.0, (v) {
            setState(() => _sharpness = v);
          }),
          _adjustSlider('Denoise', _denoise, 0.0, 2.0, (v) {
            setState(() => _denoise = v);
          }),
          _adjustSlider('Blur', _blur, 0.0, 10.0, (v) {
            setState(() => _blur = v);
          }),
        ],
      ),
    );
  }

  Widget _adjustSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Container(
      width: 140,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              activeColor: AppTheme.primaryPurple,
              inactiveColor: AppTheme.getElevatedColor(context),
              onChanged: onChanged,
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedFilterIndex == index;
          return GestureDetector(
            onTap: () {
              _saveState();
              setState(() => _selectedFilterIndex = index);
            },
            child: Container(
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryPurple, width: 2)
                          : Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _imageBytes != null
                          ? ColorFiltered(
                              colorFilter:
                                  _filters[index].colorFilter ??
                                  const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.dst,
                                  ),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              color: AppTheme.getElevatedColor(context),
                              child: const Icon(
                                Icons.photo,
                                color: AppTheme.textMuted,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _filters[index].name,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : AppTheme.textMuted,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCropZoomPanel() {
    return _buildActionList([
      _ActionItem('Apply', Icons.check, () async {
        final dart_ui.Image bitmap = await _cropController.croppedBitmap();
        final ByteData? data = await bitmap.toByteData(
          format: dart_ui.ImageByteFormat.png,
        );
        if (data != null) {
          _saveState();
          setState(() {
            _imageBytes = data.buffer.asUint8List();
            _selectedToolCategory = 0; // Go back to Adjust mode
          });
        }
      }),
      _ActionItem(
        'Free',
        Icons.crop_free,
        () => _cropController.aspectRatio = null,
      ),
      _ActionItem(
        '1:1',
        Icons.crop_square,
        () => _cropController.aspectRatio = 1.0,
      ),
      _ActionItem(
        '4:3',
        Icons.crop_landscape,
        () => _cropController.aspectRatio = 4.0 / 3.0,
      ),
      _ActionItem(
        '3:4',
        Icons.crop_portrait,
        () => _cropController.aspectRatio = 3.0 / 4.0,
      ),
      _ActionItem(
        '16:9',
        Icons.crop_16_9,
        () => _cropController.aspectRatio = 16.0 / 9.0,
      ),
      _ActionItem(
        '9:16',
        Icons.crop_portrait,
        () => _cropController.aspectRatio = 9.0 / 16.0,
      ),
    ]);
  }

  Widget _buildTransformPanel() {
    return _buildActionList([
      _ActionItem('Rotate', Icons.rotate_90_degrees_cw, () {
        _saveState();
        setState(() => _rotateAngle = (_rotateAngle + 90) % 360);
      }),
      _ActionItem('Mirror', Icons.flip, () {
        _saveState();
        setState(() => _flipHorizontal = !_flipHorizontal);
      }),
      _ActionItem('Flip V', Icons.flip_camera_android, () {
        _saveState();
        setState(() => _flipVertical = !_flipVertical);
      }),
      _ActionItem('Reset All', Icons.restore, () {
        _saveState();
        setState(() {
          _rotateAngle = 0;
          _flipHorizontal = false;
          _flipVertical = false;
          _aspectRatio = null;
          _transformController.value = Matrix4.identity();
        });
      }),
    ]);
  }

  Widget _buildTextPanel() => _buildActionList([
    _ActionItem('Add Text', Icons.text_fields, () => _showTextInputDialog()),
    _ActionItem(
      'Clear All Text',
      Icons.delete_sweep,
      () => setState(() => _textOverlays.clear()),
    ),
  ]);

  Widget _buildAIPanel() => _buildActionList([
    _ActionItem('Original', Icons.restore, () {
      _saveState();
      setState(() {
        _saturation = 1.0;
        _contrast = 1.0;
        _brightness = 0.0;
        _warmth = 0.0;
        _highlight = 0.0;
        _sharpness = 0.0;
        _vignette = 0.0;
        _blur = 0.0;
        _skintone = 0.0;
        _bluetone = 0.0;
        _denoise = 0.0;
      });
    }),
    _ActionItem('Auto Enhance', Icons.auto_fix_high, () {
      _saveState();
      setState(() {
        _saturation = 1.4;
        _contrast = 1.4;
        _highlight = 0.3;
        _sharpness = 0.5;
        _warmth = 0.1;
      });
    }),
    _ActionItem('HDR Filter', Icons.hdr_on, () {
      _saveState();
      setState(() {
        _contrast = 1.6;
        _saturation = 1.3;
        _highlight = 0.5;
        _vignette = 0.4;
        _blur = 0.0;
      });
    }),
    _ActionItem('Relight', Icons.lightbulb, () {
      _saveState();
      setState(() {
        _brightness = 0.25;
        _warmth = 0.4;
        _highlight = 0.4;
      });
    }),
    _ActionItem('Color Match', Icons.color_lens, () {
      _saveState();
      setState(() {
        _skintone = 0.3;
        _bluetone = -0.2;
        _saturation = 1.25;
      });
    }),
  ]);

  Widget _buildDrawPanel() => _buildActionList([
    _ActionItem(
      'Draw Mode: ${_isDrawingMode ? 'ON' : 'OFF'}',
      Icons.brush,
      () => setState(() => _isDrawingMode = !_isDrawingMode),
    ),
    _ActionItem('Color', Icons.color_lens, _showColorPicker),
    _ActionItem('Undo Stroke', Icons.undo, () {
      if (_drawnPaths.isNotEmpty) setState(() => _drawnPaths.removeLast());
    }),
    _ActionItem(
      'Clear All',
      Icons.clear,
      () => setState(() {
        _drawnPaths.clear();
        _currentPath = null;
      }),
    ),
  ]);

  Widget _buildActionList(List<_ActionItem> items) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: items
            .map(
              (item) => GestureDetector(
                onTap: item.onTap,
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withAlpha(20)),
                        ),
                        child: Icon(
                          item.icon,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showTextInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Text Overlay',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: AppTheme.textPrimary),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter text...',
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.getElevatedColor(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppTheme.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _textOverlays.add(
                    PhotoTextOverlay(
                      text: controller.text.trim(),
                      offset: const Offset(100, 100),
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  );
                });
              }
              Navigator.pop(ctx);
            },
            child: Text(
              'Add',
              style: GoogleFonts.inter(
                color: AppTheme.primaryPurple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    final colors = [
      Colors.white,
      Colors.black,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Brush Color',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: colors.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    setState(() => _brushColor = colors[i]);
                    Navigator.pop(ctx);
                    if (!_isDrawingMode) {
                      setState(() => _isDrawingMode = true);
                    }
                    _showFeedback('Brush color updated! Draw Mode is ON.');
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors[i],
                      border: Border.all(
                        color: Colors.white.withAlpha(50),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedback(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 13)),
        backgroundColor: isError
            ? Colors.redAccent
            : AppTheme.getCardColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: isError
            ? const Duration(seconds: 3)
            : const Duration(seconds: 1),
      ),
    );
  }
}

class _PhotoTool {
  final String name;
  final IconData icon;
  const _PhotoTool(this.name, this.icon);
}

class _PhotoFilter {
  final String name;
  final ColorFilter? colorFilter;
  const _PhotoFilter(this.name, this.colorFilter);
}

class _PhotoState {
  final double brightness, contrast, saturation, warmth, sharpness, vignette;
  final double blur, highlight, skintone, bluetone;
  final int filterIndex, rotateAngle;
  final bool flipHorizontal, flipVertical;

  const _PhotoState({
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.warmth,
    required this.sharpness,
    required this.vignette,
    required this.blur,
    required this.highlight,
    required this.skintone,
    required this.bluetone,
    required this.filterIndex,
    required this.rotateAngle,
    required this.flipHorizontal,
    required this.flipVertical,
  });
}

class _ActionItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionItem(this.label, this.icon, this.onTap);
}

class PhotoTextOverlay {
  String text;
  Offset offset;
  double fontSize;
  Color color;

  PhotoTextOverlay({
    required this.text,
    required this.offset,
    this.fontSize = 24,
    this.color = Colors.white,
  });
}

class DrawnPath {
  final List<Offset> points;
  final Color color;
  final double width;

  DrawnPath({required this.points, required this.color, required this.width});
}

class _DrawingPainter extends CustomPainter {
  final List<DrawnPath> paths;

  _DrawingPainter(this.paths);

  @override
  void paint(Canvas canvas, Size size) {
    for (var path in paths) {
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (path.points.isNotEmpty) {
        final p = Path()..moveTo(path.points.first.dx, path.points.first.dy);
        for (int i = 1; i < path.points.length; i++) {
          p.lineTo(path.points[i].dx, path.points[i].dy);
        }
        canvas.drawPath(p, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
