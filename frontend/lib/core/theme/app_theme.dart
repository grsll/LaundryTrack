import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryBlue = Color(0xFF1E6091);
  static const Color primaryLight = Color(0xFF1A759F);
  static const Color primaryDark = Color(0xFF184E77);
  static const Color accentCyan = Color(0xFF52B69A);
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningOrange = Color(0xFFED6C02);
  static const Color errorRed = Color(0xFFD32F2F);

  // Neutral Backgrounds & Surfaces
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFE9ECEF);
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentCyan,
        surface: surfaceWhite,
        error: errorRed,
      ),
      scaffoldBackgroundColor: backgroundLight,
      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: surfaceMuted, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      fontFamily: 'Inter',
    );
  }
}
