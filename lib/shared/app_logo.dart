import 'package:flutter/material.dart';

/// In-app logo asset. Use on splash, header, about.
///
/// [removeWhiteBg] applies [BlendMode.multiply] so that the logo's white
/// background disappears when rendered on any non-white surface (e.g. the
/// green gradient splash screen). Safe to enable whenever the background is
/// not plain white.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 120, this.removeWhiteBg = false});

  final double size;
  final bool removeWhiteBg;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: removeWhiteBg ? Colors.white : null,
      colorBlendMode: removeWhiteBg ? BlendMode.multiply : null,
      errorBuilder: (_, __, ___) => Icon(
        Icons.sports_soccer,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    return image;
  }
}
