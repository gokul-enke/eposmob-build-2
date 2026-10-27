import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/discount_sale_report_query.dart';
import 'package:pos_machine/features/reports/domain/models/discount_sale_report.dart';
import 'package:pos_machine/features/reports/domain/report_period.dart';
import '../../../test_support/app_translations.dart';

void main() {
  test('API period codes: today, week, month and custom', () {
    expect(
        DiscountSaleReportParams.periods
            .map(DiscountSaleReportParams.periodCode),
        ['today', 'week', 'month', 'custom']);
    // Periods the report does not offer fall back to the default month.
    expect(
        DiscountSaleReportParams.periodCode(ReportPeriod.lastMonth), 'month');
  });

  test('each picker sets its own single-id parameter', () {
    expect({
      for (final filter in DiscountSaleReportFilter.values)
        filter.name: filter.parameter
    }, {
      'store': 'store_id',
      'salesExecutive': 'executive_id',
      'customer': 'customer_id',
    });
  });

  group('DiscountSaleReportResponse.parse', () {
    Map<String, dynamic> row(int id) =>
        {'order_id': id, 'order_number': 'ORD-$id'};

    test('the reports API shape: data.data, summary and pagination', () {
      final page = DiscountSaleReportResponse.parse({
        'status': 'success',
        'data': {
          'data': [row(1)],
          'summary': {'orders': 1, 'total_discount': '2.50', 'note': 'x'},
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
      expect(page.summary, {'orders': 1.0, 'total_discount': 2.5});
    });

    test('a Laravel paginator without a pagination block', () {
      final page = DiscountSaleReportResponse.parse({
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
      final page = DiscountSaleReportResponse.parse({
        'status': 'success',
        'data': [row(1), row(2)],
        'meta': {'current_page': 1, 'last_page': 1, 'per_page': 25, 'total': 2}
      });
      expect(page.rows.map((r) => r.orderId), [1, 2]);
      expect(page.summary, isEmpty);
    });

    test('no pagination means one page', () {
      final page = DiscountSaleReportResponse.parse({
        'status': 'success',
        'data': [row(1), row(2)]
      });
      expect((page.currentPage, page.lastPage, page.perPage, page.total),
          (1, 1, 2, 2));
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
        expect(
            () => DiscountSaleReportResponse.parse(bad), throwsFormatException,
            reason: '$bad');
      }
    });
  });

  group('rows', () {
    test('the fields of the discount-sales-report API', () {
      final row = DiscountSaleReportRow.fromJson({
        'order_id': 6843,
        'order_date': '2026-10-12',
        'order_number': 'ORD-004749',
        'executive_id': 1060,
        'executive_name': 'SALESMEDINA',
        'customer_id': 2693,
        'customer_name': 'Ayswariya',
        'discount_type': 'Cart items level',
        'item_discount': 2,
        'discount': 0,
        'total_discount': 2,
        'store_id': 70,
        'store_name': 'MEDINA FUNZCART'
      });
      expect(row.orderId, 6843);
      expect(row.orderNumber, 'ORD-004749');
      expect(row.orderDate, DateTime(2026, 10, 12));
      expect((row.salesExecutive, row.salesExecutiveId), ('SALESMEDINA', 1060));
      expect(row.customer, 'Ayswariya');
      expect(row.discountType, DiscountType.cartItems);
      expect(row.discountTypeText, 'Cart items level');
      expect(row.cartItemsDiscount, 2);
      expect(row.overallOrderDiscount, 0);
      expect(row.discountAmount, 2);
      expect(row.store, 'MEDINA FUNZCART');
      expect(row.offlineReceiptNumber, isNull);
    });

    test('descriptive field names are accepted as fallbacks', () {
      final row = DiscountSaleReportRow.fromJson({
        'id': '7',
        'created_at': '2026-10-12T08:00:00',
        'offline_receipt_number': ' OFF-9 ',
        'sales_executive_name': 'Alex',
        'sales_executive_id': '8',
        'customer': {'name': 'Walk-in'},
        'discount_type': 'coupon',
        'cart_items_discount': '1,250.50',
        'overall_order_discount': 3,
        'discount_amount': 4,
        'store': 'Branch'
      });
      expect(row.orderId, 7);
      expect(row.orderDate, DateTime(2026, 10, 12, 8));
      expect(row.offlineReceiptNumber, 'OFF-9');
      expect((row.salesExecutive, row.salesExecutiveId), ('Alex', 8));
      expect(row.customer, 'Walk-in');
      expect(row.discountType, isNull, reason: 'unknown types stay as sent');
      expect(row.discountTypeText, 'coupon');
      expect(row.cartItemsDiscount, 1250.5);
      expect((row.overallOrderDiscount, row.discountAmount), (3, 4));
      expect(row.store, 'Branch');
    });

    test('bad amounts stay empty rather than zero; blank number falls back',
        () {
      final row = DiscountSaleReportRow.fromJson(
          {'order_id': 1, 'total_discount': 'abc', 'order_number': ' '});
      expect(row.discountAmount, isNull);
      expect(row.orderNumber, '#1');
      expect(() => DiscountSaleReportRow.fromJson({'order_id': 0}),
          throwsFormatException);
    });

    test('discount types: API text and codes', () {
      expect(DiscountType.fromCode('Overall order level'),
          DiscountType.overallOrder);
      expect(DiscountType.fromCode('order'), DiscountType.overallOrder);
      expect(DiscountType.fromCode(' Items '), DiscountType.cartItems);
      expect(DiscountType.fromCode('Cart items level'), DiscountType.cartItems);
      expect(DiscountType.fromCode('coupon'), isNull);
      expect(DiscountType.fromCode(''), isNull);
      expect(DiscountType.fromCode(null), isNull);
      expect(DiscountType.all.code, isEmpty);
      expect(DiscountType.cartItems.code, 'items');
      expect(DiscountType.overallOrder.code, 'order');
    });
  });

  test('labels of the types and pickers exist in every language', () {
    for (final lang in ['en', 'ar', 'ml']) {
      final section = translationSection(lang, 'discount_sale_report');
      for (final key in [
        for (final type in DiscountType.values) type.labelKey,
        for (final filter in DiscountSaleReportFilter.values) filter.labelKey,
      ]) {
        expect(key, startsWith('discount_sale_report.'));
        expect(section, contains(key.split('.').last), reason: '$lang $key');
      }
    }
  });
}
