import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/weigh_machine/domain/plu_csv.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  test('exports only products with an SKU and preserves CSV data', () {
    final weighted = GetProduct(
      productId: 1,
      productName: 'Apples, "red"',
      category: ProductCategory(name: 'Fruit'),
      barcode: '0000123',
      price: ProductPrice(price: '4'),
      mrp: '5.5',
      unit: 'KG',
      purchasePrice: '2',
      names: {'ar': 'تفاح'},
      sku: 'APL-1',
    );
    final ordinary = GetProduct(
      productId: 2,
      productName: 'Bag',
      // The old flag no longer decides anything.
      weightInfo: WeightInfo(isWeighted: true),
    );
    final blankSku = GetProduct(productId: 3, productName: 'Tray', sku: '  ');

    final items = PluCsv.weighted([weighted, ordinary, blankSku]);
    expect(items, [weighted]);
    expect(
      PluCsv.build(items),
      'Product Name,Category,Barcode,Price,MRP,Unit,Purchase Price,Arabic Name\r\n'
      '"Apples, ""red""",Fruit,0000123,4.00,5.50,KG,2.00,تفاح\r\n',
    );
  });

  group('SKU from stock rows', () {
    // Shape of the catalog API: no product-level sku; each store's stock
    // rows carry it (Mughlai White Mutton, product 14572).
    final apiJson = <String, dynamic>{
      'product_id': 14572,
      'product_name': ' Mughlai White Mutton',
      'barcode': '10045',
      'unit': 'PCS',
      'price': {'base_price': '18.880', 'total_price': '18.880'},
      'stock': [
        {'id': 17771, 'store_id': 2, 'sku': '4225', 'price': '18.880'},
        {'id': 17794, 'store_id': 35, 'sku': '4225', 'price': '18.880'},
      ],
    };

    test('reads the SKU from the active store stock row', () {
      final product = GetProduct.fromJson(apiJson);
      expect(product.sku, isNull);
      expect(PluCsv.skuOf(product, storeId: 35), '4225');
      expect(PluCsv.isWeighted(product, storeId: 2), isTrue);
    });

    test('ignores stock rows of other stores', () {
      final product = GetProduct.fromJson(apiJson);
      expect(PluCsv.skuOf(product, storeId: 99), isNull);
      expect(PluCsv.weighted([product], storeId: 99), isEmpty);
    });

    test('any stock row counts when no store is active', () {
      expect(PluCsv.skuOf(GetProduct.fromJson(apiJson)), '4225');
    });

    test('survives the local storage round trip', () {
      // LocalProductProvider saves product.toJson() and reads it back.
      final stored = GetProduct.fromJson(GetProduct.fromJson(apiJson).toJson());
      expect(PluCsv.skuOf(stored, storeId: 35), '4225');
    });

    test('product SKU wins; latest non-blank stock SKU otherwise', () {
      final own = GetProduct(
        productId: 1,
        sku: 'OWN',
        stock: [Stock(storeId: 1, sku: 'ROW')],
      );
      expect(PluCsv.skuOf(own, storeId: 1), 'OWN');

      final rows = GetProduct(productId: 2, stock: [
        Stock(storeId: 1, sku: 'OLD'),
        Stock(storeId: 1, sku: 'NEW'),
        Stock(storeId: 1, sku: '  '),
      ]);
      expect(PluCsv.skuOf(rows, storeId: 1), 'NEW');
    });
  });
}
