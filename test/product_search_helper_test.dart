import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/product_search_helper.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  group('ProductSearchHelper', () {
    test('searches every supported product identifier', () {
      final product = GetProduct(
        productId: 1,
        productName: 'Arabica Coffee',
        names: const {'ar': 'قهوة عربية'},
        itemCode: 'ITEM-42',
        sku: 'BASE-SKU',
        hsnCode: 'HSN-0901',
        barcode: '8901234567890',
        variants: [
          ProductVariant(
            id: 10,
            sku: 'VAR-SKU',
            barcode: 'VAR-998877',
          ),
        ],
        stock: [
          Stock(sku: 'BATCH-SKU', hsnCode: 'BATCH-HSN'),
        ],
        saleUnits: [
          SaleUnit(barcode: 'UNIT-554433'),
        ],
      );

      for (final query in [
        'coffee',
        'عربية',
        'item-42',
        'base-sku',
        'var-sku',
        'batch-sku',
        'hsn-0901',
        'batch-hsn',
        '34567',
        '99887',
        '55443',
      ]) {
        expect(
          ProductSearchHelper.search([product], query),
          [product],
          reason: 'Expected "$query" to match',
        );
      }
    });

    test('ranks five-digit barcode matches by relevance', () {
      final substring = GetProduct(
        productId: 1,
        productName: 'Substring',
        barcode: '999991234588888',
      );
      final prefixLong = GetProduct(
        productId: 2,
        productName: 'Long prefix',
        barcode: '1234567890123',
      );
      final exact = GetProduct(
        productId: 3,
        productName: 'Exact',
        saleUnits: [SaleUnit(barcode: '12345')],
      );
      final prefixShort = GetProduct(
        productId: 4,
        productName: 'Short prefix',
        variants: [ProductVariant(id: 40, barcode: '123456')],
      );

      final result = ProductSearchHelper.searchBarcodes(
        [substring, prefixLong, exact, prefixShort],
        '12345',
      );

      expect(result, [exact, prefixShort, prefixLong, substring]);
    });

    test('ignores inactive variant identifiers', () {
      final product = GetProduct(
        productName: 'Inactive variant',
        variants: [
          ProductVariant(
            id: 1,
            sku: 'HIDDEN-SKU',
            barcode: '123456789',
            active: false,
          ),
        ],
      );

      expect(ProductSearchHelper.search([product], 'hidden-sku'), isEmpty);
      expect(ProductSearchHelper.searchBarcodes([product], '12345'), isEmpty);
    });
  });
}
