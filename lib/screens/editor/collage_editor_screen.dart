import 'dart:typed_data';
import 'dart:ui' as ui;
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

class _CollageEditorScreenState extends State<CollageEditorScreen> {
  final ImagePicker _picker = ImagePicker();
  List<Uint8List?> _photos = [];
  int _selectedLayout = 0;
  Color _backgroundColor = Colors.black;
  double _spacing = 4.0;
  int? _selectedPhotoIndex;
  final GlobalKey _repaintKey = GlobalKey();
  int? _selectedPhotoCount;

  final List<_CollageLayout> _allLayouts = [
    _CollageLayout('2x2 Grid', 4, [[0, 1], [2, 3]]),
    _CollageLayout('1x3 (Vertical)', 3, [[0], [1], [2]]),
    _CollageLayout('3x1 (Horizontal)', 3, [[0, 1, 2]]),
    _CollageLayout('Top Large', 4, [[0, 0], [1, 2]]),
    _CollageLayout('Bottom Large', 4, [[0, 1], [2, 2]]),
    _CollageLayout('3x3 Grid', 9, [[0, 1, 2], [3, 4, 5], [6, 7, 8]]),
    _CollageLayout('2x3 Grid', 6, [[0, 1], [2, 3], [4, 5]]),
    _CollageLayout('Classic (Left Big)', 4, [[0, 0], [1, 2]]),
    _CollageLayout('2 Split Vertical', 2, [[0], [1]]),
    _CollageLayout('5 Grid', 5, [[0, 1], [2, 3, 4]]),
  ];

  List<_CollageLayout> get _availableLayouts {
    if (_selectedPhotoCount == null) return [];
    return _allLayouts
        .where((layout) => layout.photoCount == _selectedPhotoCount)
        .toList();
  }

  @override
  void initState() {
    super.initState();
  }

  void _selectPhotoCount(int count) {
    setState(() {
      _selectedPhotoCount = count;
      _selectedLayout = 0;
      _photos = List<Uint8List?>.filled(count, null);
    });
  }

