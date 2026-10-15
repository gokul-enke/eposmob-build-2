import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/providers/dashboard_widgets_repository.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _success(Map<String, dynamic> data) =>
    http.Response(jsonEncode({'status': 'success', 'data': data}), 200);

void main() {
  final originalBase = APPUrl.baseURL;
  setUp(() {
    APPUrl.baseURL = 'https://demo.example';
    SharedPreferences.setMockInitialValues(
        {'api_key': 'demo-tenant', 'active_store_id': 2});
  });
  tearDown(() => APPUrl.baseURL = originalBase);

  test(
      'four verified default routes carry authentication and tenant, without guessed filters',
      () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.method, 'GET');
      expect(request.url.host, 'demo.example');
      expect(request.url.queryParameters, isEmpty);
      expect(request.headers['Authorization'], 'Bearer demo-token');
      expect(request.headers['X-Tenant'], 'demo-tenant');
      expect(request.headers['Accept'], 'application/json');
      return switch (request.url.path.split('/').last) {
        'orders-widget' => _success(
            {'total_orders_today': 1, 'average_order_amount': 404.8141128}),
        'latest-orders' => _success({'orders': []}),
        'customer-transactions-summary' => _success({
            'total_customers': 221,
            'total_credit': 1422624.945,
            'total_debit': 1909661.735,
            'total_balance': -487036.79
          }),
        'suppliers-graph' => _success({
            'labels': ['Jan'],
            'suppliers': [3]
          }),
        _ => throw StateError('Unexpected endpoint'),
      };
    });
    final repository = DashboardWidgetsRepository(client: client);
    expect((await repository.fetchOrdersWidget('demo-token')).todayCount, 1);
    expect((await repository.fetchLatestOrders('demo-token')).orders, isEmpty);
    expect(
        (await repository.fetchCustomerTransactionsSummary('demo-token'))
            .balance,
        -487036.79);
    expect((await repository.fetchSuppliersGraph('demo-token')).counts, [3]);
    expect(paths, [
      '/api/v1/dashboard/orders-widget',
      '/api/v1/dashboard/latest-orders',
      '/api/v1/dashboard/customer-transactions-summary',
      '/api/v1/dashboard/suppliers-graph',
    ]);
  });

  test('no network request is made without tenant or token', () async {
    var calls = 0;
    final repository = DashboardWidgetsRepository(client: MockClient((_) async {
      calls++;
      return _success({});
    }));
    await expectLater(
        repository.fetchOrdersWidget(''), throwsA(isA<HttpException>()));
    SharedPreferences.setMockInitialValues({});
    await expectLater(repository.fetchOrdersWidget('demo-token'),
        throwsA(isA<HttpException>()));
    expect(calls, 0);
  });

  for (final code in [401, 403, 404, 500]) {
    test('HTTP $code remains a widget failure', () async {
      final repository = DashboardWidgetsRepository(
          client: MockClient((_) async => http.Response('failed', code)));
      await expectLater(repository.fetchOrdersWidget('demo-token'),
          throwsA(isA<HttpException>()));
    });
  }

  for (final response in [
    '<html>Login</html>',
    '[]',
    '{"status":"failed","data":{}}',
    '{"status":"success","data":[]}'
  ]) {
    test('invalid or unsuccessful response $response is rejected', () async {
      final repository = DashboardWidgetsRepository(
          client: MockClient((_) async => http.Response(response, 200)));
      await expectLater(
          repository.fetchOrdersWidget('demo-token'), throwsFormatException);
    });
  }

  test('a slow endpoint times out and a later call can retry', () async {
    var calls = 0;
    final slow = Completer<http.Response>();
    final repository = DashboardWidgetsRepository(
      timeout: const Duration(milliseconds: 10),
      client: MockClient((_) {
        calls++;
        return calls == 1
            ? slow.future
            : Future.value(_success(
                {'total_orders_today': 2, 'average_order_amount': 15}));
      }),
    );
    await expectLater(repository.fetchOrdersWidget('demo-token'),
        throwsA(isA<TimeoutException>()));
    expect((await repository.fetchOrdersWidget('demo-token')).todayCount, 2);
    slow.complete(
        _success({'total_orders_today': 99, 'average_order_amount': 1}));
  });
}
