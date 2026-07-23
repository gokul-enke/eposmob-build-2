import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/list_stock.dart';
import 'package:pos_machine/providers/stock_provider.dart';

void main() {
  test('stock list model parses and serializes variant identity', () {
    final stock = ListStockModelData.fromJson({
      'id': 507,
      'product_variant_id': '8',
      'variant_name': 'Roasted peanuts - OPPO | gold',
      'product_name': 'Roasted peanuts',
      'barcode': '67878999098890',
      'qty': 99,
    });

    expect(stock.productVariantId, 8);
    expect(stock.variantName, 'Roasted peanuts - OPPO | gold');
    expect(stock.toJson()['product_variant_id'], 8);
    expect(
      stock.toJson()['variant_name'],
      'Roasted peanuts - OPPO | gold',
    );
  });

  test('pending stock validation requires a selected variant when enabled', () {
    final provider = StockProvider();
    final stockItem = <String, dynamic>{
      'productId': 15444,
      'categoryId': 2,
      'quantity': '1',
      'retailPrice': '100',
      'purchaseRate': '80',
      'unit': '1',
      'expiryDate': '2027-07-23',
      'variantRequired': true,
    };

    expect(
      provider.validateStockItem(stockItem)['variant'],
      'Product variant is required',
    );

    stockItem['productVariantId'] = 8;
    expect(provider.validateStockItem(stockItem)['variant'], isNull);
  });
}
