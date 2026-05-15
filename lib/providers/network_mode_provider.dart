import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NetworkMode { lan, internet }

class NetworkModeProvider extends ChangeNotifier {
  static const _key = 'network_mode';

  NetworkMode _mode = NetworkMode.lan;

  NetworkMode get mode => _mode;
  bool get isLan => _mode == NetworkMode.lan;
  bool get isInternet => _mode == NetworkMode.internet;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'internet') {
      _mode = NetworkMode.internet;
    } else {
      _mode = NetworkMode.lan;
    }
    notifyListeners();
  }

  Future<void> setMode(NetworkMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == NetworkMode.internet ? 'internet' : 'lan');
    notifyListeners();
  }
}
