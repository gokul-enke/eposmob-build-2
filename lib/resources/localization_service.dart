import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static const String _prefsKey = 'app_locale_code';
  static const Locale fallbackLocale = Locale('en');

  static final List<Locale> supportedLocales = <Locale>[
    const Locale('en'),
    const Locale('ar'),
  ];

  static Locale _locale = fallbackLocale;
  static Map<String, Map<String, String>> _translations = {};

  static Locale get locale => _locale;
  static Map<String, Map<String, String>> get translations => _translations;

  static Future<void> init() async {
    // Translations first. They are what makes the UI readable, they depend on
    // nothing but the asset bundle, and init() runs inside a bounded startup
    // step — so anything that reads the preference store must come after them
    // or it can starve them of that budget and leave every screen showing raw
    // keys like "login.title".
    await _loadTranslations();
    await _loadSavedLocale();
  }

  /// The saved locale is a preference, not a prerequisite: guarded, bounded,
  /// and always falls back to [fallbackLocale].
  ///
  /// The timeout matters as much as the catch. A store that throws is easy;
  /// one that simply never answers would otherwise hang here for the whole
  /// startup budget.
  static Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 3));
      final savedCode = prefs.getString(_prefsKey);
      if (savedCode == null || savedCode.isEmpty) {
        return;
      }

      final savedLocale = _localeFromCode(savedCode);
      _locale = savedLocale ?? fallbackLocale;
      if (savedLocale == null) {
        await prefs.setString(_prefsKey, _codeFromLocale(fallbackLocale));
      }
    } catch (e) {
      _locale = fallbackLocale;
      debugPrint(
          'LocalizationService: could not read the saved locale, falling back '
          'to ${fallbackLocale.languageCode}: $e');
    }
  }

  /// Preloads every supported locale. Individual files degrade to an empty
  /// map inside _loadJsonMap, so one bad file cannot take the others down.
  static Future<void> _loadTranslations() async {
    final Map<String, Map<String, String>> loaded = {};
    for (final loc in supportedLocales) {
      final code = _codeFromLocale(loc);
      loaded[code] = await _loadJsonMap('lib/resources/i18n/$code.json');
    }
    _translations = loaded;
  }

  static Future<void> updateLocale(Locale newLocale) async {
    _locale = _localeFromCode(newLocale.languageCode) ?? fallbackLocale;

    // Switching language in the running app must work even when the store
    // cannot be written; the choice simply will not survive a restart.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _codeFromLocale(_locale));
    } catch (e) {
      debugPrint('LocalizationService: could not persist the locale: $e');
    }
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
      final Map<String, dynamic> jsonMap =
          json.decode(data) as Map<String, dynamic>;

      // Flatten nested JSON to dot notation
      return _flattenJson(jsonMap);
    } catch (_) {
      return <String, String>{};
    }
  }

  /// Flattens nested JSON to dot notation keys
  /// Example: {"billing": {"title": "Billing"}} -> {"billing.title": "Billing"}
  static Map<String, String> _flattenJson(Map<String, dynamic> json,
      [String prefix = '']) {
    final Map<String, String> result = {};

    json.forEach((key, value) {
      final newKey = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map<String, dynamic>) {
        // Recursively flatten nested objects
        result.addAll(_flattenJson(value, newKey));
      } else {
        // Convert value to string and store
        result[newKey] = value.toString();
      }
    });

    return result;
  }
}
