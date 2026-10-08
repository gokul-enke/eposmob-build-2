import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/models/consumed_stocks_report.dart';
import 'package:pos_machine/features/reports/presentation/state/consumed_stocks_report_controller.dart';
import '../../support/consumed_stocks_fixtures.dart';

void main() {
  ConsumedStocksReportController controller({ConsumedStocksFetch? fetch}) =>
      ConsumedStocksReportController(
          fetch: fetch ?? (q, p) async => consumedPage(p),
          readScope: () async => consumedScope,
          loadStores: () async => {});
  test('directory outage cannot prevent initial unfiltered table', () async {
    final c = ConsumedStocksReportController(
        fetch: (q, p) async => consumedPage(p),
        readScope: () async => consumedScope,
        loadStores: () async => throw StateError('directory outage'));
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.report!.data!.data!.single.id, 1);
    expect(c.stores, isEmpty);
    expect(c.errorKey, isNull);
  });
  test('in-flight directory loads are reused and late disposal is safe',
      () async {
    var calls = 0;
    final pending = Completer<Map<String, String>>();
    final c = ConsumedStocksReportController(
        fetch: (q, p) async => consumedPage(p),
        readScope: () async => consumedScope,
        loadStores: () {
          calls++;
          return pending.future;
        });
    final a = c.refreshStores(), b = c.refreshStores();
    expect(calls, 1);
    c.dispose();
    pending.complete({'9': 'Store'});
    await Future.wait([a, b]);
    expect(c.stores, isEmpty);
  });
  test('filter failure retains rows but retry uses first page/new IDs',
      () async {
    var fail = false;
    final calls = <ConsumedCall>[];
    final c = controller(fetch: (q, p) async {
      calls.add((query: q, page: p));
      if (fail) throw StateError('outage');
      return consumedPage(p, last: 3);
    });
    addTearDown(c.dispose);
    await c.load();
    await c.goToPage(3);
    fail = true;
    await c.setProduct('12');
    expect(c.page, 3);
    expect(c.canExport, false);
    await c.goToPage(2);
    expect(calls.last.page, 1);
    fail = false;
    await c.retry();
    expect(c.page, 1);
    expect(calls.last.query.productId, '12');
  });
  test('inverted dates never fetch; clear/reset restores all fields and page',
      () async {
    final calls = <ConsumedCall>[];
    final c = controller(fetch: (q, p) async {
      calls.add((query: q, page: p));
      return consumedPage(p);
    });
    addTearDown(c.dispose);
    await c.setStore('9');
    await c.setProduct('12');
    await c.setFrom(DateTime(2026, 5, 31, 15));
    await c.setUntil(DateTime(2026, 5, 1));
    expect(c.errorKey, 'consumed_stocks_report.invalid_dates');
    expect(calls.length, 3);
    expect(c.canExport, false);
    await c.setUntil(DateTime(2026, 5, 31));
    expect(c.errorKey, isNull);
    expect(calls.last.query.apiFrom, '2026-05-31');
    await c.reset();
    expect(c.query.isEmpty, true);
    expect(c.resetRevision, 1);
    expect(c.page, 1);
    expect(calls.last.query.isEmpty, true);
  });
  test('older failures cannot replace newer filters', () async {
    final old = Completer<GetConsumedStocksReportResponse>();
    final c = controller(
        fetch: (q, p) => q.productId == null
            ? old.future
            : Future.value(consumedPage(1, rows: [consumedRow(2)])));
    addTearDown(c.dispose);
    final first = c.load();
    await Future<void>.delayed(Duration.zero);
    await c.setProduct('2');
    old.completeError(StateError('late'));
    await first;
    expect(c.report!.data!.data!.single.id, 2);
    expect(c.errorKey, isNull);
  });
  test('paging and refresh during export do not cancel its captured query',
      () async {
    final delayed = Completer<GetConsumedStocksReportResponse>();
    var exporting = false;
    final calls = <ConsumedCall>[];
    final c = controller(fetch: (q, p) {
      calls.add((query: q, page: p));
      if (exporting && p == 1) return delayed.future;
      return Future.value(consumedPage(p, last: 2, total: 2));
    });
    addTearDown(c.dispose);
    await c.setProduct('12');
    await c.goToPage(2);
    exporting = true;
    final result = c.export(
        build: (rows) async => rows.length, permissionUnchanged: () => true);
    await Future<void>.delayed(Duration.zero);
    await c.retry();
    exporting = false;
    await c.goToPage(1);
    delayed.complete(consumedPage(1, last: 2, total: 2));
    expect(await result, 2);
    expect(c.page, 1);
    expect(calls.map((x) => x.query.productId), everyElement('12'));
  });
  for (final cause in [
    'filter',
    'reset',
    'session',
    'permission',
    'dispose',
    'during build'
  ]) {
    test('export stops safely when $cause changes', () async {
      var exporting = false,
          scope = consumedScope,
          allowed = true,
          built = false;
      final pending = Completer<GetConsumedStocksReportResponse>();
      final c = ConsumedStocksReportController(
          fetch: (q, p) =>
              exporting ? pending.future : Future.value(consumedPage(p)),
          readScope: () async => scope,
          loadStores: () async => {});
      await c.load();
      exporting = true;
      final result = c.export(
          build: (rows) async {
            built = true;
            if (cause == 'during build') await c.setStore('9');
            return rows.length;
          },
          permissionUnchanged: () => allowed);
      final assertion =
          expectLater(result, throwsA(isA<ConsumedStocksExportCancelled>()));
      await Future<void>.delayed(Duration.zero);
      if (cause == 'filter') {
        exporting = false;
        await c.setFrom(DateTime(2026, 1, 1));
      }
      if (cause == 'reset') {
        exporting = false;
        await c.reset();
      }
      if (cause == 'session') {
        scope = (
          token: 'new',
          tenant: 'tenant',
          activeStoreId: 4,
          endpoint: consumedScope.endpoint
        );
      }
      if (cause == 'permission') allowed = false;
      if (cause == 'dispose') c.dispose();
      exporting = false;
      pending.complete(consumedPage(1));
      await assertion;
      expect(built, cause == 'during build');
      if (cause != 'dispose') c.dispose();
    });
  }
  test(
      'optional listing pagination remains compatible; export rejects incomplete metadata',
      () async {
    final c = controller(
        fetch: (q, p) async => GetConsumedStocksReportResponse(
            status: 'success',
            data: Data(
                data: [consumedRow(p)], pagination: Pagination(lastPage: 2))));
    addTearDown(c.dispose);
    await c.load();
    expect(c.perPage, 25);
    await c.goToPage(2);
    expect(c.page, 2);
    await expectLater(
        c.export(build: (r) async => r.length, permissionUnchanged: () => true),
        throwsStateError);
  });
}
