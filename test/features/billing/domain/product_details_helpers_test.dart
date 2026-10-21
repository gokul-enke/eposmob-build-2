import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/product_details_helpers.dart';

void main() {
  group('editedSkuForApi', () {
    test('an unchanged SKU is not sent', () {
      expect(editedSkuForApi(original: 'SKU-1', edited: 'SKU-1'), isNull);
      expect(editedSkuForApi(original: ' SKU-1 ', edited: 'SKU-1 '), isNull);
      expect(editedSkuForApi(original: null, edited: ''), isNull);
      expect(editedSkuForApi(original: null, edited: '   '), isNull);
    });

    test('a new or changed SKU is sent trimmed', () {
      expect(editedSkuForApi(original: null, edited: ' 4227 '), '4227');
      expect(editedSkuForApi(original: 'SKU-1', edited: 'SKU-2'), 'SKU-2');
    });

    test('clearing a set SKU sends an empty string', () {
      expect(editedSkuForApi(original: 'SKU-1', edited: '  '), '');
    });
  });
}
