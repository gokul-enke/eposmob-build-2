import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/purchase_order_model.dart';

void main() {
  test('parses complete pending purchase item from mixed JSON types', () {
    final item = PurchaseOrderItemData.fromJson({
      'id': '456',
      'product_id': '123',
      'quantity': 24,
      'unit_price': 100,
      'calculated_purchase_rate': '118.000',
      'retail_price': 150,
      'wholesale_price': '130.000',
      'mrp': 160,
      'tax_include': 1,
      'tax_include_purchase': false,
      'rack': 'RACK-A',
      'wholesale_min_unit': 6,
      'pkg_mfg': '2026-08-01',
      'expiry_date': '2027-08-01',
      'batch_number': 'BATCH-1001',
      'purchase_unit_id': '5',
      'purchase_unit_type': 'Carton',
      'purchase_unit_conversion_rate': 12,
      'purchase_qty': 2,
      'unit_prices': [
        {'sale_unit_id': '5', 'price': '1750.000'},
      ],
    });

    expect(item.id, 456);
    expect(item.productId, 123);
    expect(item.quantity, '24');
    expect(item.taxInclude, isTrue);
    expect(item.taxIncludePurchase, isFalse);
    expect(item.retailPrice, '150');
    expect(item.pkgMfg, '2026-08-01');
    expect(item.purchaseUnitId, 5);
    expect(item.purchaseUnitType, 'Carton');
    expect(item.purchaseUnitConversionRate, '12');
    expect(item.purchaseQty, '2');
    expect(item.unitPrices, [
      {'sale_unit_id': 5, 'price': 1750.0},
    ]);
  });

  test('falls back purchase tax inclusion to selling tax for old responses',
      () {
    final item = PurchaseOrderItemData.fromJson({
      'tax_include': '0',
    });

    expect(item.taxInclude, isFalse);
    expect(item.taxIncludePurchase, isFalse);
  });
}
