import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/quantity_input_helper.dart';

void main() {
  group('decimal purchase quantities', () {
    test('DZ is recognized as a decimal-capable unit', () {
      expect(allowsDecimalQuantityUnit('DZ'), isTrue);
      expect(allowsDecimalQuantityUnit(' dz '), isTrue);
    });

    test('length unit aliases are decimal-capable regardless of case', () {
      const lengthUnits = [
        'M',
        'MTR',
        'METER',
        'METERS',
        'METRE',
        'METRES',
        'CM',
        'CENTIMETER',
        'CENTIMETERS',
        'CENTIMETRE',
        'CENTIMETRES',
        'YD',
        'YARD',
        'YARDS',
        'FT',
        'FOOT',
        'FEET',
        'IN',
        'INCH',
        'INCHES',
      ];

      for (final unit in lengthUnits) {
        expect(allowsDecimalQuantityUnit(unit), isTrue, reason: unit);
        expect(
          allowsDecimalQuantityUnit(unit.toLowerCase()),
          isTrue,
          reason: unit.toLowerCase(),
        );
      }
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
