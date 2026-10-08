import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pos_machine/core/network/tenant_session.dart';
import 'package:pos_machine/features/reports/data/stock_report_api.dart';
import 'package:pos_machine/features/reports/data/stock_report_snapshot.dart';
import 'package:pos_machine/features/reports/domain/models/stock_report.dart';
import 'package:pos_machine/features/reports/domain/models/stock_report_pagination.dart';
import 'package:pos_machine/features/reports/domain/stock_report_query.dart';
import 'package:pos_machine/features/reports/presentation/state/stock_report_controller.dart';
import 'package:pos_machine/providers/report_provider.dart';

class Session extends TenantSession {
  Session({this.tenant = 'tenant', this.store = 9});
  String? tenant;
  int? store;
  @override
  Future<String?> apiKey() async => tenant;
  @override
  Future<int?> activeStoreId() async => store;
}

const scope =
    (token: 'token', tenant: 'tenant', activeStoreId: 9, endpoint: 'stock');
GetStockReportResponse response(int page,
        {int last = 3, int perPage = 1, int? total, String? name}) =>
    GetStockReportResponse(
        status: 'success',
        message: '',
        data: [
          StockReportData(id: page, name: name ?? 'Row $page', barcode: '00123')
        ],
        pagination: StockReportPagination(
            currentPage: page, lastPage: last, perPage: perPage, total: total));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'URI preserves product names, dates, enums, sort and active store fallback',
      () {
    final uri = StockReportApi.uri(
        endpoint: 'https://example.com/stock',
        product: '12 BARBECUE CUBES',
        categoryId: 4,
        activeStoreId: 9,
        stockLevel: 'below_reorder',
        expiringWithin: 'three_months',
        snapshotDate: '2026-10-01',
        from: '2026-09-01',
        until: '2026-10-06',
        page: 2,
        perPage: 250,
        sortBy: 'name',
        sortDirection: 'asc');
    expect(uri.queryParameters, {
      'product': '12 BARBECUE CUBES',
      'category_id': '4',
      'store_id': '9',
      'stock_level': 'below_reorder',
      'expiring_within': 'three_months',
      'snapshot_date': '2026-10-01',
      'from': '2026-09-01',
      'until': '2026-10-06',
      'page': '2',
      'per_page': '250',
      'sort_by': 'name',
      'sort_direction': 'asc'
    });
    expect(
        StockReportApi.uri(
                endpoint: 'https://example.com',
                storeId: 3,
                activeStoreId: 9,
                stockLevel: 'All',
                expiringWithin: 'All')
            .queryParameters,
        {'store_id': '3'});
  });
  test('transport uses bearer tenant and parses successful empty flat data',
      () async {
    final api = StockReportApi(
        session: Session(),
        get: (uri, {headers}) async {
          expect(headers,
              TenantSession.headers(accessToken: 'token', apiKey: 'tenant'));
          expect(uri.queryParameters['store_id'], '9');
          return http.Response(
              jsonEncode({'status': 'success', 'data': []}), 200);
        });
    expect((await api.fetch(accessToken: 'token')).data, isEmpty);
  });
  for (final body in ['', '{}', '{"data":{}}', '{"data":"wrong"}', 'invalid']) {
    test('empty or malformed envelope fails: $body', () async {
      final api = StockReportApi(
          session: Session(),
          get: (uri, {headers}) async => http.Response(body, 200));
      await expectLater(
          api.fetch(accessToken: 'token'), throwsA(isA<Exception>()));
    });
  }
  test(
      'missing tenant and failed endpoint fail without publishing empty success',
      () async {
    var calls = 0;
    final session = Session(tenant: null);
    final api = StockReportApi(
        session: session,
        get: (uri, {headers}) async {
          calls++;
          return http.Response('{}', 403);
        });
    await expectLater(
        api.fetch(accessToken: 'token'), throwsA(isA<Exception>()));
    expect(calls, 0);
    session.tenant = 'tenant';
    await expectLater(
        api.fetch(accessToken: 'token'), throwsA(isA<Exception>()));
    expect(calls, 1);
  });
  test('legacy provider publishes once; snapshot never overwrites shared rows',
      () async {
    var id = 0, notifications = 0;
    final provider = ReportsProvider(
        stockReportApi: StockReportApi(
            session: Session(),
            get: (uri, {headers}) async => http.Response(
                jsonEncode({
                  'status': 'success',
                  'data': [
                    {'id': ++id, 'name': 'P$id'}
                  ]
                }),
                200)));
    addTearDown(provider.dispose);
    provider.addListener(() => notifications++);
    await provider.fetchStockReport(accessToken: 'token');
    final original = provider.stockReport;
    expect(notifications, 1);
    expect(
        (await provider.fetchStockReportSnapshot(accessToken: 'token'))
            .data
            .first
            .id,
        2);
    expect(provider.stockReport, same(original));
    expect(notifications, 1);
  });
  test('date-only query accepts same day and maps every expiry value', () {
    expect(
        StockReportQuery(
                from: DateTime(2026, 10, 6, 23), until: DateTime(2026, 10, 6))
            .valid,
        isTrue);
    expect(
        StockReportQuery(
                from: DateTime(2026, 10, 7), until: DateTime(2026, 10, 6))
            .valid,
        isFalse);
    expect([
      for (final expiry in StockExpiry.values)
        StockReportQuery(expiry: expiry).expiryParameter
    ], [
      null,
      'one_month',
      'three_months',
      'six_months',
      'one_year'
    ]);
  });
  test('all pages keep filters, preserve table state and report progress',
      () async {
    final calls = <(StockReportQuery, int, int?)>[];
    final controller = StockReportController(
        readScope: () async => scope,
        fetch: (q, p, size) async {
          calls.add((q, p, size));
          return response(p, total: 3);
        });
    addTearDown(controller.dispose);
    controller.store = const StockReportOption('3', 'Store');
    controller.category = const StockReportOption('4', 'Category');
    controller.product = const StockReportOption('Name', 'Name');
    controller.stockLevel = StockLevel.belowReorder;
    controller.expiry = StockExpiry.oneYear;
    controller.snapshot = DateTime(2026, 10, 1);
    controller.from = DateTime(2026, 9, 1);
    controller.until = DateTime(2026, 10, 6);
    await controller.load(requestedPage: 2);
    final visible = controller.report;
    final progress = <(int, int)>[];
    final rows = await controller.export(
        build: (rows) async => rows,
        permissionUnchanged: () => true,
        progress: (p, n) => progress.add((p, n)));
    expect(rows.map((r) => r.id), [1, 2, 3]);
    expect(progress, [(1, 3), (2, 3), (3, 3)]);
    expect(controller.report, same(visible));
    expect(controller.page, 2);
    for (final call in calls.skip(1)) {
      expect(call.$1.matches(calls.first.$1), isTrue);
      expect(call.$3, 250);
    }
    await controller.reset();
    expect(controller.query.active, isFalse);
    expect(controller.resetRevision, 1);
    expect(controller.page, 1);
  });
  test(
      'failed filter change keeps rows but retries page one and blocks Next/export',
      () async {
    var fail = false;
    final pages = <int>[];
    final c = StockReportController(
        readScope: () async => scope,
        fetch: (q, p, size) async {
          pages.add(p);
          if (fail) throw StateError('offline');
          return response(p);
        });
    addTearDown(c.dispose);
    await c.load(requestedPage: 2);
    final old = c.report;
    fail = true;
    await c.setStore(const StockReportOption('4', 'Store'));
    expect(c.report, same(old));
    expect(c.canExport, isFalse);
    await c.goToPage(3);
    expect(pages, [2, 1]);
    fail = false;
    await c.retry();
    expect(pages, [2, 1, 1]);
    expect(c.page, 1);
  });
  test('invalid range makes no request and can recover', () async {
    var calls = 0;
    final c = StockReportController(
        readScope: () async => scope,
        fetch: (q, p, size) async {
          calls++;
          return response(p);
        });
    addTearDown(c.dispose);
    c.from = DateTime(2026, 10, 7);
    c.until = DateTime(2026, 10, 6);
    await c.load();
    expect(c.errorKey, 'stock_report.invalid_date_range');
    expect(calls, 0);
    await c.setDate(null, 'until');
    expect(c.errorKey, isNull);
    expect(calls, 1);
  });
  test('refresh past a shrunken last page moves to the new last page',
      () async {
    var last = 5;
    final pages = <int>[];
    final c = StockReportController(
        readScope: () async => scope,
        fetch: (q, p, size) async {
          pages.add(p);
          return response(p, last: last);
        });
    addTearDown(c.dispose);
    await c.load(requestedPage: 5);
    last = 3;
    await c.retry();
    expect(pages, [5, 5, 3]);
    expect(c.errorKey, isNull);
    expect(c.page, 3);
    expect(c.totalPages, 3);
    await c.retry();
    expect(pages, [5, 5, 3, 3]);
  });
  test('failed page load keeps paging available for the same filters',
      () async {
    var fail = false;
    final pages = <int>[];
    final c = StockReportController(
        readScope: () async => scope,
        fetch: (q, p, size) async {
          pages.add(p);
          if (fail) throw StateError('offline');
          return response(p);
        });
    addTearDown(c.dispose);
    await c.load(requestedPage: 2);
    fail = true;
    await c.goToPage(3);
    expect(c.errorKey, 'stock_report.unavailable');
    fail = false;
    await c.goToPage(1);
    expect(pages, [2, 3, 1]);
    expect(c.errorKey, isNull);
    expect(c.page, 1);
  });
  test('rapid filters serialize work and discard the earlier result', () async {
    final pending = Completer<GetStockReportResponse>(),
        entered = Completer<void>();
    final names = <String?>[];
    final c = StockReportController(
        readScope: () async => scope,
        fetch: (q, p, size) async {
          names.add(q.product);
          if (names.length == 1) {
            entered.complete();
            return pending.future;
          }
          return response(p, name: q.product);
        });
    addTearDown(c.dispose);
    final initial = c.load();
    await entered.future;
    await c.setProduct(const StockReportOption('Old', 'Old'));
    await c.setProduct(const StockReportOption('Latest', 'Latest'));
    pending.complete(response(1, name: 'stale'));
    await initial;
    expect(names, [null, 'Latest']);
    expect(c.report!.data.first.name, 'Latest');
    expect(c.loading, isFalse);
  });
  for (final change in ['filter', 'permission', 'scope', 'dispose']) {
    test('export is canceled after $change changes during fetch', () async {
      var permission = true, exporting = false, currentScope = scope;
      final entered = Completer<void>(),
          pending = Completer<GetStockReportResponse>();
      final c = StockReportController(
          readScope: () async => currentScope,
          fetch: (q, p, size) async {
            if (exporting) {
              entered.complete();
              return pending.future;
            }
            return response(p);
          });
      await c.load();
      exporting = true;
      var built = false;
      final export = c.export(
          build: (rows) async {
            built = true;
            return rows;
          },
          permissionUnchanged: () => permission);
      final expectation = expectLater(export, throwsStateError);
      await entered.future;
      switch (change) {
        case 'filter':
          c.from = DateTime(2026);
          break;
        case 'permission':
          permission = false;
          break;
        case 'scope':
          currentScope = (
            token: 'other',
            tenant: 'tenant',
            activeStoreId: 9,
            endpoint: 'stock'
          );
          break;
        case 'dispose':
          c.dispose();
          break;
      }
      pending.complete(response(1));
      await expectation;
      expect(built, isFalse);
      if (change != 'dispose') c.dispose();
    });
  }
  test('permission changed while workbook builds prevents delivery', () async {
    var permission = true;
    final c = StockReportController(
        readScope: () async => scope, fetch: (q, p, size) async => response(p));
    addTearDown(c.dispose);
    await c.load();
    await expectLater(
        c.export(
            build: (rows) async {
              permission = false;
              return rows;
            },
            permissionUnchanged: () => permission),
        throwsStateError);
  });
  test('flat legacy report exports as a single response', () async {
    final rows = await stockReportSnapshot((p) async => GetStockReportResponse(
        status: 'success',
        message: '',
        data: [StockReportData(id: 1, name: 'A')]));
    expect(rows.single.name, 'A');
  });
  for (final shape in ['flat', 'single-page', 'overlap', 'overlap-no-total']) {
    test('export refuses duplicate product IDs in $shape responses', () async {
      await expectLater(stockReportSnapshot((p) async {
        final single = shape == 'flat' || shape == 'single-page';
        return GetStockReportResponse(
            status: 'success',
            message: '',
            data: [
              StockReportData(id: 7, name: 'Product A'),
              if (single) StockReportData(id: 7, name: 'Product A'),
            ],
            pagination: shape == 'flat'
                ? null
                : StockReportPagination(
                    currentPage: p,
                    lastPage: single ? 1 : 2,
                    perPage: single ? 2 : 1,
                    total: shape == 'overlap-no-total' ? null : 2));
      }), throwsStateError);
    });
  }
  test('overlapping export stops before building and preserves visible rows',
      () async {
    final pages = <int>[];
    final c = StockReportController(
        readScope: () async => scope,
        fetch: (q, p, size) async {
          if (size == null) return response(p);
          pages.add(p);
          return GetStockReportResponse(
              status: 'success',
              message: '',
              data: [StockReportData(id: 7, name: 'Repeated product')],
              pagination: StockReportPagination(
                  currentPage: p, lastPage: 3, perPage: 1, total: 3));
        });
    addTearDown(c.dispose);
    await c.load();
    final visible = c.report;
    var built = false;
    await expectLater(
        c.export(
            build: (rows) async {
              built = true;
              return rows;
            },
            permissionUnchanged: () => true),
        throwsStateError);
    expect(built, isFalse);
    expect(pages, [1, 2]);
    expect(c.report, same(visible));
    expect(c.canExport, isTrue);
  });
  for (final defect in [
    'wrong-page',
    'last-page',
    'per-page',
    'total',
    'missing-page',
    'empty-page',
    'partial-error'
  ]) {
    test('export refuses $defect rather than delivering a partial file',
        () async {
      await expectLater(stockReportSnapshot((p) async {
        if (p == 1) return response(1, total: 3);
        return switch (defect) {
          'wrong-page' => response(1, total: 3),
          'last-page' => response(p, last: 4, total: 3),
          'per-page' => response(p, perPage: 2, total: 3),
          'total' => response(p, total: 4),
          'missing-page' =>
            GetStockReportResponse(status: 'success', message: '', data: []),
          'empty-page' => GetStockReportResponse(
              status: 'success',
              message: '',
              data: [],
              pagination: StockReportPagination(
                  currentPage: p, lastPage: 3, perPage: 1, total: 3)),
          _ => throw StateError('offline'),
        };
      }), throwsStateError);
    });
  }
  test(
      'declared total mismatch fails and no arbitrary total page limit applies',
      () async {
    await expectLater(
        stockReportSnapshot((p) async => response(p, last: 1, total: 2)),
        throwsStateError);
    expect(await stockReportSnapshot((p) async => response(p, last: 1001)),
        hasLength(1001));
  });
}
