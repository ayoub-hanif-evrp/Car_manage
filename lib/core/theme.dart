import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium daylight driver theme for My Logan.
class LoganTheme {
  LoganTheme._();

  static const ink = Color(0xFF12151A);
  static const stone = Color(0xFFEEF1F4);
  static const paper = Color(0xFFFFFFFF);
  static const accent = Color(0xFF0E6B5C);
  static const accentSoft = Color(0xFFD8EBE6);
  static const muted = Color(0xFF5C6570);
  static const caution = Color(0xFFB45309);
  static const cautionSoft = Color(0xFFFFF3E6);
  static const routeAlt = Color(0xFF7A8794);
  static const danger = Color(0xFF9B2C2C);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      primary: accent,
      onPrimary: paper,
      surface: stone,
      onSurface: ink,
      secondary: accentSoft,
      onSecondary: ink,
      error: danger,
    );

    final display = GoogleFonts.soraTextTheme().apply(
      bodyColor: ink,
      displayColor: ink,
    );
    final body = GoogleFonts.ibmPlexSansTextTheme().apply(
      bodyColor: ink,
      displayColor: ink,
    );

    final textTheme = body.copyWith(
      displayLarge: display.displayLarge?.copyWith(fontWeight: FontWeight.w600),
      displayMedium: display.displayMedium?.copyWith(fontWeight: FontWeight.w600),
      displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w600),
      headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
      headlineMedium:
          display.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: display.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: display.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: stone,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: stone,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: paper,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: paper,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: textTheme.titleSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: Color(0xFFD5DBE2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD5DBE2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD5DBE2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: accentSoft,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.ibmPlexSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: ink,
          ),
        ),
        elevation: 0,
        height: 68,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paper,
        selectedColor: accentSoft,
        labelStyle: GoogleFonts.ibmPlexSans(fontSize: 13, color: ink),
        side: const BorderSide(color: Color(0xFFD5DBE2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerColor: const Color(0xFFD5DBE2),
    );
  }
}
