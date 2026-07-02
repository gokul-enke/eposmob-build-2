import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/product_details_helpers.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  group('product_details_helpers', () {
    test('formatProductDetailsNumeric trims trailing zeros', () {
      expect(formatProductDetailsNumeric('10.000'), '10');
      expect(formatProductDetailsNumeric(12.5), '12.5');
      expect(formatProductDetailsNumeric(''), '');
    });

    test('productAvailableQuantity sums stock rows', () {
      final product = GetProduct(
        stock: [
          Stock(quantity: 3),
          Stock(quantity: 2),
        ],
      );
      expect(productAvailableQuantity(product), 5);
    });

    test('isProductLowStock compares quantity to reorder level', () {
      expect(isProductLowStock(5, 10), isTrue);
      expect(isProductLowStock(11, 10), isFalse);
      expect(isProductLowStock(null, 10), isFalse);
    });

    test('formatProductStockNumber drops decimals for whole numbers', () {
      expect(formatProductStockNumber(10), '10');
      expect(formatProductStockNumber(10.5), '10.5');
    });
  });
}
