import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/document_configurations.dart';

void main() {
  const snapshot = String.fromEnvironment('RECEIPT_CONFIG_SNAPSHOT');
  test('captured API labels survive model and cache serialization', () {
    final payload = jsonDecode(File(snapshot).readAsStringSync())
        as Map<String, dynamic>;
    final configs = payload['document_configurations'] as Map<String, dynamic>;
    for (final type in const [
      'Bill', 'Bill A4', 'Sales and Return Bill',
      'Sales and Return Bill A4', 'Return Bill',
    ]) {
      final raw = configs[type] as Map<String, dynamic>;
      final first = DocumentConfig.fromJson(raw);
      final restored = DocumentConfig.fromJson(first.toJson());
      for (final model in [first, restored]) {
        expect(model.language, raw['language'], reason: type);
        expect(model.header, raw['header'], reason: type);
        expect(model.subheader, raw['subheader'], reason: type);
        expect(model.activeTheme, raw['theme'], reason: type);
        final labels = raw['resolved_labels'] as Map<String, dynamic>;
        final serializedLabels = model.resolvedLabels!.toJson();
        for (final key in labels.keys) {
          expect(serializedLabels.containsKey(key), isTrue,
              reason: '$type resolved label $key omitted');
          expect(serializedLabels[key] == labels[key], isTrue,
              reason: '$type resolved label $key changed');
        }
        final options = raw['display_configuration'] as Map<String, dynamic>;
        for (final entry in options.entries) {
          final actual = model.displayConfiguration!.options![entry.key]!;
          final expected = entry.value as Map<String, dynamic>;
          expect(actual.value == expected['value'], isTrue,
              reason: '$type ${entry.key} active text changed');
          expect(actual.defaultValue == expected['default'], isTrue,
              reason: '$type ${entry.key} English text changed');
        }
      }
    }
  }, skip: snapshot.isEmpty ? 'Supply a local API capture to audit' : false);
}
