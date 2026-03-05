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
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, color: onSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
    );

    return _buildTheme(colorScheme: colorScheme, textTheme: textTheme, isDark: false);
  }

  static ThemeData get dark {
    const darkSurface = Color(0xFF1A1A1A);
    const darkCard = Color(0xFF242424);
    const darkOnSurface = Color(0xFFE8E8E8);
    const darkOnSurfaceVariant = Color(0xFFAAAAAA);

    final colorScheme = ColorScheme.dark(
      primary: primaryLight,           // lighter green reads well on dark
      primaryContainer: primary,
      secondary: const Color(0xFF26A69A),
      secondaryContainer: const Color(0xFF00695C),
      surface: darkSurface,
      surfaceContainerHighest: const Color(0xFF2C2C2C),
      onPrimary: onPrimary,
      onSurface: darkOnSurface,
      onSurfaceVariant: darkOnSurfaceVariant,
      outline: const Color(0xFF3A3A3A),
    );

    final base = GoogleFonts.poppinsTextTheme();
    final textTheme = TextTheme(
      headlineMedium: base.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.bold, color: darkOnSurface),
      titleLarge: base.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w600, color: darkOnSurface),
      titleMedium: base.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: darkOnSurface),
      titleSmall: base.titleSmall?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: darkOnSurface),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: 16, color: darkOnSurface),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, color: darkOnSurface),
      bodySmall: base.bodySmall?.copyWith(fontSize: 12, color: darkOnSurfaceVariant),
      labelLarge: base.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: darkOnSurface),
    );

    return _buildTheme(
      colorScheme: colorScheme,
      textTheme: textTheme,
      isDark: true,
      cardColor: darkCard,
      inputFill: darkCard,
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required bool isDark,
    Color? cardColor,
    Color? inputFill,
  }) {
    final effectiveCard = cardColor ?? surface;
    final effectiveInput = inputFill ?? surface;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : background,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: onPrimary,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        color: effectiveCard,
        elevation: isDark ? 0 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isDark ? BorderSide(color: const Color(0xFF3A3A3A), width: 0.5) : BorderSide.none,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: effectiveInput,
      ),
    );
  }
}
