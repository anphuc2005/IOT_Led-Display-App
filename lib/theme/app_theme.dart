import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const backgroundDark = Color(0xFF0F172A);
  static const surfaceDark = Color(0xFF1E293B);
  static const cardDark = Color(0xFF1B2336);
  static const borderDark = Color(0xFF475569);
  static const accent = Color(0xFF22C55E);
  static const info = Color(0xFF38BDF8);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double pagePadding = 20;

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme.dark(
          primary: accent,
          onPrimary: Color(0xFF052E16),
          secondary: info,
          onSecondary: Color(0xFF082F49),
          surface: surfaceDark,
          onSurface: Color(0xFFF8FAFC),
          error: danger,
          onError: Colors.white,
          outline: borderDark,
          surfaceContainer: cardDark,
          surfaceContainerHigh: Color(0xFF263449),
        ),
        scaffold: backgroundDark,
      );

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme.light(
          primary: Color(0xFF15803D),
          onPrimary: Colors.white,
          secondary: Color(0xFF0369A1),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
          error: Color(0xFFB91C1C),
          onError: Colors.white,
          outline: Color(0xFFCBD5E1),
          surfaceContainer: Color(0xFFF1F5F9),
          surfaceContainerHigh: Color(0xFFE2E8F0),
        ),
        scaffold: const Color(0xFFF8FAFC),
      );

  static ThemeData _build(
      {required Brightness brightness,
      required ColorScheme scheme,
      required Color scaffold}) {
    final base = ThemeData(
        brightness: brightness, useMaterial3: true, colorScheme: scheme);
    final textTheme =
        GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28, fontWeight: FontWeight.w700, color: scheme.onSurface),
      headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
      titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurface),
      titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
      bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16, height: 1.5, color: scheme.onSurface),
      bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14, height: 1.45, color: scheme.onSurface),
      labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w700),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(color: scheme.outline.withValues(alpha: .65)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: .18),
        labelTextStyle: WidgetStatePropertyAll(
            textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: BorderSide(color: scheme.error)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            minimumSize: const Size(48, 48), maximumSize: const Size(48, 48)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm)),
      ),
    );
  }
}
