import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleState extends ChangeNotifier {
  Locale _currentLocale = const Locale('ko', 'KR');

  Locale get currentLocale => _currentLocale;

  Future<void> loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString('selected_locale') ?? 'ko';
    _currentLocale = savedLocale == 'en'
        ? const Locale('en', 'US')
        : const Locale('ko', 'KR');
    notifyListeners();
  }

  Future<void> changeLocale(Locale newLocale) async {
    _currentLocale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_locale', newLocale.languageCode);
    notifyListeners();
  }

  void toggleLocale() {
    final newLocale = _currentLocale.languageCode == 'ko'
        ? const Locale('en', 'US')
        : const Locale('ko', 'KR');
    changeLocale(newLocale);
  }
}
