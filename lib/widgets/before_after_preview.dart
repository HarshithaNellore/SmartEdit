import 'dart:typed_data';
import 'package:flutter/material.dart';

class BeforeAfterPreview extends StatefulWidget {
  final Uint8List originalBytes;
  final String processedUrl;

  const BeforeAfterPreview({
    Key? key,
    required this.originalBytes,
    required this.processedUrl,
  }) : super(key: key);

  @override
  State<BeforeAfterPreview> createState() => _BeforeAfterPreviewState();
}

class _BeforeAfterPreviewState extends State<BeforeAfterPreview> {
  double _position = 0.5;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _position += details.delta.dx / constraints.maxWidth;
                  _position = _position.clamp(0.0, 1.0);
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Processed image (bottom layer, right side visible)
                  Image.network(
                    widget.processedUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                  // Original image (top layer, left side visible)
                  ClipRect(
                    clipper: _BeforeAfterClipper(_position),
                    child: Image.memory(
                      widget.originalBytes,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Slider handle
                  Positioned(
                    left: constraints.maxWidth * _position - 1.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      color: Colors.white,
                      child: Center(
                        child: Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: const Icon(Icons.compare_arrows, size: 20, color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                  // Labels
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _buildLabel('Original'),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _buildLabel('Result'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _BeforeAfterClipper extends CustomClipper<Rect> {
  final double position;
  _BeforeAfterClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_BeforeAfterClipper oldClipper) {
    return oldClipper.position != position;
  }
}
