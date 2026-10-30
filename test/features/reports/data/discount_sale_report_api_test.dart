import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/reports/data/discount_sale_report_api.dart';
import 'package:pos_machine/features/reports/data/discount_sale_report_snapshot.dart';
import 'package:pos_machine/features/reports/domain/models/discount_sale_report.dart';
import 'package:pos_machine/resources/app_url.dart';

class _Session extends TenantSession {
  const _Session(this.tenant);
  final String? tenant;
  @override
  Future<String?> apiKey() async => tenant;
  @override
  Future<int?> activeStoreId() async => 2;
}

DiscountSaleReportRow _row(int id) =>
    DiscountSaleReportRow(orderId: id, orderNumber: 'ORD-$id');

DiscountSaleReportResponse _page(int page, List<int> ids,
        {int last = 2, int per = 2, int? total = 4}) =>
    DiscountSaleReportResponse(
        rows: [for (final id in ids) _row(id)],
        currentPage: page,
        lastPage: last,
        perPage: per,
        total: total);

void main() {
  group('DiscountSaleReportApi', () {
    test('sends filters, paging and tenant headers, but not the active store',
        () async {
      late Uri uri;
      late Map<String, String> sent;
      final api = DiscountSaleReportApi(
          endpoint: () => 'https://x.test/api/v1/discount-sales-report',
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
          parameters: {'store_id': '5', 'sales_date_range': 'month'},
          page: 3,
          perPage: 25);
      expect(page.rows.single.orderNumber, 'ORD-1');
      expect(uri.path, '/api/v1/discount-sales-report');
      // The Store filter is the only store sent: the session's active store
      // (2) must not narrow this all-store report.
      expect(uri.queryParameters, {
        'store_id': '5',
        'sales_date_range': 'month',
        'page': '3',
        'per_page': '25',
      });
      expect(sent['Authorization'], 'Bearer token');
      expect(sent['X-Tenant'], 'tenant');
    });

    test('scope: token, tenant, active store and the live endpoint', () async {
      var endpoint = 'https://a.test/r';
      final api = DiscountSaleReportApi(
          endpoint: () => endpoint, session: const _Session('tenant'));
      expect(await api.scope('t'),
          (token: 't', tenant: 'tenant', activeStoreId: 2, endpoint: endpoint));
      endpoint = 'https://b.test/r';
      expect((await api.scope('t')).endpoint, 'https://b.test/r');
      // Without an injected endpoint, the app's discount report URL.
      expect(
          (await DiscountSaleReportApi(session: const _Session('tenant'))
                  .scope('t'))
              .endpoint,
          APPUrl.discountSaleReport);
    });

    test('fails without tenant, on HTTP errors, empty and invalid bodies',
        () async {
      Future<void> expectFail(String? tenant, http.Response response) {
        final api = DiscountSaleReportApi(
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
      await expectFail(
          'tenant',
          http.Response(
              jsonEncode({'status': 'failed', 'message': 'no company'}), 200));
    });

    test('sales executives directory: all stores, incomplete rows skipped',
        () async {
      late Uri asked;
      late Map<String, String> sent;
      final api = DiscountSaleReportApi(
          endpoint: () => 'https://x.test/r',
          session: const _Session('tenant'),
          get: (u, {headers}) async {
            asked = u;
            sent = headers!;
            return http.Response(
                jsonEncode({
                  'status': 'success',
                  'data': [
                    {'id': 4, 'name': 'salesexecutiv2'},
                    {
                      'id': '6',
                      'name': {'name': 'Mapped'}
                    },
                    {'id': null, 'name': 'no id'},
                    {'id': 5, 'name': ' '},
                    'x',
                  ]
                }),
                200);
          });
      final options = await api.salesExecutives('t');
      expect(options.map((o) => (o.id, o.label)),
          [('4', 'salesexecutiv2'), ('6', 'Mapped')]);
      expect(asked.path, endsWith('/api/v1/list-sales-executives'));
      expect(asked.queryParameters, isEmpty);
      expect(sent['X-Tenant'], 'tenant');
    });

    test('sales executives: an invalid response fails', () async {
      final api = DiscountSaleReportApi(
          session: const _Session('tenant'),
          get: (_, {headers}) async =>
              http.Response(jsonEncode({'status': 'success'}), 200));
      await expectLater(api.salesExecutives('t'), throwsFormatException);
    });
  });

  group('discountSaleReportSnapshot', () {
    test('reads every page in order with progress', () async {
      final progress = <(int, int)>[];
      final rows = await discountSaleReportSnapshot(
          (p) async => p == 1 ? _page(1, [1, 2]) : _page(2, [3, 4]),
          progress: (p, t) => progress.add((p, t)));
      expect(rows.map((r) => r.orderId), [1, 2, 3, 4]);
      expect(progress, [(1, 2), (2, 2)]);
    });

    test('rejects overlaps, changing pagination and short results', () async {
      Future<void> fails(DiscountSaleReportResponse second) => expectLater(
          discountSaleReportSnapshot(
              (p) async => p == 1 ? _page(1, [1, 2]) : second),
          throwsStateError);

      await fails(_page(2, [2, 3])); // overlap
      await fails(_page(2, [3, 4], last: 3)); // last page moved
      await fails(_page(2, [3, 4], per: 3)); // page size moved
      await fails(_page(2, [3, 4], total: 5)); // total moved
      await fails(_page(1, [3, 4])); // wrong page number
      await fails(_page(2, [3])); // total says 4, got 3
      await expectLater(
          discountSaleReportSnapshot(
              (p) async => _page(1, [1], last: 2)), // short non-last page
          throwsStateError);
      await expectLater(
          discountSaleReportSnapshot(
              (p) async => _page(1, [1, 2, 3], last: 1, total: 3)), // > per
          throwsStateError);
    });

    test('refuses absurd page counts', () async {
      await expectLater(
          discountSaleReportSnapshot(
              (p) async => _page(1, [1], last: 5000, per: 1, total: null),
              maxPages: 1000),
          throwsStateError);
    });
  });
}
