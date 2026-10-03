import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

/// The app's real English strings (`lib/resources/i18n/en.json`), for
/// `GetMaterialApp(translations: EnglishTranslations(), locale: Locale('en'))`.
class EnglishTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys {
    final flat = <String, String>{};
    void flatten(Map<String, dynamic> data, String prefix) {
      for (final entry in data.entries) {
        final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
        if (entry.value is Map<String, dynamic>) {
          flatten(entry.value as Map<String, dynamic>, key);
        } else {
          flat[key] = entry.value.toString();
        }
      }
    }

    flatten(
        jsonDecode(File('lib/resources/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>,
        '');
    return {'en': flat};
  }
}

/// The `section` object of the `lang` bundle (`en`, `ar`, `ml`).
Map<String, dynamic> translationSection(String lang, String section) =>
    (jsonDecode(File('lib/resources/i18n/$lang.json').readAsStringSync())
        as Map<String, dynamic>)[section] as Map<String, dynamic>;
