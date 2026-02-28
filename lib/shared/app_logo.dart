import 'package:flutter/material.dart';

/// In-app logo asset. Use on splash, header, about.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(Icons.sports_soccer, size: size, color: Theme.of(context).colorScheme.primary),
    );
  }
}
