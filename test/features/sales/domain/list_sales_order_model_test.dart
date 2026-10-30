import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/models/payment_method_registry.dart';

void main() {
  setUp(PaymentMethodRegistry.clear);
  tearDown(PaymentMethodRegistry.clear);

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

  test('resolves a COD master-data ID before classifying an unpaid order', () {
    PaymentMethodRegistry.update(const [
      PaymentMethod(
        id: '7973',
        code: 'COD',
        label: 'Cash on Delivery',
      ),
    ]);

    final order = ListOrderModelData.fromJson({
      'payment_method': '7973',
      'payment_status': 'pending',
    });

    expect(order.isUnpaidCod, isTrue);
  });

  test('does not treat a non-COD master-data ID as COD', () {
    PaymentMethodRegistry.update(const [
      PaymentMethod(
        id: '7973',
        code: 'CARD',
        label: 'Card',
      ),
    ]);

    final order = ListOrderModelData.fromJson({
      'payment_method': '7973',
      'payment_status': 'pending',
    });

    expect(order.isUnpaidCod, isFalse);
  });

  test('paid amount leaves out the unpaid credit balance', () {
    // Shape from list-orders: BALANCE is a JSON-encoded string.
    final order = ListOrderModelData.fromJson({
      'grand_total': '200.000',
      'order_props': [
        {'code': 'ORDER_TOKEN_NUMBER', 'value': '136'},
        {'code': 'BALANCE', 'value': '"50"'},
      ],
    });

    expect(order.paidAmount, '150.000');
  });

  test('paid amount is the order total when nothing is on credit', () {
    final order = ListOrderModelData.fromJson({
      'grand_total': '10.25',
      'order_props': [
        {'code': 'BALANCE', 'value': '"0"'},
      ],
    });

    expect(order.paidAmount, '10.25');
    expect(ListOrderModelData.fromJson({'grand_total': '10.25'}).paidAmount,
        '10.25');
  });

  test('paid amount is zero for a fully credit sale', () {
    final order = ListOrderModelData.fromJson({
      'grand_total': '24.5',
      'order_props': [
        {'code': 'BALANCE', 'value': '"24.5"'},
      ],
    });

    expect(order.paidAmount, '0.000');
  });
}
