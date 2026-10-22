import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/models/sales_report.dart';
import 'package:pos_machine/features/reports/domain/report_period.dart';
import 'package:pos_machine/features/reports/domain/sales_report_query.dart';
import '../../../test_support/app_translations.dart';

void main() {
  group('SalesReportParams', () {
    test('Date Range options and their API codes', () {
      expect(SalesReportParams.periods, [
        ReportPeriod.thisMonth,
        ReportPeriod.lastMonth,
        ReportPeriod.last3Months,
        ReportPeriod.custom
      ]);
      expect(SalesReportParams.periods.map(SalesReportParams.periodCode),
          ['this_month', 'last_month', 'last_3_months', 'custom']);
    });

    test('each filter has its API list and its own label', () {
      expect({
        for (final f in SalesReportFilter.values) f: f.parameter
      }, {
        SalesReportFilter.store: 'store_ids',
        SalesReportFilter.salesExecutive: 'sales_executive_ids',
        SalesReportFilter.paymentMethod: 'payment_method_ids',
        SalesReportFilter.deliveryMethod: 'delivery_method_ids',
        SalesReportFilter.category: 'category_ids',
        SalesReportFilter.product: 'product_ids',
        SalesReportFilter.customer: 'customer_ids',
      });
      expect(
          SalesReportFilter.store.labelKey, 'order_sales_report.filter_stores');
      final strings = translationSection('en', 'order_sales_report');
      for (final filter in SalesReportFilter.values) {
        expect(strings, contains(filter.labelKey.split('.').last),
            reason: filter.name);
      }
    });
  });

  group('SalesReportResponse.parse', () {
    Map<String, dynamic> row(int id) =>
        {'order_id': id, 'order_number': 'ORD-$id'};

    test('the reports API shape: data.data, summary and pagination', () {
      final page = SalesReportResponse.parse({
        'status': 'success',
        'data': {
          'data': [row(1)],
          'summary': {'orders': 1, 'order_value': '250.0', 'note': 'x'},
          'filters': {'from': '2026-10-01', 'to': '2026-10-20'},
          'pagination': {
            'current_page': '2',
            'last_page': 3,
            'per_page': 25,
            'total': 51,
            'next_page_url': null
          }
        }
      });
      expect(page.rows.single.orderNumber, 'ORD-1');
      expect((page.currentPage, page.lastPage, page.perPage, page.total),
          (2, 3, 25, 51));
      expect(page.summary, {'orders': 1.0, 'order_value': 250.0});
    });

    test('a Laravel paginator without a pagination block', () {
      final page = SalesReportResponse.parse({
        'status': 'success',
        'data': {
          'data': [row(1)],
          'current_page': 1,
          'last_page': 0,
          'per_page': 25,
          'total': 1
        }
      });
      expect((page.currentPage, page.lastPage, page.perPage, page.total),
          (1, 1, 25, 1));
    });

    test('list with a top-level pagination block', () {
      final page = SalesReportResponse.parse({
        'status': 'success',
        'data': [row(1), row(2)],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 2}
      });
      expect(page.rows.map((r) => r.orderId), [1, 2]);
      expect(page.summary, isEmpty);
    });

    test('no pagination means one page', () {
      final page = SalesReportResponse.parse({
        'status': 'success',
        'data': [row(1), row(2)]
      });
      expect((page.currentPage, page.lastPage, page.perPage, page.total),
          (1, 1, 2, 2));
      final empty =
          SalesReportResponse.parse({'status': 'success', 'data': []});
      expect((empty.lastPage, empty.perPage, empty.total), (1, 1, 0));
    });

    test('rejects failures and malformed envelopes', () {
      for (final bad in [
        null,
        {
          'status': 'failed',
          'message': 'Unable to resolve company',
          'data': null
        },
        {'status': 'success', 'data': 'x'},
        {
          'status': 'success',
          'data': {'data': 'x'}
        },
        {
          'status': 'success',
          'data': ['x']
        },
        {
          'status': 'success',
          'data': [row(1)],
          'pagination': {'current_page': 1, 'last_page': 1, 'per_page': 0}
        },
        {
          'status': 'success',
          'data': [row(1)],
          'pagination': {'current_page': 1, 'per_page': 25}
        },
        {
          'status': 'success',
          'data': [
            {'order_number': 'no id'}
          ]
        },
      ]) {
        expect(() => SalesReportResponse.parse(bad), throwsFormatException,
            reason: '$bad');
      }
    });
  });

  group('SalesReportRow', () {
    test('the fields of the sales-report API', () {
      final row = SalesReportRow.fromJson({
        'order_id': 101,
        'order_number': 'ORD-101',
        'order_date': '2026-10-20',
        'order_value': 250.0,
        'store_id': 1,
        'store_name': 'Main Store',
        'customer_id': 22,
        'customer_name': 'John Doe',
        'payment_methods': ['CASH', 'CARD'],
        'delivery_method_id': 2,
        'delivery_method': 'Door Delivery',
        'sales_executive_id': 8,
        'sales_executive': 'Alex',
        'items_quantity': 3
      });
      expect(row.orderId, 101);
      expect(row.orderNumber, 'ORD-101');
      expect(row.orderDate, DateTime(2026, 10, 20));
      expect(row.orderValue, 250);
      expect(row.paymentMethods, 'CASH, CARD');
      expect(row.deliveryMethod, 'Door Delivery');
      expect((row.salesExecutive, row.salesExecutiveId), ('Alex', 8));
      expect((row.customer, row.store), ('John Doe', 'Main Store'));
    });

    test('fallback field names of the order APIs', () {
      final row = SalesReportRow.fromJson({
        'id': '7',
        'created_at': '2026-10-20T10:00:00Z',
        'total_price': '1,250.50',
        'payment_method': 'CASH',
        'delivery_mode': 'Pickup',
        'sales_executive_name': 'Sam',
        'store': {'name': 'Branch'}
      });
      expect(row.orderId, 7);
      expect(row.orderNumber, '#7');
      expect(row.orderDate, DateTime.utc(2026, 10, 20, 10).toLocal());
      expect(row.orderValue, 1250.5);
      expect((row.paymentMethods, row.deliveryMethod), ('CASH', 'Pickup'));
      expect((row.salesExecutive, row.store), ('Sam', 'Branch'));
    });

    test('bad amounts stay empty rather than zero', () {
      final row = SalesReportRow.fromJson(
          {'order_id': 1, 'order_value': 'abc', 'order_number': ' '});
      expect(row.orderValue, isNull);
      expect(row.orderNumber, '#1');
    });

    test('a row without an order id is rejected', () {
      for (final bad in [
        <String, dynamic>{'order_number': 'x'},
        <String, dynamic>{'order_id': 0},
        <String, dynamic>{'order_id': 'abc'},
      ]) {
        expect(() => SalesReportRow.fromJson(bad), throwsFormatException,
            reason: '$bad');
      }
    });
  });
}
