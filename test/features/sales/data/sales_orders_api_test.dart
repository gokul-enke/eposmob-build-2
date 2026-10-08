import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/sales/data/sales_orders_api.dart';
import 'package:pos_machine/features/sales/domain/sales_action_error.dart';
import 'package:pos_machine/features/sales/domain/sales_order_query.dart';

class Session extends TenantSession {
  const Session(this.key, this.store);
  final String? key;
  final int? store;
  @override
  Future<String?> apiKey() async => key;
  @override
  Future<int?> activeStoreId() async => store;
}

void main() {
  test('tenant and active store travel with all supplied filters', () async {
    Uri? request;
    Map<String, String>? requestHeaders;
    final api = SalesOrdersApi(
        session: const Session('tenant-a', 7),
        get: (uri, {headers}) async {
          request = uri;
          requestHeaders = headers;
          return http.Response(
              jsonEncode({
                'status': 'success',
                'data': {
                  'data': [],
                  'current_page': 3,
                  'last_page': 4,
                  'from': 41
                }
              }),
              200);
        });
    final result = await api.fetchOrders(
        'token',
        const SalesOrderQuery(
            orderNumber: 'ORD-1',
            filterName: 'Alice',
            date: '2026-10-05',
            from: '2026-10-01',
            until: '2026-10-05',
            businessDate: '2026-10-05',
            customerId: 8,
            productId: 9,
            filterStatus: 'paid',
            filterPrice: '4.190',
            filterEmail: 'a@example.com',
            filterPhone: '123',
            filterStore: '10',
            filterCreatedBy: '11',
            page: 3,
            filterOnlineSales: false));
    expect(requestHeaders, {
      'Authorization': 'Bearer token',
      'Content-Type': 'application/json',
      'X-Tenant': 'tenant-a'
    });
    expect(request!.queryParameters, {
      'store_id': '7',
      'number': 'ORD-1',
      'filter_name': 'Alice',
      'order_date': '2026-10-05',
      'filter_datetime[from]': '2026-10-01',
      'filter_datetime[until]': '2026-10-05',
      'business_date': '2026-10-05',
      'customer_id': '8',
      'product_id': '9',
      'filter_status': 'paid',
      'filter_price': '4.190',
      'filter_email': 'a@example.com',
      'filter_phone': '123',
      'filter_store': '10',
      'filter_created_by': '11',
      'page': '3',
      'filter_online_sales': 'false'
    });
    expect(result.pagination!.currentPage, 3);
  });
  test('explicit store wins over the active store', () async {
    final api = SalesOrdersApi(
        session: const Session('tenant-b', 7),
        get: (uri, {headers}) async {
          expect(uri.queryParameters['store_id'], '99');
          expect(headers!['X-Tenant'], 'tenant-b');
          return http.Response('{"data":{"data":[]}}', 200);
        });
    await api.fetchOrders('token', const SalesOrderQuery(storeId: 99));
  });
  test('only the legacy No Orders Found 500 is an empty result', () async {
    var body = '{"status":"failed","message":"No Orders Found","data":[]}';
    final api = SalesOrdersApi(
        session: const Session('tenant', 7),
        get: (uri, {headers}) async => http.Response(body, 500));
    expect((await api.fetchOrders('token', const SalesOrderQuery())).data,
        isEmpty);
    body = '{"status":"failed","message":"Invalid payment allocation"}';
    await expectLater(
        api.fetchOrders('token', const SalesOrderQuery()),
        throwsA(isA<SalesApiException>().having((e) => e.toString(),
            'backend message', contains('Invalid payment allocation'))));
  });
  test('empty and malformed successful responses remain errors', () async {
    var body = '';
    final api = SalesOrdersApi(
        session: const Session('tenant', 7),
        get: (uri, {headers}) async => http.Response(body, 200));
    await expectLater(
        api.fetchOrders('token', const SalesOrderQuery()), throwsException);
    body = 'invalid json';
    await expectLater(api.fetchOrders('token', const SalesOrderQuery()),
        throwsFormatException);
  });
  test('missing tenant makes no HTTP request', () async {
    var called = false;
    final api = SalesOrdersApi(
        session: const Session(null, 7),
        get: (uri, {headers}) async {
          called = true;
          return http.Response('{}', 200);
        });
    await expectLater(
        api.fetchOrders('token', const SalesOrderQuery()), throwsException);
    expect(called, false);
  });
}
