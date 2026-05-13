import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool isDark = true;

  Color primaryColor = const Color(0xFF25D366);

  final List<Color> availableColors = const [
    Color(0xFF25D366),
    Color(0xFF0A84FF),
    Color(0xFFFF9500),
    Color(0xFFFF2D55),
    Color(0xFFAF52DE),
  ];

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    isDark = prefs.getBool('isDark') ?? true;

    final colorValue = prefs.getInt('themeColor') ??
        const Color(0xFF25D366).value;

    primaryColor = Color(colorValue);

    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    isDark = value;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isDark', value);

    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    primaryColor = color;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      'themeColor',
      color.value,
    );

    notifyListeners();
  }

  ThemeData get theme {
    return ThemeData(
      brightness:
          isDark ? Brightness.dark : Brightness.light,

      primaryColor: primaryColor,

      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0B141A)
          : const Color(0xFFF2F2F7),

      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? Colors.black : Colors.white,

        foregroundColor:
            isDark ? Colors.white : Colors.black,

        elevation: 0.5,
      ),

      floatingActionButtonTheme:
          FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
      ),

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: isDark
            ? Brightness.dark
            : Brightness.light,
      ),
    );
  }
}