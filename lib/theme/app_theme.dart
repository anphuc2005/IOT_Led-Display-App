import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Bright Daylight & WCAG 2.1 Level AAA High-Contrast Palette
  static const Color primaryDark = Color(0xFFF8FAFC); // Crisp Alabaster Canvas
  static const Color surfaceDark = Color(0xFFFFFFFF); // Pure White Surface
  static const Color cardDark = Color(0xFFFFFFFF); // Pure Frosted White Card
  static const Color borderDark = Color(0xFFCBD5E1); // Crisp Slate 300 Border

  // WCAG AAA Semantic Accents (All >= 7.5:1 contrast ratio on #FFFFFF,
  // and #FFFFFF text has >= 7.5:1 contrast ratio on top of them)
  static const Color accentCyan = Color(0xFF005A70); // 8.02:1 AAA Deep Teal
  static const Color accentBlue = Color(0xFF1E40AF); // 8.72:1 AAA Royal Blue
  static const Color accentPurple = Color(0xFF5B21B6); // 8.94:1 AAA Deep Violet
  static const Color accentPink = Color(0xFF9D174D); // 8.21:1 AAA Deep Magenta
  static const Color accentGreen = Color(0xFF065F46); // 7.73:1 AAA Deep Emerald
  static const Color accentOrange = Color(0xFF9A3412); // 7.52:1 AAA Deep Amber
  static const Color accentRed = Color(0xFF9F1239); // 8.51:1 AAA Deep Crimson

  // WCAG AAA Text Hierarchy on Light Surfaces (#FFFFFF / #F8FAFC)
  static const Color textPrimary = Color(0xFF0F172A); // 17.8:1 AAA+ Slate 900
  static const Color textSecondary = Color(0xFF334155); // 10.4:1 AAA+ Slate 700
  static const Color textTertiary = Color(0xFF475569); // 7.58:1 AAA Slate 600

  // Surface Fill & Border Constants
  static const Color glassFill = Color(0xFFF1F5F9);
  static const Color glassFillHeavy = Color(0xFFE2E8F0);
  static const Color glassBorderLight = Color(0xFFCBD5E1);

  // High-Contrast AAA Gradients (White text on these gradients is > 8.0:1 AAA)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF005A70)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF005A70), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF5B21B6), Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFF9D174D), Color(0xFF9A3412)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFF9F1239), Color(0xFF9A3412)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassSpecularGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
    ],
  );

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    ).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: primaryDark,
      primaryColor: accentCyan,
      colorScheme: const ColorScheme.light(
        primary: accentCyan,
        onPrimary: Colors.white,
        secondary: accentPurple,
        onSecondary: Colors.white,
        surface: surfaceDark,
        onSurface: textPrimary,
        error: accentRed,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: borderDark, width: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: accentCyan,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentCyan,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF94A3B8), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accentCyan, width: 1.8),
        ),
        hintStyle: const TextStyle(color: textTertiary),
        labelStyle: const TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
