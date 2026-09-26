import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/list_sales_order.dart';

void main() {
  test('detects an unpaid COD order from list payment methods', () {
    final order = ListOrderModelData.fromJson({
      'id': 6461,
      'payment_method': ['COD'],
      'payment_status': 'pending',
    });

    expect(order.paymentMethods, ['COD']);
    expect(order.isUnpaidCod, isTrue);
  });

  test('does not treat a paid COD order as unpaid COD', () {
    final order = ListOrderModelData.fromJson({
      'payment_method': '["Cash On Delivery"]',
      'payment_status': 'paid',
    });

    expect(order.paymentMethods, ['Cash On Delivery']);
    expect(order.isUnpaidCod, isFalse);
  });

  test('does not skip refund details for a mixed COD payment', () {
    final order = ListOrderModelData.fromJson({
      'payment_method': ['CARD', 'COD'],
      'payment_status': 'pending',
    });

    expect(order.paymentMethods, ['CARD', 'COD']);
    expect(order.isUnpaidCod, isFalse);
  });
}
