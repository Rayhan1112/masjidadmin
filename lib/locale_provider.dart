
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? _locale;

  Locale? get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  void _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('languageCode');
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  void setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (!L10n.all.contains(locale)) return;
    _locale = locale;
    await prefs.setString('languageCode', locale.languageCode);
    notifyListeners();
  }
}

class L10n {
  static final all = [
    const Locale('en'),
    const Locale('hi'),
    const Locale('mr'),
  ];
}
