import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme aligned with docs/DESIGN_SYSTEM.md — Lubowa Sports Park.
/// Typography: Poppins (single family for cross-platform consistency).
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF4CAF50);
  static const Color secondary = Color(0xFF00897B);
  static const Color accentBlue = Color(0xFF03A9F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5F5F5);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF212121);
  static const Color onSurfaceVariant = Color(0xFF757575);
  static const Color outline = Color(0xFFE0E0E0);

  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: primary,
      primaryContainer: primaryLight,
      secondary: secondary,
      secondaryContainer: accentBlue,
      surface: surface,
      surfaceContainerHighest: background,
      onPrimary: onPrimary,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
    );

    final base = GoogleFonts.poppinsTextTheme();
    final textTheme = TextTheme(
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.bold, color: onSurface),
      titleLarge: base.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: onSurface),
      titleMedium: base.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall: base.titleSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, color: onSurface),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, color: onSurface),
      bodySmall: base.bodySmall?.copyWith(fontSize: 14, color: onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: surface,
      ),
    );
  }
}
