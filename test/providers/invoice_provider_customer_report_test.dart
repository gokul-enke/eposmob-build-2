import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/reports/support/report_fixtures.dart';

/// `InvoiceProvider.listAllTransaction` as the Customer Transactions Report
/// uses it (`updateState: false`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('forwards page and filters without touching shared state', () async {
    SharedPreferences.setMockInitialValues(
        {'api_key': 'test', 'active_store_id': 7});
    final provider = InvoiceProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);
    await http.runWithClient(() async {
      final result = await provider.listAllTransaction(
          accessToken: 'token',
          customerId: '42',
          dateFrom: '2026-09-01 00:00:00',
          page: 2,
          updateState: false);
      expect(result['status'], 'success');
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters['page'], '2');
              expect(request.url.queryParameters['customer_id'], '42');
              expect(request.url.queryParameters['date_from'],
                  '2026-09-01 00:00:00');
              expect(request.url.queryParameters['store_id'], '7');
              expect(request.headers['X-Tenant'], 'test');
              return http.Response(
                  jsonEncode(
                      customerReportResponse(2, [customerGroup(42)], last: 2)),
                  200);
            }));
    expect(notifications, 0);
    expect(provider.transactionListDetails, isNull);
  });

  test('an HTTP failure throws instead of returning an empty report', () async {
    SharedPreferences.setMockInitialValues({'api_key': 'test'});
    await http.runWithClient(() async {
      await expectLater(
          InvoiceProvider()
              .listAllTransaction(accessToken: 'test', updateState: false),
          throwsA(isA<HttpException>()));
    },
        () => MockClient(
            (_) async => http.Response('{"status":"success"}', 500)));
  });
}
