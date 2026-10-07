import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/reports/data/non_stock_report_api.dart';
import 'package:pos_machine/features/reports/domain/models/non_stock_report.dart';
import 'package:pos_machine/providers/report_provider.dart';

class _Session extends TenantSession {
  const _Session({this.key = 'tenant'});
  final String? key;
  final int? store = 4;
  @override
  Future<String?> apiKey() async => key;
  @override
  Future<int?> activeStoreId() async => store;
}

void main() {
  test('preserves name filters, raw barcode, active store and existing headers',
      () async {
    late Uri uri;
    Map<String, String>? receivedHeaders;
    final api = NonStockReportApi(
        session: const _Session(),
        get: (u, {headers}) async {
          uri = u;
          receivedHeaders = headers;
          return http.Response(
              jsonEncode({'status': 'success', 'data': []}), 200);
        });
    await api.fetch(
        accessToken: 'token',
        store: 'متجر / 1',
        category: 'General Item',
        product: 'Product & 1',
        barcode: ' 0012 ',
        page: 3);
    expect(uri.path, '/api/v1/non-stock-report');
    expect(uri.queryParameters, {
      'store': 'متجر / 1',
      'category': 'General Item',
      'product': 'Product & 1',
      'barcode': ' 0012 ',
      'page': '3',
      'store_id': '4'
    });
    expect(receivedHeaders, {
      'Authorization': 'Bearer token',
      'Content-Type': 'application/json',
      'X-Tenant': 'tenant'
    });
  });
  test('empty filters and absent active store do not introduce new parameters',
      () {
    expect(
        NonStockReportApi.uri(
                endpoint: 'https://example.test/report', store: '', barcode: '')
            .queryParameters,
        isEmpty);
  });
  test('missing tenant stops before transport', () async {
    final api = NonStockReportApi(
        session: const _Session(key: null),
        get: (_, {headers}) async =>
            throw StateError('transport must not run'));
    await expectLater(
        api.fetch(accessToken: 'token'), throwsA(isA<HttpException>()));
  });
  for (final invalid in [
    '',
    '{}',
    '{"status":"failed","data":[]}',
    '{"status":"success","data":{}}',
    'not json'
  ]) {
    test('does not turn invalid body $invalid into empty success', () async {
      final api = NonStockReportApi(
          session: const _Session(),
          get: (_, {headers}) async => http.Response(invalid, 200));
      await expectLater(
          api.fetch(accessToken: 'token'), throwsA(isA<FormatException>()));
    });
  }
  test('directory-independent HTTP failures remain errors', () async {
    final api = NonStockReportApi(
        session: const _Session(),
        get: (_, {headers}) async => http.Response('{}', 403));
    await expectLater(
        api.fetch(accessToken: 'token'), throwsA(isA<HttpException>()));
  });
  test(
      'legacy provider notifies once; snapshot fetching never mutates shared rows',
      () async {
    var id = 1;
    final api = NonStockReportApi(
        session: const _Session(),
        get: (_, {headers}) async => http.Response(
            jsonEncode({
              'status': 'success',
              'data': [
                {'id': id++, 'name': 'A', 'total_quantity': '0.125'}
              ]
            }),
            200));
    final provider = ReportsProvider(nonStockApi: api);
    var notifications = 0;
    provider.addListener(() => notifications++);
    await provider.fetchNonStockReport(accessToken: 'token');
    final visible = provider.nonStockReport;
    final snapshot =
        await provider.fetchNonStockReportSnapshot(accessToken: 'token');
    expect(notifications, 1);
    expect(provider.nonStockReport, same(visible));
    expect(snapshot.data.single.id, 2);
    expect(snapshot.data.single.totalQuantity, '0.125');
    provider.dispose();
  });
  test('flat and nested unpaginated responses stay single-page', () {
    for (final data in [
      [],
      {'data': []}
    ]) {
      expect(
          GetNonStockReportResponse.fromJson(
              {'status': 'success', 'data': data}).pagination,
          isNull);
    }
  });
}
