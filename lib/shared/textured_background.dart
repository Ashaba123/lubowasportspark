import 'package:flutter/material.dart';

/// Full-screen background: surface colour with a subtle staggered dot-grid
/// drawn via CustomPainter. Eliminates the PNG asset dependency while keeping
/// the decorative pattern subordinate to content (opacity ~8%).
class TexturedBackground extends StatelessWidget {
  const TexturedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    return ColoredBox(
      color: surface,
      child: CustomPaint(
        painter: _DotGridPainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});

  final Color color;

  static const double _spacing = 28.0;
  static const double _radius = 1.5;
  static const double _opacity = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: _opacity)
      ..style = PaintingStyle.fill;

    final cols = (size.width / _spacing).ceil() + 1;
    final rows = (size.height / _spacing).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      // Stagger odd rows by half a cell for a hex-like grid
      final xOffset = row.isOdd ? _spacing / 2 : 0.0;
      for (int col = 0; col < cols; col++) {
        canvas.drawCircle(
          Offset(col * _spacing + xOffset, row * _spacing),
          _radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
