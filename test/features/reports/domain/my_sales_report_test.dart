import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/my_sales_report.dart';

import '../support/report_fixtures.dart';

void main() {
  for (final invalid in [
    null,
    {},
    {'status': 'success', 'data': {}},
    {'status': 'failed', 'data': []},
    salesReport([salesRow('Bad')..['total_sales'] = 'NaN']),
    salesReport([salesRow('Bad')..['cash_sales'] = 'bad']),
    salesReport([salesRow('Bad')..['order_count'] = -1]),
    salesReport([
      salesRow('Bad')..['payment_breakdown'] = {'CARD': 'Infinity'}
    ])
  ]) {
    test('rejects invalid report $invalid', () {
      expect(() => parseMySalesReport(invalid), throwsFormatException);
    });
  }

  test('legacy camelCase and an empty payment breakdown stay supported', () {
    final rows = parseMySalesReport(salesReport([
      {
        'name': 'Legacy',
        'orderCount': '2',
        'totalSales': 5.125,
        'payment_breakdown': []
      }
    ]));
    expect(rows.single.orderCount, 2);
    expect(rows.single.totalSalesAmount, 5.125);
  });
}
