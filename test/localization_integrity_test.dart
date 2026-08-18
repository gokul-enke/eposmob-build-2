import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, String> _flatten(
  Map<String, dynamic> source, [
  String prefix = '',
]) {
  final result = <String, String>{};
  for (final entry in source.entries) {
    final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    final value = entry.value;
    if (value is Map<String, dynamic>) {
      result.addAll(_flatten(value, key));
    } else {
      result[key] = value.toString();
    }
  }
  return result;
}

Future<Map<String, String>> _loadLocale(String code) async {
  final raw = await rootBundle.loadString('lib/resources/i18n/$code.json');
  return _flatten(jsonDecode(raw) as Map<String, dynamic>);
}

Set<String> _placeholders(String value) {
  return RegExp(r'@[A-Za-z_][A-Za-z0-9_]*')
      .allMatches(value)
      .map((match) => match.group(0)!)
      .toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only English and Arabic are selectable application locales', () {
    expect(
      LocalizationService.supportedLocales,
      const [Locale('en'), Locale('ar')],
    );
  });

  test('unsupported saved locales migrate safely to English', () async {
    SharedPreferences.setMockInitialValues({
      'app_locale_code': 'hi',
    });

    await LocalizationService.init();

    expect(LocalizationService.locale, const Locale('en'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_locale_code'), 'en');
  });

  test('unsupported runtime locale updates are rejected safely', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalizationService.updateLocale(const Locale('ml'));

    expect(LocalizationService.locale, const Locale('en'));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('app_locale_code'), 'en');
  });

  test('English and Arabic resources have identical, non-empty keys', () async {
    final english = await _loadLocale('en');
    final arabic = await _loadLocale('ar');

    expect(arabic.keys.toSet().difference(english.keys.toSet()), isEmpty);
    expect(english.keys.toSet().difference(arabic.keys.toSet()), isEmpty);
    expect(
      english.entries.where((entry) => entry.value.trim().isEmpty),
      isEmpty,
    );
    expect(
      arabic.entries.where((entry) => entry.value.trim().isEmpty),
      isEmpty,
    );
  });

  test('English and Arabic interpolation placeholders match', () async {
    final english = await _loadLocale('en');
    final arabic = await _loadLocale('ar');

    for (final key in english.keys) {
      expect(
        _placeholders(arabic[key]!),
        _placeholders(english[key]!),
        reason: 'placeholder mismatch for $key',
      );
    }
  });

  test('Arabic resources contain no replacement question-mark runs', () async {
    final arabic = await _loadLocale('ar');
    final corrupted = arabic.entries
        .where((entry) => RegExp(r'\?{3,}').hasMatch(entry.value))
        .map((entry) => entry.key)
        .toList();

    expect(corrupted, isEmpty);
  });

  test('every static translation reference exists in both locales', () async {
    final english = await _loadLocale('en');
    final arabic = await _loadLocale('ar');
    final staticReference = RegExp(
      r'''[\'\"]([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+)[\'\"]\.tr(?:Params)?''',
    );
    final referencedKeys = <String>{};

    await for (final entity in Directory('lib').list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = await entity.readAsString();
      referencedKeys.addAll(
        staticReference.allMatches(source).map((match) => match.group(1)!),
      );
    }

    expect(referencedKeys.difference(english.keys.toSet()), isEmpty);
    expect(referencedKeys.difference(arabic.keys.toSet()), isEmpty);
  });
}
