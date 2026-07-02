import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/sales_return_refund_breakdown.dart';

void main() {
  group('SalesReturnRefundBreakdown', () {
    test('fromResponseBody parses nested refund_breakdown', () {
      const body = '''
{
  "status": "success",
  "message": "Item Returned Successfully",
  "data": {
    "id": 78,
    "total_amount": "80.00",
    "refund_breakdown": {
      "order_items_total": "200.00",
      "returned_items_total": "100.00",
      "pro_rata_discount": "20.00",
      "delivery_refund": "0.00",
      "net_refund": "80.00"
    }
  }
}
''';

      final breakdown = SalesReturnRefundBreakdown.fromResponseBody(body);
      expect(breakdown, isNotNull);
      expect(breakdown!.returnedItemsTotal, 100);
      expect(breakdown.proRataDiscount, 20);
      expect(breakdown.netRefund, 80);

      final summary = breakdown.toRefundSummary(
        deliveryRefundable: true,
        shippingCost: 10,
      );
      expect(summary.isFromServer, isTrue);
      expect(summary.netRefundAmount, 90);
      expect(summary.maxCashRefundAmount, 110);
    });
  });
}
