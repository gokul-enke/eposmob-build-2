import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/reports/data/sales_report_api.dart';
import 'package:pos_machine/features/reports/data/sales_report_snapshot.dart';
import 'package:pos_machine/features/reports/domain/models/sales_report.dart';

class _Session extends TenantSession {
  const _Session(this.tenant);
  final String? tenant;
  @override
  Future<String?> apiKey() async => tenant;
  @override
  Future<int?> activeStoreId() async => 2;
}

SalesReportRow _row(int id) =>
    SalesReportRow(orderId: id, orderNumber: 'ORD-$id');

SalesReportResponse _page(int page, List<int> ids,
        {int last = 2, int per = 2, int? total = 4}) =>
    SalesReportResponse(
        rows: [for (final id in ids) _row(id)],
        currentPage: page,
        lastPage: last,
        perPage: per,
        total: total);

void main() {
  group('SalesReportApi', () {
    test('sends filters, paging and tenant headers, but not the active store',
        () async {
      late Uri uri;
      late Map<String, String> sent;
      final api = SalesReportApi(
          endpoint: () => 'https://x.test/api/v1/sales-report',
          session: const _Session('tenant'),
          get: (u, {headers}) async {
            uri = u;
            sent = headers!;
            return http.Response(
                jsonEncode({
                  'status': 'success',
                  'data': [
                    {'order_id': 1, 'order_number': 'ORD-1'}
                  ]
                }),
                200);
          });
      final page = await api.fetch(
          accessToken: 'token',
          parameters: {'store_ids': '5,6', 'period': 'this_month'},
          page: 3,
          perPage: 25);
      expect(page.rows.single.orderNumber, 'ORD-1');
      expect(uri.path, '/api/v1/sales-report');
      // The Stores filter is the only store sent: the session's active store
      // (2) must not narrow this all-store report.
      expect(uri.queryParameters, {
        'store_ids': '5,6',
        'period': 'this_month',
        'page': '3',
        'per_page': '25',
      });
      expect(sent['Authorization'], 'Bearer token');
      expect(sent['X-Tenant'], 'tenant');
    });

    test('the scope names the token, tenant, active store and endpoint',
        () async {
      var base = 'https://a.test';
      final api = SalesReportApi(
          endpoint: () => '$base/api/v1/sales-report',
          session: const _Session('tenant'));
      expect(await api.scope('t'), (
        token: 't',
        tenant: 'tenant',
        activeStoreId: 2,
        endpoint: 'https://a.test/api/v1/sales-report'
      ));
      base = 'https://b.test'; // the endpoint follows the login
      expect((await api.scope('t')).endpoint,
          'https://b.test/api/v1/sales-report');
      expect(SalesReportApi().endpoint(), endsWith('/api/v1/sales-report'));
    });

    test('fails without tenant, on HTTP errors and bad bodies', () async {
      Future<void> expectFail(String? tenant, http.Response response) {
        final api = SalesReportApi(
            endpoint: () => 'https://x.test/r',
            session: _Session(tenant),
            get: (_, {headers}) async => response);
        return expectLater(
            api.fetch(
                accessToken: 't', parameters: const {}, page: 1, perPage: 25),
            throwsA(anyOf(isA<HttpException>(), isA<FormatException>())));
      }

      await expectFail(null, http.Response('{}', 200));
      await expectFail('', http.Response('{}', 200));
      await expectFail('tenant', http.Response('boom', 500));
      await expectFail('tenant', http.Response('', 200));
      await expectFail('tenant',
          http.Response(jsonEncode({'status': 'failed', 'data': null}), 200));
    });

    test('sales executives directory: all stores, incomplete rows skipped',
        () async {
      late Uri asked;
      final api = SalesReportApi(
          endpoint: () => 'https://x.test/r',
          session: const _Session('tenant'),
          get: (u, {headers}) async => (
                asked = u,
                http.Response(
                    jsonEncode({
                      'status': 'success',
                      'data': [
                        {'id': 4, 'name': 'salesexecutiv2'},
                        {'id': null, 'name': 'no id'},
                        {'id': 5, 'name': ' '},
                      ]
                    }),
                    200)
              ).$2);
      final options = await api.salesExecutives('t');
      expect(options.map((o) => (o.id, o.label)), [('4', 'salesexecutiv2')]);
      expect(asked.path, endsWith('/api/v1/list-sales-executives'));
      expect(asked.queryParameters, isEmpty);
    });

    test('a malformed sales executives response fails', () async {
      final api = SalesReportApi(
          endpoint: () => 'https://x.test/r',
          session: const _Session('tenant'),
          get: (_, {headers}) async =>
              http.Response(jsonEncode({'status': 'success'}), 200));
      await expectLater(api.salesExecutives('t'), throwsFormatException);
    });
  });

  group('salesReportSnapshot', () {
    test('reads every page in order with progress', () async {
      final progress = <(int, int)>[];
      final rows = await salesReportSnapshot(
          (p) async => p == 1 ? _page(1, [1, 2]) : _page(2, [3, 4]),
          progress: (p, t) => progress.add((p, t)));
      expect(rows.map((r) => r.orderId), [1, 2, 3, 4]);
      expect(progress, [(1, 2), (2, 2)]);
    });

    test('rejects overlaps, changing pagination and short results', () async {
      Future<void> fails(SalesReportResponse second) => expectLater(
          salesReportSnapshot((p) async => p == 1 ? _page(1, [1, 2]) : second),
          throwsStateError);

      await fails(_page(2, [2, 3])); // overlap
      await fails(_page(2, [3, 4], last: 3)); // last page moved
      await fails(_page(2, [3, 4], per: 3)); // page size moved
      await fails(_page(2, [3, 4], total: 5)); // total moved
      await fails(_page(1, [3, 4])); // wrong page number
      await fails(_page(2, [3])); // total says 4, got 3
      await fails(_page(2, [3, 4, 5])); // more rows than a page holds
      await expectLater(
          salesReportSnapshot(
              (p) async => _page(1, [1], last: 2)), // short non-last page
          throwsStateError);
    });

    test('refuses absurd page counts', () async {
      await expectLater(
          salesReportSnapshot(
              (p) async => _page(1, [1], last: 5000, per: 1, total: null),
              maxPages: 1000),
          throwsStateError);
    });
  });
}
