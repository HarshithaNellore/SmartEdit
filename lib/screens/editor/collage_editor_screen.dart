import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';

class CollageEditorScreen extends StatefulWidget {
  const CollageEditorScreen({super.key});

  @override
  State<CollageEditorScreen> createState() => _CollageEditorScreenState();
}

class _CollageEditorScreenState extends State<CollageEditorScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  List<_SlotData> _slots = [];
  int _selectedLayout = 0;
  Color _backgroundColor = const Color(0xFF1a1a2e);
  double _spacing = 4.0;
  double _cornerRadius = 12.0;
  int? _selectedSlotIndex;
  final GlobalKey _repaintKey = GlobalKey();
  int? _selectedPhotoCount;
  bool _freestyleMode = false;
  int _selectedRatio = 0;
  int _selectedGradient = -1; // -1 = solid color
  int _activeToolbar = 0; // 0=layout, 1=spacing, 2=corners, 3=bg, 4=ratio

  final List<_AspectRatio> _ratios = [
    _AspectRatio('1:1', 1.0),
    _AspectRatio('4:5', 4.0 / 5.0),
    _AspectRatio('9:16', 9.0 / 16.0),
    _AspectRatio('16:9', 16.0 / 9.0),
    _AspectRatio('3:4', 3.0 / 4.0),
    _AspectRatio('Free', 0), // 0 = unconstrained
  ];

  final List<List<Color>> _gradients = [
    [const Color(0xFF0D0D1A), const Color(0xFF1A0A2E)],
    [const Color(0xFF667EEA), const Color(0xFF764BA2)],
    [const Color(0xFFFF6B6B), const Color(0xFFE040FB)],
    [const Color(0xFF00D4AA), const Color(0xFF00B4D8)],
    [const Color(0xFFFF8A50), const Color(0xFFFFB347)],
    [const Color(0xFF1a1a2e), const Color(0xFF533483)],
    [const Color(0xFF0f3460), const Color(0xFFe94560)],
    [const Color(0xFF232526), const Color(0xFF414345)],
  ];

  final List<Color> _solidColors = [
    Colors.black,
    Colors.white,
    const Color(0xFF1a1a2e),
    const Color(0xFF0f3460),
    const Color(0xFF533483),
    const Color(0xFFc9184a),
    const Color(0xFF2d3436),
    const Color(0xFFdfe6e9),
  ];

  final List<_CollageLayout> _allLayouts = [
    _CollageLayout('2 Split', 2, [[0], [1]]),
    _CollageLayout('2 Side', 2, [[0, 1]]),
    _CollageLayout('3 Vertical', 3, [[0], [1], [2]]),
    _CollageLayout('3 Horizontal', 3, [[0, 1, 2]]),
    _CollageLayout('1+2 Top', 3, [[0, 0], [1, 2]]),
    _CollageLayout('2x2 Grid', 4, [[0, 1], [2, 3]]),
    _CollageLayout('Top Large', 4, [[0, 0], [1, 2]]),
    _CollageLayout('Bottom Large', 4, [[0, 1], [2, 2]]),
    _CollageLayout('5 Grid', 5, [[0, 1], [2, 3, 4]]),
    _CollageLayout('L-Shape', 5, [[0, 0, 1], [2, 3, 4]]),
    _CollageLayout('2x3 Grid', 6, [[0, 1], [2, 3], [4, 5]]),
    _CollageLayout('3x3 Grid', 9, [[0, 1, 2], [3, 4, 5], [6, 7, 8]]),
  ];

  List<_CollageLayout> get _availableLayouts {
    if (_selectedPhotoCount == null) return [];
    return _allLayouts
        .where((l) => l.photoCount == _selectedPhotoCount)
        .toList();
  }

  void _selectPhotoCount(int count) {
    setState(() {
      _selectedPhotoCount = count;
      _selectedLayout = 0;
      _slots = List.generate(count, (i) => _SlotData());
    });
  }

  Future<void> _pickPhoto(int index) async {
    try {
      final file = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() => _slots[index].imageBytes = bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to pick image. Please check app permissions.', style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      debugPrint('Collage image picker error: $e');
    }
  }

  Future<void> _replacePhoto(int index) async {
    await _pickPhoto(index);
  }

  void _removePhoto(int index) {
    setState(() {
      _slots[index] = _SlotData();
      _selectedSlotIndex = null;
    });
  }

  Future<void> _exportCollage() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Collage exported! (${(pngBytes.length / 1024).toStringAsFixed(0)} KB)',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export error: $e',
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: _selectedPhotoCount == null
              ? _buildPhotoCountSelector()
              : Column(children: [
                  _buildTopBar(),
                  Expanded(child: _buildEditorBody()),
                  _buildBottomToolbar(),
                ]),
        ),
      ),
    );
  }

  // ─── Photo Count Selector ───
  Widget _buildPhotoCountSelector() {
    final counts = [2, 3, 4, 5, 6, 9];
    final colors = [
      [const Color(0xFF6C63FF), const Color(0xFF9C27B0)],
      [const Color(0xFFFF6B9D), const Color(0xFFFF8A50)],
      [const Color(0xFF00D4AA), const Color(0xFF00B4D8)],
      [const Color(0xFFFFD700), const Color(0xFFFF6B6B)],
      [const Color(0xFFE040FB), const Color(0xFF667EEA)],
      [const Color(0xFF9C27B0), const Color(0xFFE040FB)],
    ];

    return Column(children: [
      // Top bar
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
          Text('Collage Maker',
              style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('How many photos?',
                  style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text('Choose count to see available layouts',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: AppTheme.textSecondary)),
              const SizedBox(height: 32),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.0,
                ),
                itemCount: counts.length,
                itemBuilder: (context, i) {
                  final count = counts[i];
                  final layoutCount = _allLayouts
                      .where((l) => l.photoCount == count)
                      .length;
                  return GestureDetector(
                    onTap: () => _selectPhotoCount(count),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors[i],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colors[i][0].withAlpha(60),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(count.toString(),
                              style: GoogleFonts.outfit(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          Text('$layoutCount layouts',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ]);
  }

  // ─── Top Bar ───
  Widget _buildTopBar() {
    final filledCount = _slots.where((s) => s.imageBytes != null).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() => _selectedPhotoCount = null),
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
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Collage',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text('$filledCount/$_selectedPhotoCount photos',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textMuted)),
              ]),
        ),
        // Freestyle toggle
        GestureDetector(
          onTap: () => setState(() => _freestyleMode = !_freestyleMode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _freestyleMode
                  ? AppTheme.accentCyan.withAlpha(30)
                  : Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _freestyleMode
                    ? AppTheme.accentCyan.withAlpha(60)
                    : Colors.white.withAlpha(15),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                _freestyleMode ? Icons.pan_tool_rounded : Icons.grid_view_rounded,
                size: 14,
                color: _freestyleMode ? AppTheme.accentCyan : AppTheme.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                _freestyleMode ? 'Free' : 'Grid',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _freestyleMode ? AppTheme.accentCyan : AppTheme.textMuted,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        // Export
        GestureDetector(
          onTap: _exportCollage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.primaryPurple.withAlpha(60),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.download_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text('Export',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─── Editor Body ───
  Widget _buildEditorBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(children: [
        const SizedBox(height: 8),
        _buildCollagePreview(),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildCollagePreview() {
    final ratio = _ratios[_selectedRatio];
    final screenWidth = MediaQuery.of(context).size.width - 32;
    double previewWidth = screenWidth;
    double previewHeight;

    if (ratio.value == 0) {
      previewHeight = screenWidth; // default square for free
    } else {
      previewHeight = screenWidth / ratio.value;
      if (previewHeight > screenWidth * 1.4) {
        previewHeight = screenWidth * 1.4;
        previewWidth = previewHeight * ratio.value;
      }
    }

    return Center(
      child: RepaintBoundary(
        key: _repaintKey,
        child: Container(
          width: previewWidth,
          height: previewHeight,
          decoration: BoxDecoration(
            color: _selectedGradient < 0 ? _backgroundColor : null,
            gradient: _selectedGradient >= 0
                ? LinearGradient(
                    colors: _gradients[_selectedGradient],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(_cornerRadius),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_cornerRadius),
            child: _freestyleMode
                ? _buildFreestyleCanvas(previewWidth, previewHeight)
                : _buildGridLayout(previewWidth, previewHeight),
          ),
        ),
      ),
    );
  }

  // ─── Grid Layout Mode ───
  Widget _buildGridLayout(double w, double h) {
    if (_availableLayouts.isEmpty) return const SizedBox();
    final layout = _availableLayouts[_selectedLayout % _availableLayouts.length];

    return Padding(
      padding: EdgeInsets.all(_spacing),
      child: Column(
        children: List.generate(layout.grid.length, (rowIndex) {
          final row = layout.grid[rowIndex];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: rowIndex < layout.grid.length - 1 ? _spacing : 0),
              child: Row(
                children: List.generate(row.length, (colIndex) {
                  final photoIndex = row[colIndex];
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                          right: colIndex < row.length - 1 ? _spacing : 0),
                      child: _buildSlot(photoIndex, null),
                    ),
                  );
                }),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ─── Freestyle Canvas Mode ───
  Widget _buildFreestyleCanvas(double w, double h) {
    final slotSize = min(w, h) / (sqrt(_slots.length) + 0.5);
    // Initialize positions if not set
    for (var i = 0; i < _slots.length; i++) {
      _slots[i].freestyleX ??= (w / 2 - slotSize / 2) + (i % 3 - 1) * (slotSize * 0.3);
      _slots[i].freestyleY ??= (h / 2 - slotSize / 2) + (i ~/ 3) * (slotSize * 0.3);
      _slots[i].freestyleW ??= slotSize;
      _slots[i].freestyleH ??= slotSize;
    }

    return Stack(
      children: List.generate(_slots.length, (i) {
        final slot = _slots[i];
        final isSelected = _selectedSlotIndex == i;
        return Positioned(
          left: slot.freestyleX!,
          top: slot.freestyleY!,
          child: GestureDetector(
            onTap: () => setState(() => _selectedSlotIndex = i),
            onDoubleTap: () => _pickPhoto(i),
            onPanUpdate: (d) {
              setState(() {
                slot.freestyleX = (slot.freestyleX! + d.delta.dx)
                    .clamp(0, w - slot.freestyleW!);
                slot.freestyleY = (slot.freestyleY! + d.delta.dy)
                    .clamp(0, h - slot.freestyleH!);
              });
            },
            onScaleUpdate: (d) {
              if (d.scale != 1.0) {
                setState(() {
                  slot.freestyleW = (slot.freestyleW! * d.scale).clamp(60.0, w * 0.8);
                  slot.freestyleH = (slot.freestyleH! * d.scale).clamp(60.0, h * 0.8);
                });
              }
            },
            child: Container(
              width: slot.freestyleW,
              height: slot.freestyleH,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_cornerRadius),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentCyan
                      : Colors.white.withAlpha(30),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: AppTheme.accentCyan.withAlpha(40),
                            blurRadius: 10)
                      ]
                    : null,
              ),
              child: _buildSlot(i, BoxConstraints(
                maxWidth: slot.freestyleW!,
                maxHeight: slot.freestyleH!,
              )),
            ),
          ),
        );
      }),
    );
  }

  // ─── Slot Widget ───
  Widget _buildSlot(int index, BoxConstraints? constraints) {
    final slot = _slots[index];
    final isSelected = _selectedSlotIndex == index;

    Widget slotWidget = GestureDetector(
      onTap: () => setState(() => _selectedSlotIndex = index),
      onDoubleTap: () => _pickPhoto(index),
      onLongPress: () {
        if (slot.imageBytes != null && _freestyleMode) {
          _showSlotMenu(index);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(max(0, _cornerRadius - _spacing)),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.darkCard,
            border: !_freestyleMode
                ? Border.all(
                    color: isSelected
                        ? AppTheme.primaryPurple
                        : Colors.transparent,
                    width: isSelected ? 2 : 0,
                  )
                : null,
          ),
          child: slot.imageBytes != null
              ? InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Stack(fit: StackFit.expand, children: [
                    Image.memory(slot.imageBytes!, fit: BoxFit.cover),
                    // Selection overlay
                    if (isSelected)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.zoom_in,
                              color: Colors.white, size: 16),
                        ),
                      ),
                  ]),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: AppTheme.primaryPurple.withAlpha(150), size: 28),
                    const SizedBox(height: 4),
                    Text('Tap or Drag',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppTheme.textMuted)),
                  ],
                ),
        ),
      ),
    );

    if (_freestyleMode) return slotWidget;

    // Grid mode: enable drag-to-swap
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        setState(() {
          final draggedIndex = details.data;
          final temp = _slots[index];
          _slots[index] = _slots[draggedIndex];
          _slots[draggedIndex] = temp;
          // Maintain selection visually
          if (_selectedSlotIndex == draggedIndex) { _selectedSlotIndex = index; }
          else if (_selectedSlotIndex == index) { _selectedSlotIndex = draggedIndex; }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        Widget targetWidget = slotWidget;
        
        if (isHovered) {
          targetWidget = Stack(
            fit: StackFit.expand,
            children: [
              slotWidget,
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withAlpha(80),
                  borderRadius: BorderRadius.circular(max(0, _cornerRadius - _spacing)),
                  border: Border.all(color: AppTheme.accentCyan, width: 3),
                ),
              ),
            ],
          );
        }

        return LongPressDraggable<int>(
          data: index,
          delay: const Duration(milliseconds: 300),
          feedback: Opacity(
            opacity: 0.8,
            child: SizedBox(
              width: 150,
              height: 150,
              child: slotWidget,
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: slotWidget,
          ),
          onDragStarted: () => setState(() => _selectedSlotIndex = index),
          child: targetWidget,
        );
      },
    );
  }

  void _showSlotMenu(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.darkElevated,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          _menuItem(Icons.swap_horiz_rounded, 'Replace Image',
              AppTheme.primaryPurple, () {
            Navigator.pop(context);
            _replacePhoto(index);
          }),
          _menuItem(
              Icons.delete_outline_rounded, 'Remove', Colors.redAccent, () {
            Navigator.pop(context);
            _removePhoto(index);
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _menuItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary)),
        ]),
      ),
    );
  }

  // ─── Bottom Toolbar ───
  Widget _buildBottomToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(60),
              blurRadius: 10,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(children: [
        // Toolbar icons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _toolbarIcon(0, Icons.grid_view_rounded, 'Layout'),
              _toolbarIcon(1, Icons.space_bar_rounded, 'Spacing'),
              _toolbarIcon(2, Icons.rounded_corner_rounded, 'Corners'),
              _toolbarIcon(3, Icons.palette_rounded, 'Color'),
              _toolbarIcon(4, Icons.aspect_ratio_rounded, 'Ratio'),
            ],
          ),
        ),
        // Tool panel
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 80,
          child: _buildToolPanel(),
        ),
      ]),
    );
  }

  Widget _toolbarIcon(int index, IconData icon, String label) {
    final isActive = _activeToolbar == index;
    return GestureDetector(
      onTap: () => setState(() => _activeToolbar = index),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryPurple.withAlpha(25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              size: 22,
              color:
                  isActive ? AppTheme.primaryPurple : AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppTheme.primaryPurple
                    : AppTheme.textMuted)),
      ]),
    );
  }

  Widget _buildToolPanel() {
    switch (_activeToolbar) {
      case 0:
        return _buildLayoutPanel();
      case 1:
        return _buildSpacingPanel();
      case 2:
        return _buildCornerPanel();
      case 3:
        return _buildColorPanel();
      case 4:
        return _buildRatioPanel();
      default:
        return const SizedBox();
    }
  }

  Widget _buildLayoutPanel() {
    final layouts = _availableLayouts;
    if (layouts.isEmpty) {
      return Center(
          child: Text('No layouts for $_selectedPhotoCount photos',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppTheme.textMuted)));
    }
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: layouts.length,
      itemBuilder: (_, i) {
        final isSelected = _selectedLayout == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedLayout = i),
          child: Container(
            width: 68,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryPurple
                      : Colors.white.withAlpha(15),
                  width: isSelected ? 2 : 1),
            ),
            child: Column(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: _buildMiniLayoutPreview(layouts[i]),
                ),
              ),
              Text(layouts[i].name,
                  style: GoogleFonts.inter(
                      fontSize: 8,
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : AppTheme.textMuted),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMiniLayoutPreview(_CollageLayout layout) {
    return Column(
      children: List.generate(layout.grid.length, (rowIndex) {
        final row = layout.grid[rowIndex];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: rowIndex < layout.grid.length - 1 ? 2 : 0),
            child: Row(
              children: List.generate(row.length, (colIndex) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(
                        right: colIndex < row.length - 1 ? 2 : 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSpacingPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: [
        Row(children: [
          Text('Spacing',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const Spacer(),
          Text('${_spacing.toStringAsFixed(0)}px',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: AppTheme.accentCyan)),
        ]),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: AppTheme.primaryPurple,
              inactiveTrackColor: Colors.white.withAlpha(15),
              thumbColor: AppTheme.primaryPurple,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _spacing,
              min: 0,
              max: 24,
              onChanged: (v) => setState(() => _spacing = v),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCornerPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(children: [
        Row(children: [
          Text('Rounded Corners',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const Spacer(),
          Text('${_cornerRadius.toStringAsFixed(0)}px',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11, color: AppTheme.accentCyan)),
        ]),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              activeTrackColor: const Color(0xFFE040FB),
              inactiveTrackColor: Colors.white.withAlpha(15),
              thumbColor: const Color(0xFFE040FB),
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: _cornerRadius,
              min: 0,
              max: 40,
              onChanged: (v) => setState(() => _cornerRadius = v),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildColorPanel() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(children: [
        // Solid colors
        ...List.generate(_solidColors.length, (i) {
          final color = _solidColors[i];
          final isSelected = _selectedGradient < 0 && _backgroundColor == color;
          return GestureDetector(
            onTap: () => setState(() {
              _backgroundColor = color;
              _selectedGradient = -1;
            }),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryPurple
                        : Colors.white.withAlpha(20),
                    width: isSelected ? 2.5 : 1),
              ),
              child: isSelected
                  ? const Center(
                      child:
                          Icon(Icons.check, color: Colors.white, size: 18))
                  : null,
            ),
          );
        }),
        Container(
            width: 1,
            height: 30,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withAlpha(15)),
        // Gradients
        ...List.generate(_gradients.length, (i) {
          final isSelected = _selectedGradient == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedGradient = i),
            child: Container(
              width: 44,
              height: 44,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: _gradients[i],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryPurple
                        : Colors.white.withAlpha(20),
                    width: isSelected ? 2.5 : 1),
              ),
              child: isSelected
                  ? const Center(
                      child:
                          Icon(Icons.check, color: Colors.white, size: 18))
                  : null,
            ),
          );
        }),
      ]),
    );
  }

  Widget _buildRatioPanel() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _ratios.length,
      itemBuilder: (_, i) {
        final ratio = _ratios[i];
        final isSelected = _selectedRatio == i;
        return GestureDetector(
          onTap: () => setState(() => _selectedRatio = i),
          child: Container(
            width: 56,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryPurple.withAlpha(25)
                  : AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryPurple
                      : Colors.white.withAlpha(15),
                  width: isSelected ? 2 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ratio preview
                Container(
                  width: 24,
                  height: ratio.value > 0
                      ? (24 / ratio.value).clamp(16.0, 30.0)
                      : 24.0,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : AppTheme.textMuted,
                        width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(ratio.label,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : AppTheme.textMuted)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Models ───

class _SlotData {
  Uint8List? imageBytes;
  double? freestyleX;
  double? freestyleY;
  double? freestyleW;
  double? freestyleH;
}

class _CollageLayout {
  final String name;
  final int photoCount;
  final List<List<int>> grid;
  _CollageLayout(this.name, this.photoCount, this.grid);
}

class _AspectRatio {
  final String label;
  final double value;
  const _AspectRatio(this.label, this.value);
}
