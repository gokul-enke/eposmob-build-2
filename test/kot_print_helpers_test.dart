import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/screens/print/kot_print_helpers.dart';

void main() {
  group('KOT document configuration', () {
    test('parses is_active and treats zero as disabled', () {
      final config = DocumentConfig.fromJson({'is_active': 0});

      expect(config.isActive, 0);
      expect(config.isEnabled, isFalse);
      expect(isKotDocumentConfigEnabled(config), isFalse);
      expect(config.toJson()['is_active'], 0);
    });

    test('remains enabled when older responses omit is_active', () {
      final config = DocumentConfig.fromJson({});

      expect(config.isEnabled, isTrue);
    });
  });

  group('calculateKotTotal', () {
    test('uses explicit line totals when available', () {
      final total = calculateKotTotal([
        {'totalPrice': '12.50', 'quantity': '99', 'unitPrice': '99'},
        {'total_price': 7.5},
      ]);

      expect(total, 20);
      expect(formatKotAmount(total), '20.00');
    });

    test('falls back to quantity multiplied by unit price', () {
      final total = calculateKotTotal([
        {'quantity': '2', 'unitPrice': '10.25'},
        {'quantity': 3, 'rate': '4'},
      ]);

      expect(total, 32.5);
    });
  });
}