  Future<void> _addPhoto(int index) async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() => _photos[index] = bytes);
    }
  }

  void _selectLayout(int index) {
    setState(() => _selectedLayout = index);
  }

  Future<void> _exportCollage() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Collage saved! (${pngBytes.length ~/ 1024} KB)',
              style: GoogleFonts.inter(fontSize: 13)),
          backgroundColor: AppTheme.darkCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting collage: $e')),
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
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(children: [
                        _buildCollagePreview(),
                        const SizedBox(height: 24),
                        _buildSpacingControl(),
                        const SizedBox(height: 24),
                        _buildColorPicker(),
                        const SizedBox(height: 24),
                        _buildLayoutSelector(),
                        const SizedBox(height: 24),
                      ]),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _buildPhotoCountSelector() {
    final photoCounts = [2, 3, 4, 5, 6, 9];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new,
                    color: AppTheme.textPrimary, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Collage Maker',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Text('Select number of photos',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppTheme.textMuted)),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How many photos?',
                          style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 8),
                      Text('Choose the number of photos you want to include',
                          style: GoogleFonts.inter(
                              fontSize: 14, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: photoCounts.length,
                  itemBuilder: (context, index) {
                    final count = photoCounts[index];
                    final availableCount = _allLayouts
                        .where((l) => l.photoCount == count)
                        .length;

                    return GestureDetector(
                      onTap: () => _selectPhotoCount(count),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryPurple.withAlpha(150),
                              AppTheme.primaryPurple.withAlpha(80),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withAlpha(30), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withAlpha(60),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              count.toString(),
                              style: GoogleFonts.outfit(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text('Photos',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text(
                              '$availableCount layout${availableCount != 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white60),
                            ),
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
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => setState(() => _selectedPhotoCount = null),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: AppTheme.textPrimary, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Collage Maker',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            Text('${_photos.where((p) => p != null).length}/$_selectedPhotoCount',
                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
          ]),
        ),
        GestureDetector(
          onTap: _exportCollage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('Export',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  Widget _buildCollagePreview() {
    final layout = _availableLayouts[_selectedLayout];

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Preview',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          Text('${layout.name}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
        ]),
      ),
      const SizedBox(height: 12),
      RepaintBoundary(
        key: _repaintKey,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: _backgroundColor,
          child: _buildCollageGrid(layout),
        ),
      ),
    ]);
  }

  Widget _buildCollageGrid(_CollageLayout layout) {
    return Padding(
      padding: EdgeInsets.all(_spacing),
      child: Column(
        children: List.generate(layout.grid.length, (rowIndex) {
          final row = layout.grid[rowIndex];
          return Padding(
            padding: EdgeInsets.only(
                bottom: rowIndex < layout.grid.length - 1 ? _spacing : 0),
            child: Row(
              children: List.generate(row.length, (colIndex) {
                final photoIndex = row[colIndex];
                final isSelected = _selectedPhotoIndex == photoIndex;

                return Expanded(
                  flex: 1,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPhotoIndex = photoIndex),
                    onDoubleTap: () => _addPhoto(photoIndex),
                    onLongPress: () => _removePhoto(photoIndex),
                    child: Container(
                      height: 150,
                      margin: EdgeInsets.only(
                        right: colIndex < row.length - 1 ? _spacing : 0,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkCard,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryPurple
                              : Colors.white.withAlpha(20),
                          width: isSelected ? 3 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _photos[photoIndex] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(fit: StackFit.expand, children: [
                                Image.memory(_photos[photoIndex]!,
                                    fit: BoxFit.cover),
                                if (isSelected)
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.check,
                                          color: Colors.white, size: 24),
                                    ),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removePhoto(photoIndex),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withAlpha(220),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ]))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate,
                                    color: AppTheme.primaryPurple, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to add\nDouble-tap to replace',
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AppTheme.textMuted),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() {
      _photos[index] = null;
      _selectedPhotoIndex = null;
    });
  }

  Widget _buildSpacingControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Spacing',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          Text('${_spacing.toStringAsFixed(1)}px',
              style:
                  GoogleFonts.inter(fontSize: 11, color: AppTheme.textMuted)),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            activeTrackColor: AppTheme.primaryPurple,
            inactiveTrackColor: Colors.white.withAlpha(20),
          ),
          child: Slider(
            value: _spacing,
            min: 0,
            max: 20,
            onChanged: (value) => setState(() => _spacing = value),
          ),
        ),
      ]),
    );
  }

  Widget _buildColorPicker() {
    final colors = [
      Colors.black,
      Colors.white,
      Colors.grey[800]!,
      const Color(0xFF1a1a2e),
      const Color(0xFF0f3460),
      const Color(0xFF533483),
      const Color(0xFFc9184a),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Background Color',
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: colors.length,
            itemBuilder: (context, index) {
              final color = colors[index];
              final isSelected = _backgroundColor == color;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => setState(() => _backgroundColor = color),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : Colors.white.withAlpha(30),
                        width: isSelected ? 3 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check,
                                color: Colors.white, size: 24),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildLayoutSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Layout',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text('${_availableLayouts.length} layouts available',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: _availableLayouts.length > 4
            ? 240
            : 120,
        child: GridView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
          ),
          itemCount: _availableLayouts.length,
          itemBuilder: (context, index) {
            final layout = _availableLayouts[index];
            final isSelected = _selectedLayout == index;

            return GestureDetector(
              onTap: () => _selectLayout(index),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryPurple
                        : Colors.white.withAlpha(20),
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _buildLayoutPreview(layout),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryPurple.withAlpha(30)
                          : Colors.transparent,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(layout.name,
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primaryPurple
                                  : AppTheme.textMuted),
                          textAlign: TextAlign.center),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _buildLayoutPreview(_CollageLayout layout) {
    const spacer = 2.0;

    return Column(
      children: List.generate(layout.grid.length, (rowIndex) {
        final row = layout.grid[rowIndex];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                bottom: rowIndex < layout.grid.length - 1 ? spacer : 0),
            child: Row(
              children: List.generate(row.length, (colIndex) {
                return Expanded(
                  flex: 1,
                  child: Container(
                    margin: EdgeInsets.only(
                      right: colIndex < row.length - 1 ? spacer : 0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(4),
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
}

class _CollageLayout {
  final String name;
  final int photoCount;
  final List<List<int>> grid;

  _CollageLayout(this.name, this.photoCount, this.grid);
}
