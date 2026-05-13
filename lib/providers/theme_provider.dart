import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  bool isDark = true;
  Color primaryColor = AppColors.accentGreen;
  double chatFontSize = 16.0;
  bool showTimestamps = true;
  bool compactMode = false;

  final List<Color> availableColors = AppColors.accentPalette;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDark = prefs.getBool('isDark') ?? true;
    final colorValue = prefs.getInt('themeColor') ?? AppColors.accentGreen.value;
    primaryColor = Color(colorValue);
    chatFontSize = prefs.getDouble('chatFontSize') ?? 16.0;
    showTimestamps = prefs.getBool('showTimestamps') ?? true;
    compactMode = prefs.getBool('compactMode') ?? false;
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
    await prefs.setInt('themeColor', color.value);
    notifyListeners();
  }

  Future<void> setChatFontSize(double size) async {
    chatFontSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('chatFontSize', size);
    notifyListeners();
  }

  Future<void> setShowTimestamps(bool value) async {
    showTimestamps = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showTimestamps', value);
    notifyListeners();
  }

  Future<void> setCompactMode(bool value) async {
    compactMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('compactMode', value);
    notifyListeners();
  }

  ThemeData get theme => isDark
      ? AppTheme.dark(primaryColor)
      : AppTheme.light(primaryColor);
}
