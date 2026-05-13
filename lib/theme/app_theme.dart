import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF075E54);
  static const Color accent = Color(0xFF25D366);
  static const Color background = Color(0xFF111B21);
  static const Color chatBubbleMine = Color(0xFF005C4B);
  static const Color chatBubbleOther = Color(0xFF202C33);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,

    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: accent,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      elevation: 0,
    ),
  );
}