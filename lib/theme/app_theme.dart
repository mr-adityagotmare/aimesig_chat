import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  // Dark palette
  static const darkBg = Color(0xFF0D0F14);
  static const darkSurface = Color(0xFF161922);
  static const darkCard = Color(0xFF1E2330);
  static const darkElevated = Color(0xFF252C3D);
  static const darkBorder = Color(0xFF2C3349);

  // Light palette
  static const lightBg = Color(0xFFF5F6FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF0F2F8);
  static const lightElevated = Color(0xFFE8EBF5);
  static const lightBorder = Color(0xFFDDE1EF);

  // Accent palettes
  static const accentGreen = Color(0xFF00D4AA);
  static const accentBlue = Color(0xFF4D8EFF);
  static const accentPurple = Color(0xFF9B6DFF);
  static const accentOrange = Color(0xFFFF7A3D);
  static const accentRose = Color(0xFFFF4D7E);
  static const accentCyan = Color(0xFF00C4D4);

  static const List<Color> accentPalette = [
    accentGreen,
    accentBlue,
    accentPurple,
    accentOrange,
    accentRose,
    accentCyan,
  ];

  static Color textPrimary(bool dark) =>
      dark ? const Color(0xFFEEF0F8) : const Color(0xFF1A1D2E);

  static Color textSecondary(bool dark) =>
      dark ? const Color(0xFF7A8099) : const Color(0xFF6B7080);

  static Color textMuted(bool dark) =>
      dark ? const Color(0xFF4A506A) : const Color(0xFF9EA6BA);
}

class AppTheme {
  static ThemeData dark(Color accent) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: accent,
      fontFamily: 'SF Pro Display',
      colorScheme: ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: AppColors.darkSurface,
        background: AppColors.darkBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.textPrimary(true)),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary(true),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.darkBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: AppColors.textMuted(true)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }

  static ThemeData light(Color accent) {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: accent,
      fontFamily: 'SF Pro Display',
      colorScheme: ColorScheme.light(
        primary: accent,
        secondary: accent,
        surface: AppColors.lightSurface,
        background: AppColors.lightBg,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.textPrimary(false)),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary(false),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.lightBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: AppColors.textMuted(false)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}
