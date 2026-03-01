import 'package:flutter/material.dart';

/// Background layer: surface colour with Design 1 pattern as subtle corner accents.
/// Keeps centre clear for content (hierarchy, restraint). Uses theme colours.
class TexturedBackground extends StatelessWidget {
  const TexturedBackground({super.key});

  static const String _patternAsset = 'assets/background_pattern_1.png';

  /// Opacity for pattern (keeps it secondary to content).
  static const double _patternOpacity = 0.12;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            ColoredBox(color: scheme.surface),
            // Full-screen pattern layer so the PNG is visible on all screens.
            Positioned.fill(
              child: _CornerPattern(asset: _patternAsset, opacity: _patternOpacity),
            ),
          ],
        );
      },
    );
  }
}

class _CornerPattern extends StatelessWidget {
  const _CornerPattern({required this.asset, required this.opacity});

  final String asset;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
