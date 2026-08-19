import 'dart:convert';
import 'dart:io';

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
    final english = _loadAndFlatten('lib/resources/i18n/en.json');
    final arabic = _loadAndFlatten('lib/resources/i18n/ar.json');

    test('English and Arabic expose the same translation keys', () {
      expect(arabic.keys.toSet(), english.keys.toSet());
    });

    test('English and Arabic translations are not empty', () {
      expect(english.values.where((value) => value.trim().isEmpty), isEmpty);
      expect(arabic.values.where((value) => value.trim().isEmpty), isEmpty);
    });

    test('locale files do not shadow top-level namespaces', () {
      expect(
        _duplicateTopLevelNamespaces('lib/resources/i18n/en.json'),
        isEmpty,
      );
      expect(
        _duplicateTopLevelNamespaces('lib/resources/i18n/ar.json'),
        isEmpty,
      );
    });
  });
}
