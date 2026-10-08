import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/reports/data/consumed_stocks_report_api.dart';
import 'package:pos_machine/features/reports/data/consumed_stocks_store_directory.dart';
import 'package:pos_machine/providers/report_provider.dart';
import '../support/consumed_stocks_fixtures.dart';
import 'package:pos_machine/features/reports/domain/models/consumed_stocks_report.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(
      {'api_key': 'tenant', 'active_store_id': 4}));
  test(
      'API preserves IDs, date-only bounds, explicit store override and headers',
      () async {
    Uri? request;
    Map<String, String>? capturedHeaders;
    final api = ConsumedStocksReportApi(get: (uri, {headers}) async {
      request = uri;
      return http.Response(jsonEncode(consumedPage(2, last: 2).toJson()), 200);
    });
    // Capture headers separately to avoid shadowing.
    final capture = ConsumedStocksReportApi(get: (uri, {headers}) async {
      request = uri;
      capturedHeaders = headers;
      return http.Response(jsonEncode(consumedPage(2, last: 2).toJson()), 200);
    });
    final result = await capture.fetch(
        accessToken: 'token',
        productId: '12',
        storeId: '9',
        from: '2026-05-01',
        until: '2026-05-31',
        page: 2);
    expect(request!.queryParameters, {
      'product_id': '12',
      'store_id': '9',
      'from': '2026-05-01',
      'until': '2026-05-31',
      'page': '2'
    });
    expect(capturedHeaders, {
      'Authorization': 'Bearer token',
      'Content-Type': 'application/json',
      'X-Tenant': 'tenant'
    });
    expect(result.data!.pagination!.currentPage, 2);
    expect((await api.scope('token')).activeStoreId, 4);
  });
  test('empty selected store falls back to active store; empty fields omitted',
      () async {
    expect(
        ConsumedStocksReportApi.uri(
                endpoint: 'https://example.test',
                storeId: '',
                productId: '',
                from: '',
                until: '',
                activeStoreId: 4)
            .queryParameters,
        {'store_id': '4'});
    expect(
        ConsumedStocksReportApi.uri(endpoint: 'https://example.test')
            .queryParameters,
        isEmpty);
  });
  test('missing tenant does not start transport', () async {
    SharedPreferences.setMockInitialValues({});
    var called = false;
    final api = ConsumedStocksReportApi(get: (uri, {headers}) async {
      called = true;
      return http.Response('{}', 200);
    });
    await expectLater(
        api.fetch(accessToken: 'token'), throwsA(isA<HttpException>()));
    expect(called, false);
  });
  for (final body in [
    '',
    '{}',
    '{"status":"failed","data":{"data":[]}}',
    '{"status":"success","data":[]}',
    '{"status":"success","data":{"data":{}}}'
  ]) {
    test('rejects empty/malformed/unsuccessful envelope $body', () async {
      final api = ConsumedStocksReportApi(
          get: (uri, {headers}) async => http.Response(body, 200));
      await expectLater(api.fetch(accessToken: 'token'), throwsFormatException);
    });
  }
  test('HTTP outage remains an error', () async {
    await expectLater(
        ConsumedStocksReportApi(
                get: (uri, {headers}) async => http.Response('{}', 403))
            .fetch(accessToken: 'token'),
        throwsA(isA<HttpException>()));
  });
  test('provider snapshot never publishes; legacy fetch publishes once',
      () async {
    final provider = ReportsProvider(
        consumedStocksApi: ConsumedStocksReportApi(
            get: (uri, {headers}) async =>
                http.Response(jsonEncode(consumedPage(1).toJson()), 200)));
    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.fetchConsumedStocksReportSnapshot(accessToken: 'token');
    expect(provider.consumedStocksReport, isNull);
    expect(notifications, 0);
    await provider.fetchConsumedStocksReport(accessToken: 'token');
    expect(provider.consumedStocksReport!.data!.data!.single.product, 'Banana');
    expect(notifications, 1);
    provider.dispose();
  });
  test('directory uses cached IDs and labels', () async {
    SharedPreferences.setMockInitialValues({
      'stores':
          '[{"id":9,"store_name":"Store"},{"id":"10","store_name":"Other"}]'
    });
    expect(await consumedStocksStores(), {'9': 'Store', '10': 'Other'});
  });
  test('directory accepts the store_id shape saved by login', () async {
    SharedPreferences.setMockInitialValues({
      'stores': '[{"store_id":2,"store_name":"Store"},'
          '{"store_id":"32","store_name":"Other"},'
          '{"store_id":35,"id":99,"store_name":"Third"}]'
    });
    expect(await consumedStocksStores(),
        {'2': 'Store', '32': 'Other', '35': 'Third'});
  });
  test(
      'missing directory is empty; malformed directory signals only its loader',
      () async {
    SharedPreferences.setMockInitialValues({});
    expect(await consumedStocksStores(), isEmpty);
    SharedPreferences.setMockInitialValues({'stores': 'invalid'});
    await expectLater(consumedStocksStores(), throwsFormatException);
  });
  test(
      'numeric strings normalize record IDs/pagination and preserve quantities',
      () {
    final json = consumedPage(1).toJson();
    json['data']['data'][0]['id'] = '001';
    json['data']['pagination']['per_page'] = '1';
    final row = GetConsumedStocksReportResponse.fromJson(json);
    expect(row.data!.data!.single.id, 1);
    expect(row.data!.data!.single.quantityWithdrawn, '1.000000');
    expect(row.data!.pagination!.perPage, 1);
  });
}
