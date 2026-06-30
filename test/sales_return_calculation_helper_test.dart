import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/sales_return_calculation_helper.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';

SalesReturnCart _item({
  required int cartItemId,
  String quantity = '10',
  String totalPrice = '100',
  double returnedQuantity = 0,
  String returnedTotal = '0',
}) {
  return SalesReturnCart(
    cartItemId: cartItemId,
    returnOrderId: 1,
    productName: 'Product',
    quantity: quantity,
    unitPrice: '10',
    totalPrice: totalPrice,
    returnedQuantity: returnedQuantity,
    returnedTotal: returnedTotal,
    isReturned: false,
  );
}

void main() {
  group('SalesReturnCalculationHelper', () {
    test('remainingReturnableQuantity subtracts already returned qty', () {
      final item = _item(cartItemId: 1, quantity: '5', returnedQuantity: 2);
      expect(
        SalesReturnCalculationHelper.remainingReturnableQuantity(item),
        3,
      );
    });

    test('pro-rata discount applies only to returned share', () {
      final items = [_item(cartItemId: 1, totalPrice: '100')];
      final summary = SalesReturnCalculationHelper.calculateRefund(
        items: items,
        initialReturnedTotals: const {},
        orderDiscount: 20,
        shippingCost: 10,
        deliveryRefundable: false,
      );

      // Session return total 50 with 100 order items total → 10 discount (half of 20)
      expect(summary.sessionItemsTotal, 0);

      final withReturn = SalesReturnCalculationHelper.calculateRefund(
        items: [
          _item(
            cartItemId: 1,
            totalPrice: '100',
            returnedTotal: '50',
          ),
        ],
        initialReturnedTotals: const {1: 0.0},
        orderDiscount: 20,
        shippingCost: 10,
        deliveryRefundable: true,
      );

      expect(withReturn.sessionItemsTotal, 50);
      expect(withReturn.proRataDiscount, 10);
      expect(withReturn.netRefundAmount, 50); // 50 - 10 + 10 shipping
    });
  });
}
