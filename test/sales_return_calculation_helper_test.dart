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

/// Offer fields the server sends on a sold line, next to its sold
/// `unit_price`. A return must ignore them.
const _offerFields = <String, dynamic>{
  'standard_unit_price': '100.000',
  'offer_id': 9,
  'offer_version': 3,
};

/// Returns one unit of [soldLine] the way the return dialog prices it
/// (returned quantity x the line's unit price) and calculates the refund.
SalesReturnRefundSummary _returnOneUnit(
  Map<String, dynamic> soldLine, {
  double orderDiscount = 0,
}) {
  final sold = SalesReturnCart.fromJson(soldLine);
  final returned = SalesReturnCart.fromJson({
    ...soldLine,
    'returned_quantity': 1,
    'returned_total': (1 * double.parse(sold.unitPrice)).toStringAsFixed(3),
  });
  return SalesReturnCalculationHelper.calculateRefund(
    items: [returned],
    initialReturnedTotals: const {1: 0},
    orderDiscount: orderDiscount,
    shippingCost: 0,
    deliveryRefundable: false,
  );
}

void main() {
  group('SalesReturnCalculationHelper', () {
    test(
        'an offer line refunds its sold unit_price, not the higher '
        'standard_unit_price', () {
      const sold = <String, dynamic>{
        'cart_item_id': 1,
        'quantity': 2,
        'unit_price': '90.000',
        'total_price': '180.000',
      };
      final offerLine = SalesReturnCart.fromJson({...sold, ..._offerFields});
      expect(offerLine.unitPrice, '90.000');
      expect(offerLine.totalPrice, '180.000');

      final summary = _returnOneUnit({...sold, ..._offerFields});
      expect(summary.sessionItemsTotal, 90);
      expect(summary.proRataDiscount, 0);
      expect(summary.netRefundAmount, 90);
      expect(summary.maxCashRefundAmount, 90);

      // The offer fields change nothing: same refund as a plain 90 line.
      final plain = _returnOneUnit(sold);
      expect(summary.netRefundAmount, plain.netRefundAmount);
      expect(summary.maxCashRefundAmount, plain.maxCashRefundAmount);
    });

    test(
        'an order coupon is refunded pro-rata on the offer price, not on the '
        'standard price', () {
      const sold = <String, dynamic>{
        'cart_item_id': 1,
        'quantity': 2,
        'unit_price': '90.000',
        'total_price': '180.000',
      };
      final summary =
          _returnOneUnit({...sold, ..._offerFields}, orderDiscount: 18);
      // Half of the 180 line is returned, so half of the 18 coupon.
      expect(summary.orderItemsTotal, 180);
      expect(summary.proRataDiscount, 9);
      expect(summary.netRefundAmount, 81);

      final plain = _returnOneUnit(sold, orderDiscount: 18);
      expect(summary.proRataDiscount, plain.proRataDiscount);
      expect(summary.netRefundAmount, plain.netRefundAmount);
    });

    test(
        'a line made free by an offer refunds a finite zero, even with an '
        'order discount', () {
      final summary = _returnOneUnit({
        'cart_item_id': 1,
        'quantity': 1,
        'unit_price': '0.000',
        'total_price': '0.000',
        ..._offerFields,
      }, orderDiscount: 5);
      // The order lines total 0, so no share of the discount (no 0 / 0).
      expect(summary.proRataDiscount, 0);
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
