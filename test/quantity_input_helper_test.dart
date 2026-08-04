import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';

void main() {
  group('decimal purchase quantities', () {
    test('DZ is recognized as a decimal-capable unit', () {
      expect(allowsDecimalQuantityUnit('DZ'), isTrue);
      expect(allowsDecimalQuantityUnit(' dz '), isTrue);
    });

    test('DZ formatter accepts a quantity with two decimal places', () {
      final formatter = quantityInputFormattersForUnit('DZ').single;
      const value = TextEditingValue(
        text: '1.25',
        selection: TextSelection.collapsed(offset: 4),
      );

      expect(
        formatter.formatEditUpdate(TextEditingValue.empty, value).text,
        '1.25',
      );
    });
  });
}
