import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/dashboard_widget_data.dart';

void main() {
  test('orders summary accepts the verified fields and numeric strings', () {
    final data = OrdersWidgetData.fromJson({
      'total_orders_today': '1',
      'average_order_amount': '404.8141128',
    });
    expect(data.todayCount, 1);
    expect(data.averageAmount, 404.8141128);
  });

  test('revenue stats reads all five amounts, including numeric strings', () {
    final data = RevenueStatsData.fromJson({
      'total_on_order': 293624.30000000005,
      'credit_collected': 9200,
      'credit_sales': '36662.2',
      'total_in_bank': 883490.92,
      'total_in_cash': 797509.706,
    });
    expect(data.totalOnOrder, closeTo(293624.3, 0.001));
    expect(data.creditCollected, 9200);
    expect(data.creditSales, 36662.2);
    expect(data.totalInBank, 883490.92);
    expect(data.totalInCash, 797509.706);
    expect(() => RevenueStatsData.fromJson({'total_on_order': 1}),
        throwsFormatException);
  });

  test('customer summary preserves debit, credit and a negative balance', () {
    final data = CustomerTransactionsSummaryData.fromJson({
      'total_customers': 221,
      'total_credit': '1422624.945',
      'total_debit': 1909661.735,
      'total_balance': -487036.79000000004,
    });
    expect(data.customers, 221);
    expect(data.credit, 1422624.945);
    expect(data.debit, 1909661.735);
    expect(data.balance, -487036.79000000004);
  });

  for (final bad in [null, true, 'wrong', 'NaN', double.infinity]) {
    test('invalid amount $bad fails instead of showing zero', () {
      expect(
          () => OrdersWidgetData.fromJson({
                'total_orders_today': 1,
                'average_order_amount': bad,
              }),
          throwsFormatException);
    });
  }

  for (final bad in [-1, 1.5, '1.5', null, 1e40]) {
    test('invalid count $bad is rejected', () {
      expect(
          () => OrdersWidgetData.fromJson({
                'total_orders_today': bad,
                'average_order_amount': 0,
              }),
          throwsFormatException);
    });
  }

  test(
      'latest orders keeps IDs distinct from order numbers and tolerates null customer',
      () {
    final data = LatestOrdersData.fromJson({
      'orders': [
        {
          'id': 6892,
          'order_date': '2026-10-13',
          'customer_name': null,
          'status': 'confirmed',
          'grand_total': '14.125',
        }
      ]
    });
    expect(data.orders.single.id, '6892');
    expect(data.orders.single.date, '2026-10-13');
    expect(data.orders.single.customerName, '');
    expect(data.orders.single.status, 'confirmed');
    expect(data.orders.single.grandTotal, 14.125);
    expect(() => data.orders.clear(), throwsUnsupportedError);
  });

  test('empty latest orders is valid, malformed or missing list is not', () {
    expect(LatestOrdersData.fromJson({'orders': []}).orders, isEmpty);
    for (final data in <Map<String, dynamic>>[
      {},
      {'orders': {}},
      {
        'orders': [null]
      },
      {
        'orders': [
          {'grand_total': 10}
        ]
      }
    ]) {
      expect(() => LatestOrdersData.fromJson(data), throwsFormatException);
    }
  });

  test('supplier graph keeps every paired month, zero count and numeric string',
      () {
    final data = SuppliersGraphData.fromJson({
      'labels': ['Jan', 'Feb', 'Mar'],
      'suppliers': [0, '14', 3],
    });
    expect(data.labels, ['Jan', 'Feb', 'Mar']);
    expect(data.counts, [0, 14, 3]);
    expect(() => data.counts.clear(), throwsUnsupportedError);
    expect(SuppliersGraphData.fromJson({'labels': [], 'suppliers': []}).counts,
        isEmpty);
  });

  test(
      'supplier graph rejects malformed arrays rather than silently truncating',
      () {
    for (final data in <Map<String, dynamic>>[
      {},
      {
        'labels': ['Jan'],
        'suppliers': []
      },
      {
        'labels': ['Jan'],
        'suppliers': [1, 2]
      },
      {
        'labels': [null],
        'suppliers': [1]
      },
      {
        'labels': ['Jan'],
        'suppliers': [-1]
      },
    ]) {
      expect(() => SuppliersGraphData.fromJson(data), throwsFormatException);
    }
  });
}
