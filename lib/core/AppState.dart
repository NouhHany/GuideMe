import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppState extends ChangeNotifier {
  bool _isDarkMode = false;
  String _languageCode = 'en';
  String? _audioGuideLanguage;

  bool get isDarkMode => _isDarkMode;

  String get languageCode => _languageCode;

  String? get audioGuideLanguage => _audioGuideLanguage;

  AppState() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _languageCode = prefs.getString('languageCode') ?? 'en';
    _audioGuideLanguage = prefs.getString('audioGuideLanguage') ?? 'en';
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setLanguageCode(String value) async {
    _languageCode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', value);
    notifyListeners();
  }

  Future<void> setAudioGuideLanguage(String value) async {
    _audioGuideLanguage = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audioGuideLanguage', value);
    notifyListeners();
  }
}
