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
    test(
        'an offer-priced return refunds the sold price without a second item discount',
        () {
      final sold = SalesReturnCart.fromJson({
        'cart_item_id': 1,
        'quantity': 2,
        'unit_price': '90.000',
        'standard_unit_price': '100.000',
        'offer_id': 9,
        'total_price': '180.000',
        'returned_quantity': 1,
        'returned_total': '90.000',
      });
      final summary = SalesReturnCalculationHelper.calculateRefund(
        items: [sold],
        initialReturnedTotals: const {1: 0},
        orderDiscount: 0,
        shippingCost: 0,
        deliveryRefundable: false,
      );
      expect(sold.unitPrice, '90.000');
      expect(summary.proRataDiscount, 0);
      expect(summary.netRefundAmount, 90);
    });

    test('an order coupon is refunded pro-rata on top of the offer price', () {
      final sold = SalesReturnCart.fromJson({
        'cart_item_id': 1,
        'quantity': 2,
        'unit_price': '90.000',
        'standard_unit_price': '100.000',
        'total_price': '180.000',
        'returned_quantity': 1,
        'returned_total': '90.000',
      });
      final summary = SalesReturnCalculationHelper.calculateRefund(
        items: [sold],
        initialReturnedTotals: const {1: 0},
        orderDiscount: 18,
        shippingCost: 0,
        deliveryRefundable: false,
      );
      expect(summary.proRataDiscount, 9);
      expect(summary.netRefundAmount, 81);
    });

    test('a free offer sale has a finite zero refund', () {
      final sold = SalesReturnCart.fromJson({
        'cart_item_id': 1,
        'quantity': 1,
        'unit_price': '0.000',
        'standard_unit_price': '100.000',
        'total_price': '0.000',
        'returned_quantity': 1,
        'returned_total': '0.000',
      });
      final summary = SalesReturnCalculationHelper.calculateRefund(
        items: [sold],
        initialReturnedTotals: const {1: 0},
        orderDiscount: 0,
        shippingCost: 0,
        deliveryRefundable: false,
      );
      expect(summary.netRefundAmount, 0);
      expect(summary.netRefundAmount.isFinite, isTrue);
    });

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
      expect(withReturn.maxCashRefundAmount, 60); // 50 items + 10 delivery

      final fullReturnNoDelivery = SalesReturnCalculationHelper.calculateRefund(
        items: [
          _item(
            cartItemId: 1,
            totalPrice: '100',
            returnedTotal: '100',
          ),
        ],
        initialReturnedTotals: const {1: 0.0},
        orderDiscount: 20,
        shippingCost: 10,
        deliveryRefundable: false,
      );

      expect(fullReturnNoDelivery.sessionItemsTotal, 100);
      expect(fullReturnNoDelivery.proRataDiscount, 20);
      expect(fullReturnNoDelivery.netRefundAmount, 80);
      expect(fullReturnNoDelivery.maxCashRefundAmount, 100);
    });
  });
}
