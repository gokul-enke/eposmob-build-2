import 'dart:convert';
import 'dart:io';

import 'package:pos_machine/resources/localization_service.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, String> _loadAndFlatten(String path) {
  final source = File(path).readAsStringSync();
  final decoded = jsonDecode(source) as Map<String, dynamic>;
  final flattened = <String, String>{};

  void visit(Map<String, dynamic> values, String prefix) {
    for (final entry in values.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        visit(value, key);
      } else {
        flattened[key] = value.toString();
      }
    }
  }

  visit(decoded, '');
  return flattened;
}

Set<String> _duplicateTopLevelNamespaces(String path) {
  final source = File(path).readAsStringSync();
  final namespacePattern = RegExp(r'^  "([^"]+)": \{$', multiLine: true);
  final seen = <String>{};
  final duplicates = <String>{};

  for (final match in namespacePattern.allMatches(source)) {
    final namespace = match.group(1)!;
    if (!seen.add(namespace)) duplicates.add(namespace);
  }

  return duplicates;
}

void main() {
  group('localization resources', () {
    final locales = LocalizationService.supportedLocales
        .map((locale) => locale.languageCode)
        .toList();
    const referenceCode = 'en';

    final bundles = {
      for (final code in locales)
        code: _loadAndFlatten('lib/resources/i18n/$code.json'),
    };

    test('every supported locale exposes the same translation keys as English',
        () {
      final referenceKeys = bundles[referenceCode]!.keys.toSet();

      for (final code in locales) {
        if (code == referenceCode) continue;
        final keys = bundles[code]!.keys.toSet();
        final missing = referenceKeys.difference(keys);
        final extra = keys.difference(referenceKeys);
        expect(
          missing,
          isEmpty,
          reason: '$code.json is missing keys: $missing',
        );
        expect(
          extra,
          isEmpty,
          reason: '$code.json has extra keys not in en.json: $extra',
        );
      }
    });

    test('every supported locale has no empty or whitespace-only values', () {
      for (final code in locales) {
        final emptyKeys = bundles[code]!
            .entries
            .where((entry) => entry.value.trim().isEmpty)
            .map((entry) => entry.key)
            .toSet();
        expect(
          emptyKeys,
          isEmpty,
          reason: '$code.json has empty/whitespace-only values for keys: $emptyKeys',
        );
      }
    });

    test('locale files do not shadow top-level namespaces', () {
      for (final code in locales) {
        expect(
          _duplicateTopLevelNamespaces('lib/resources/i18n/$code.json'),
          isEmpty,
          reason: '$code.json has duplicate top-level namespaces',
        );
      }
    });
  });
}
