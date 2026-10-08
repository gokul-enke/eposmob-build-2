import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/return_print_identity.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return.dart';
import 'package:pos_machine/models/order_details.dart';

void main() {
  test('return summary keeps its own ID and never invents a creation date', () {
    final returns = OrderReturns.fromJson({
      'id': '758',
      'return_total_amount': '360',
      'return_items': [
        {'id': 985, 'quantity': 2, 'unit_price': '180'}
      ],
    });
    final restored = OrderReturns.fromJson(returns.toJson());
    final identity = ReturnPrintIdentity.fromSummary(restored);
    expect(identity.number, '758');
    expect(identity.date, isEmpty);
    expect(restored.returnTotalAmount, '360');
    expect(restored.returnItems!.single.id, 985);
    for (final date in [null, '', 'bad date', '2026-09-15T10:20:00Z']) {
      final source = OrderReturns.fromJson({'id': 758, 'created_at': date});
      final cached = OrderReturns.fromJson(source.toJson());
      final actual = ReturnPrintIdentity.fromSummary(cached);
      expect(actual.number, '758');
      expect(actual.date, date == '2026-09-15T10:20:00Z' ? date : '');
    }
    for (final id in [null, 0, -1]) {
      expect(ReturnPrintIdentity.fromSummary(OrderReturns(id: id)).number,
          isEmpty);
    }
  });
  test(
      'transaction identity is distinct from sale and ignores fallback current date',
      () {
    for (final date in [null, '', 'bad date', '2026-09-15T10:20:00Z']) {
      final returns = SalesReturnOrder.fromJson({
        'id': 758,
        'order_id': 4460,
        'created_at': date,
        'order': {
          'id': 4460,
          'order_number': 'ORD-004460',
          'order_date': '2026-09-01T10:37:00Z'
        },
      });
      final identity = ReturnPrintIdentity.fromTransaction(returns);
      expect(identity.number, '758');
      expect(identity.number, isNot(returns.order?.orderNumber));
      expect(returns.order?.orderNumber, 'ORD-004460');
      expect(returns.hasCreatedAt, date == '2026-09-15T10:20:00Z');
      expect(identity.date,
          date == '2026-09-15T10:20:00Z' ? '2026-09-15T10:20:00.000Z' : '');
      expect(identity.date, isNot('2026-09-01T10:37:00Z'));
    }
  });
}
