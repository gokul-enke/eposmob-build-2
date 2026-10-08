import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';

Map<String, dynamic> _returnJson(Map<String, dynamic>? order) => {
      'id': 12,
      'order_id': 4689,
      'total_amount': '4.00',
      'user_id': 1,
      'status': 1,
      'created_at': '2026-09-29T06:52:00.000Z',
      'updated_at': '2026-09-29T06:52:00.000Z',
      'items': [],
      if (order != null) 'order': order,
    };

void main() {
  test('shows the device receipt number first when the order has one', () {
    final sale = SalesReturnOrder.fromJson(_returnJson({
      'id': 4689,
      'order_number': 'ORD-004689',
      'receipt_number': '2-01-260929-0002',
    }));

    expect(sale.receiptNumber, '2-01-260929-0002');
    expect(sale.originalOrderNumber, 'ORD-004689');
    expect(sale.displayNumber, '2-01-260929-0002');
  });

  test('falls back to the backend order number for older orders', () {
    for (final receipt in [null, '', '   ']) {
      final sale = SalesReturnOrder.fromJson(_returnJson({
        'id': 4460,
        'order_number': 'ORD-004460',
        'receipt_number': receipt,
      }));

      expect(sale.receiptNumber, isNull);
      expect(sale.displayNumber, 'ORD-004460');
    }
  });

  test('uses the order id when the nested order is missing', () {
    final sale = SalesReturnOrder.fromJson(_returnJson(null));

    expect(sale.receiptNumber, isNull);
    expect(sale.displayNumber, '4689');
  });
}
