import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/purchase_return_pricing.dart';
import 'package:pos_machine/models/purchase_order_model.dart';
import 'package:pos_machine/models/purchase_return_model.dart';

void main() {
  test('matches API pricing for a voucher with a global discount', () {
    final voucher = PurchaseOrderData(
      discount: '33.00',
      items: [
        PurchaseOrderItemData(
          id: 10,
          quantity: '10',
          unitPrice: '11.00',
          totalPrice: '110.00',
        ),
        PurchaseOrderItemData(
          id: 11,
          quantity: '10',
          unitPrice: '22.00',
          totalPrice: '220.00',
        ),
      ],
    );
    final item = ReturnableItem(
      purchaseItemId: 10,
      unitPrice: 11,
      returnableQuantity: 10,
    );

    expect(
      PurchaseReturnPricing.unitPrice(item: item, voucher: voucher),
      closeTo(9.9, 0.000001),
    );
    expect(
      PurchaseReturnPricing.lineAmount(
        item: item,
        quantity: 2,
        voucher: voucher,
      ),
      closeTo(19.8, 0.000001),
    );
  });

  test('preserves fractional quantities instead of rounding them away', () {
    expect(PurchaseReturnPricing.formatQuantity(0.125), '0.125');
    expect(PurchaseReturnPricing.formatQuantity(1.5), '1.5');
    expect(PurchaseReturnPricing.formatQuantity(2), '2');
  });

  test('falls back to the returnable item price when purchase data is absent',
      () {
    final item = ReturnableItem(purchaseItemId: 99, unitPrice: 12.5);

    expect(
      PurchaseReturnPricing.unitPrice(item: item),
      closeTo(12.5, 0.000001),
    );
  });
}
