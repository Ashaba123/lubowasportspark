import 'dart:ui';

import 'package:flutter/material.dart';

/// Glassmorphism container: backdrop blur + semi-transparent fill + border.
/// Use sparingly (e.g. nav bar, one card per screen) for performance.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius,
    this.borderWidth = 1,
    this.blurSigma = 10,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double borderWidth;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(12);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.25),
            borderRadius: radius,
            border: Border.all(
              color: scheme.outline.withValues(alpha: 0.4),
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
