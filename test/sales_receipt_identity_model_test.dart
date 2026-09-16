import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/list_sales_order.dart';
import 'package:pos_machine/models/order_details.dart';

void main() {
  test('sales list parses and prefers the stable receipt reference', () {
    final order = ListOrderModelData.fromJson({
      'id': 6220,
      'order_number': 'ORD-004645',
      'client_sale_id': '01995643-7f83-7a21-9a4b-b8c26d9c7b61',
      'receipt_number': '2-03-260916-0001',
      'issued_at': '2026-09-16T04:14:00.000Z',
      'grand_total': '16.00',
    });

    expect(order.orderNumber, 'ORD-004645');
    expect(order.clientSaleId, '01995643-7f83-7a21-9a4b-b8c26d9c7b61');
    expect(order.receiptNumber, '2-03-260916-0001');
    expect(order.customerReceiptNumber, '2-03-260916-0001');
  });

  test('order details keeps backend order and customer receipt identities', () {
    final order = OrderDetailsModelData.fromJson({
      'orders_id': 6220,
      'order_number': 'ORD-004645',
      'client_sale_id': '01995643-7f83-7a21-9a4b-b8c26d9c7b61',
      'receipt_number': '2-03-260916-0001',
      'issued_at': '2026-09-16T04:14:00.000Z',
    });

    expect(order.orderNumber, 'ORD-004645');
    expect(order.customerReceiptNumber, '2-03-260916-0001');
    expect(order.issuedAt, '2026-09-16T04:14:00.000Z');
  });

  test('old backend orders fall back to their existing order number', () {
    final listOrder = ListOrderModelData.fromJson({
      'order_number': 'ORD-000123',
      'grand_total': '1.00',
    });
    final details = OrderDetailsModelData.fromJson({
      'order_number': 'ORD-000123',
    });

    expect(listOrder.customerReceiptNumber, 'ORD-000123');
    expect(details.customerReceiptNumber, 'ORD-000123');
  });
}
