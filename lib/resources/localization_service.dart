import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static const String _prefsKey = 'app_locale_code';
  static const Locale fallbackLocale = Locale('en');

  static final List<Locale> supportedLocales = <Locale>[
    const Locale('en'),
    const Locale('hi'),
  ];

  static Locale _locale = fallbackLocale;
  static Map<String, Map<String, String>> _translations = {};

  static Locale get locale => _locale;
  static Map<String, Map<String, String>> get translations => _translations;

  static Future<void> init() async {
    // Load saved locale
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_prefsKey);
    if (savedCode != null && savedCode.isNotEmpty) {
      _locale = _localeFromCode(savedCode) ?? fallbackLocale;
    }

    // Preload all supported locale JSON files
    final Map<String, Map<String, String>> loaded = {};
    for (final loc in supportedLocales) {
      final code = _codeFromLocale(loc);
      final map = await _loadJsonMap('lib/resources/i18n/$code.json');
      loaded[code] = map;
    }
    _translations = loaded;
  }

  static Future<void> updateLocale(Locale newLocale) async {
    _locale = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _codeFromLocale(newLocale));
  }

  static String _codeFromLocale(Locale l) => l.languageCode;

  static Locale? _localeFromCode(String code) {
    try {
      return supportedLocales.firstWhere((l) => l.languageCode == code);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, String>> _loadJsonMap(String assetPath) async {
    try {
      final data = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonMap = json.decode(data) as Map<String, dynamic>;
      return jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }
}
