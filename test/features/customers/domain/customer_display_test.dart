import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/domain/customer_display.dart';

void main() {
  group('CustomerNames', () {
    test('blank and placeholder names are unnamed', () {
      for (final name in [null, '', '   ', 'No Name', 'unnamed', ' UNNAMED ']) {
        expect(CustomerNames.isUnnamed(name), isTrue, reason: '$name');
        expect(CustomerNames.realName(name), isNull);
      }
    });

    test('real names are trimmed', () {
      expect(CustomerNames.isUnnamed(' Ann '), isFalse);
      expect(CustomerNames.realName(' Ann '), 'Ann');
    });
  });

  group('CustomerType.parse', () {
    test('B2B in any case is business, everything else consumer', () {
      expect(CustomerType.parse('b2b'), CustomerType.b2b);
      expect(CustomerType.parse(' B2B '), CustomerType.b2b);
      expect(CustomerType.parse('B2C'), CustomerType.b2c);
      expect(CustomerType.parse(null), CustomerType.b2c);
      expect(CustomerType.parse('other'), CustomerType.b2c);
    });
  });
}
