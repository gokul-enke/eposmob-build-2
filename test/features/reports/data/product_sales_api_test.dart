import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/product_sales_api.dart';
import 'package:pos_machine/providers/report_provider.dart';
import '../../../test_support/network_fakes.dart';

Map<String, dynamic> response() => {
      'status': 'success',
      'data': {
        'data': [
          {
            'product_id': 1,
            'product_name': 'Product',
            'price': '2.345',
            'sales_count': '1.5',
            'total_price': '3.5175'
          }
        ],
        'currency': 'SAR',
        'summary': {'total_revenue': '3.5175', 'total_quantity': '1.5'},
        'pagination': {
          'current_page': 2,
          'last_page': 2,
          'per_page': 25,
          'total': 26
        }
      }
    };
void main() {
  test('injectable API preserves URL query headers and numeric response',
      () async {
    final api = ProductSalesApi(
        session: const FakeTenantSession(),
        get: (url, {headers}) async {
          expect(url.queryParameters, {
            'page': '2',
            'per_page': '25',
            'category_id': '88',
            'product_id': '9',
            'customer_id': '7',
            'from': '2026-09-01',
            'to': '2026-09-30'
          });
          expect(headers, {
            'Authorization': 'Bearer token',
            'Content-Type': 'application/json',
            'X-Tenant': 'tenant'
          });
          expect(url.queryParameters.containsKey('store_id'), isFalse);
          return jsonResponse(response());
        });
    final result = await api.fetch(
        accessToken: 'token',
        categoryId: '88',
        productId: '9',
        customerId: '7',
        startDate: '2026-09-01',
        endDate: '2026-09-30',
        page: 2);
    expect(result.data.entries.single.totalPrice, 3.5175);
    expect(result.data.summary.totalQuantity, 1.5);
  });
  test('missing tenant fails before HTTP', () async {
    final api = ProductSalesApi(
        session: const FakeTenantSession(key: null),
        get: (_, {headers}) => throw StateError('Must not call HTTP'));
    await expectLater(
        api.fetch(accessToken: ''), throwsA(isA<HttpException>()));
  });
  for (final status in [403, 500]) {
    test('non-200 $status is a failure rather than an empty success', () async {
      final api = ProductSalesApi(
          session: const FakeTenantSession(),
          get: (_, {headers}) async => jsonResponse({}, status));
      await expectLater(api.fetch(accessToken: ''), throwsException);
    });
  }
  test('provider keeps its public updateState notification contract', () async {
    final api = ProductSalesApi(
        session: const FakeTenantSession(),
        get: (_, {headers}) async => jsonResponse(response()));
    final provider = ReportsProvider(productSalesApi: api);
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.fetchProductSalesReport(
        accessToken: 'token', updateState: false);
    expect(provider.productSalesReport, isNull);
    expect(notifications, 0);
    final result = await provider.fetchProductSalesReport(accessToken: 'token');
    expect(provider.productSalesReport, same(result));
    expect(notifications, 1);
  });
}
