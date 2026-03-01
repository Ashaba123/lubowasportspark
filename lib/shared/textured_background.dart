import 'package:flutter/material.dart';

/// Background layer: surface colour with Design 1 pattern as subtle corner accents.
/// Keeps centre clear for content (hierarchy, restraint). Uses theme colours.
class TexturedBackground extends StatelessWidget {
  const TexturedBackground({super.key});

  static const String _patternAsset = 'assets/background_pattern_1.png';

  /// Opacity for corner pattern (0.08–0.15 keeps it secondary to content).
  static const double _patternOpacity = 0.12;

  /// Corner tile size (px). Restraint: small accents, not full coverage.
  static const double _cornerSize = 100;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // Base: solid surface so content area is clean and readable.
        ColoredBox(color: scheme.surface),
        // Corner accents only; centre stays empty for breathing room.
        Positioned(
          top: 0,
          left: 0,
          width: _cornerSize,
          height: _cornerSize,
          child: _CornerPattern(asset: _patternAsset, opacity: _patternOpacity),
        ),
        Positioned(
          top: 0,
          right: 0,
          width: _cornerSize,
          height: _cornerSize,
          child: _CornerPattern(asset: _patternAsset, opacity: _patternOpacity, flipHorizontal: true),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          width: _cornerSize,
          height: _cornerSize,
          child: _CornerPattern(asset: _patternAsset, opacity: _patternOpacity, flipVertical: true),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          width: _cornerSize,
          height: _cornerSize,
          child: _CornerPattern(
            asset: _patternAsset,
            opacity: _patternOpacity,
            flipHorizontal: true,
            flipVertical: true,
          ),
        ),
      ],
    );
  }
}

class _CornerPattern extends StatelessWidget {
  const _CornerPattern({
    required this.asset,
    required this.opacity,
    this.flipHorizontal = false,
    this.flipVertical = false,
  });

  final String asset;
  final double opacity;
  final bool flipHorizontal;
  final bool flipVertical;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
        child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          flipHorizontal ? -1.0 : 1.0,
          flipVertical ? -1.0 : 1.0,
          1.0,
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          width: TexturedBackground._cornerSize,
          height: TexturedBackground._cornerSize,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
