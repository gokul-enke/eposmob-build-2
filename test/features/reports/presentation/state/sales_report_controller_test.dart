import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/sales_report_snapshot.dart';
import 'package:pos_machine/features/reports/domain/models/sales_report.dart';
import 'package:pos_machine/features/reports/domain/report_period.dart';
import 'package:pos_machine/features/reports/domain/sales_report_query.dart';
import 'package:pos_machine/features/reports/presentation/state/sales_report_controller.dart';

typedef _Call = ({Map<String, String> params, int page, int perPage});

const SalesReportScope _scope =
    (token: 't', tenant: 'tenant', activeStoreId: 2, endpoint: 'e');

SalesReportRow _row(int id, {int? executiveId, String? executive}) =>
    SalesReportRow(
        orderId: id,
        orderNumber: 'ORD-$id',
        salesExecutiveId: executiveId,
        salesExecutive: executive);

/// Two pages of two rows by default.
class _Server {
  final calls = <_Call>[];
  bool fail = false;
  Completer<void>? gate;
  int lastPage = 2;

  Future<SalesReportResponse> fetch(
      Map<String, String> params, int page, int perPage) async {
    calls.add((params: params, page: page, perPage: perPage));
    final wait = gate;
    if (wait != null) await wait.future;
    if (fail) throw StateError('outage');
    return SalesReportResponse(
        rows: [
          _row(page * 10 + 1, executiveId: 1060, executive: 'SALESMEDINA'),
          _row(page * 10 + 2)
        ],
        currentPage: page,
        lastPage: lastPage,
        perPage: 2,
        total: lastPage * 2,
        summary: {'orders': lastPage * 2.0, 'order_value': 99.5});
  }
}

final _now = DateTime(2026, 10, 14, 15);

SalesReportController _sales(_Server server,
        {Map<SalesReportFilter, SalesReportOptionsLoader> loaders = const {},
        Future<SalesReportScope> Function()? scope}) =>
    SalesReportController(
        fetch: server.fetch,
        readScope: scope ?? () async => _scope,
        loaders: loaders,
        clock: () => _now);

void main() {
  test('first load: this month, page one, 25 rows, no other filters', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.load();
    expect(server.calls.single.page, 1);
    expect(server.calls.single.perPage, SalesReportController.pageSize);
    expect(server.calls.single.params, {'period': 'this_month'});
    expect(report.rows.map((r) => r.orderId), [11, 12]);
    expect((report.page, report.totalPages, report.total), (1, 2, 4));
    expect(report.summary, {'orders': 4.0, 'order_value': 99.5});
    expect(report.hasActiveFilters, isFalse);
    expect(report.canExport, isTrue);
  });

  test('selections reach the API as sorted id lists', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.select(SalesReportFilter.store, {'70', '2', ' '});
    await report.select(SalesReportFilter.paymentMethod, {'3'});
    await report.select(SalesReportFilter.product, {'9', '10'});
    expect(server.calls.last.params, {
      'period': 'this_month',
      'store_ids': '2,70',
      'payment_method_ids': '3',
      'product_ids': '10,9',
    });
    // Choosing All (an empty set) removes the parameter.
    await report.select(SalesReportFilter.store, const {});
    expect(server.calls.last.params.containsKey('store_ids'), isFalse);
    // The same selection again does not reload.
    final before = server.calls.length;
    await report.select(SalesReportFilter.product, {'10', '9'});
    expect(server.calls, hasLength(before));
    expect(report.hasActiveFilters, isTrue);
  });

  test('every filter reaches its API parameter', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    for (final filter in SalesReportFilter.values) {
      await report.select(filter, {'${filter.index + 1}'});
    }
    expect(server.calls.last.params, {
      'period': 'this_month',
      'store_ids': '1',
      'sales_executive_ids': '2',
      'payment_method_ids': '3',
      'delivery_method_ids': '4',
      'category_ids': '5',
      'product_ids': '6',
      'customer_ids': '7',
    });
  });

  test('periods, custom dates and sort', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    expect(report.periods, SalesReportParams.periods);
    await report.setPeriod(ReportPeriod.last3Months);
    expect(server.calls.last.params, {'period': 'last_3_months'});
    // Not offered by this report: ignored.
    await report.setPeriod(ReportPeriod.today);
    expect(report.period, ReportPeriod.last3Months);

    // Custom starts from the range on screen.
    await report.setPeriod(ReportPeriod.custom);
    expect(server.calls.last.params,
        {'period': 'custom', 'from': '2026-07-14', 'to': '2026-10-14'});
    await report.setCustomDate(DateTime(2026, 10, 2, 9, 30), from: true);
    expect(report.customFrom, DateTime(2026, 10, 2));
    expect(server.calls.last.params['from'], '2026-10-02');
    // A cleared date blocks the request until it is picked again.
    final before = server.calls.length;
    await report.setCustomDate(null, from: false);
    expect(server.calls, hasLength(before));
    expect(report.errorKey, SalesReportController.missingDates);
    expect(report.errorKey, 'order_sales_report.missing_dates');
    expect((report.canRetry, report.canExport), (false, false));
    await report.setCustomDate(DateTime(2026, 10, 9), from: false);
    expect(server.calls.last.params,
        {'period': 'custom', 'from': '2026-10-02', 'to': '2026-10-09'});
    expect(report.errorKey, isNull);

    await report.setOldestFirst(true);
    expect(server.calls.last.params['sort_direction'], 'asc');
    // A preset sends only its code and drops the custom dates.
    await report.setPeriod(ReportPeriod.lastMonth);
    expect(server.calls.last.params,
        {'period': 'last_month', 'sort_direction': 'asc'});
    expect((report.customFrom, report.customTo), (null, null));
    // The same sort again does not reload; newest first drops the parameter.
    final sorted = server.calls.length;
    await report.setOldestFirst(true);
    expect(server.calls, hasLength(sorted));
    await report.setOldestFirst(false);
    expect(server.calls.last.params, {'period': 'last_month'});
  });

  test('From after To never reaches the API', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.setCustomDate(DateTime(2026, 10, 9), from: true);
    final before = server.calls.length;
    await report.setCustomDate(DateTime(2026, 10, 2), from: false);
    expect(server.calls, hasLength(before));
    expect(report.errorKey, 'order_sales_report.inverted_dates');
    expect(report.canRetry, isFalse);
    expect(report.canExport, isFalse);
  });

  test('reset clears every filter and reloads page one', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.select(SalesReportFilter.category, {'3'});
    await report.setPeriod(ReportPeriod.custom);
    await report.setOldestFirst(true);
    await report.goToPage(2);
    final revision = report.resetRevision;

    await report.reset();

    expect(server.calls.last.page, 1);
    expect(server.calls.last.params, {'period': 'this_month'});
    expect(report.period, SalesReportController.defaultPeriod);
    expect((report.customFrom, report.customTo), (null, null));
    expect(report.selected, isEmpty);
    expect(report.oldestFirst, isFalse);
    expect(report.hasActiveFilters, isFalse);
    expect(report.resetRevision, revision + 1);
  });

  test('paging only moves to valid pages', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.load();
    await report.goToPage(2);
    expect(report.page, 2);
    await report.goToPage(2);
    await report.goToPage(3);
    await report.goToPage(0);
    expect(server.calls.map((c) => c.page), [1, 2]);
  });

  test('a result that shrank below the page shows its new last page', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.load();
    await report.goToPage(2);
    server.lastPage = 1; // e.g. the month rolled over before Refresh
    await report.retry();
    expect(server.calls.map((c) => c.page), [1, 2, 2, 1]);
    expect((report.page, report.totalPages, report.errorKey), (1, 1, null));
    expect(report.rows.map((r) => r.orderId), [11, 12]);
    expect(report.canPage, isTrue);
  });

  test('a page that does not match the request is rejected', () async {
    final report = SalesReportController(
        readScope: () async => _scope,
        clock: () => _now,
        fetch: (params, page, perPage) async => SalesReportResponse(
            rows: [_row(1), _row(2)], currentPage: 1, lastPage: 1, perPage: 1));
    addTearDown(report.dispose);
    await report.load();
    expect(report.errorKey, SalesReportController.unavailable);
    expect(report.rows, isEmpty);
  });

  test('paging or refreshing during an export does not stop it', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.load();
    final gate = Completer<void>();
    server.gate = gate;
    final export = report.export(
        build: (rows) async => rows, permissionUnchanged: () => true);
    await Future<void>.delayed(Duration.zero);
    final paging = report.goToPage(2);
    gate.complete();
    await paging;
    await report.retry();
    expect((await export).map((r) => r.orderId), [11, 12, 21, 22]);
    expect(report.page, 2);
  });

  test('each picker is ready as soon as its own list arrives', () async {
    final slow = Completer<List<SalesReportOption>>();
    final report = _sales(_Server(), loaders: {
      SalesReportFilter.store: () async =>
          const [SalesReportOption('5', 'Main')],
      SalesReportFilter.product: () => slow.future,
    });
    addTearDown(report.dispose);
    final options = report.loadOptions();
    expect(report.optionsLoading(SalesReportFilter.store), isTrue);
    expect(report.optionsLoading(SalesReportFilter.product), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(report.optionsLoading(SalesReportFilter.store), isFalse);
    expect(report.optionMap(SalesReportFilter.store), {'5': 'Main'});
    expect(report.optionsLoading(SalesReportFilter.product), isTrue);
    slow.complete(const [SalesReportOption('9', 'Juice')]);
    await options;
    expect(report.optionsLoading(SalesReportFilter.product), isFalse);
    expect(report.optionMap(SalesReportFilter.product), {'9': 'Juice'});
  });

  test('a failed list shows at once; Retry reloads only the failed ones',
      () async {
    final slow = Completer<List<SalesReportOption>>();
    final loads = <SalesReportFilter>[];
    var storeDown = true;
    final report = _sales(_Server(), loaders: {
      SalesReportFilter.store: () async {
        loads.add(SalesReportFilter.store);
        if (storeDown) throw StateError('down');
        return const [SalesReportOption('5', 'Main')];
      },
      SalesReportFilter.product: () {
        loads.add(SalesReportFilter.product);
        return slow.future;
      },
    });
    addTearDown(report.dispose);
    final first = report.loadOptions();
    await Future<void>.delayed(Duration.zero);
    expect(report.optionsFailed, isTrue,
        reason: 'not held back by the slow product list');
    expect(report.optionsLoading(SalesReportFilter.product), isTrue);

    storeDown = false;
    await report.retryOptions();
    expect(loads, [
      SalesReportFilter.store,
      SalesReportFilter.product,
      SalesReportFilter.store
    ]);
    expect(report.optionsFailed, isFalse);
    expect(report.optionMap(SalesReportFilter.store), {'5': 'Main'});
    expect(report.optionsLoading(SalesReportFilter.product), isTrue,
        reason: 'the retry does not drop the list still loading');
    slow.complete(const [SalesReportOption('9', 'Juice')]);
    await first;
    expect(report.optionMap(SalesReportFilter.product), {'9': 'Juice'});
  });

  test('the newest options request per filter wins', () async {
    final older = Completer<List<SalesReportOption>>();
    var call = 0;
    final report = _sales(_Server(), loaders: {
      SalesReportFilter.store: () => ++call == 1
          ? older.future
          : Future.value(const [SalesReportOption('6', 'New')]),
    });
    addTearDown(report.dispose);
    final first = report.loadOptions();
    await report.loadOptions();
    expect(report.optionMap(SalesReportFilter.store), {'6': 'New'});
    older.complete(const [SalesReportOption('5', 'Old')]);
    await first;
    expect(report.optionMap(SalesReportFilter.store), {'6': 'New'});
    expect(report.optionsLoading(SalesReportFilter.store), isFalse);
  });

  test('stale response does not replace newer rows', () async {
    final gate = Completer<void>();
    var call = 0;
    final report = SalesReportController(
        readScope: () async => _scope,
        clock: () => _now,
        fetch: (params, page, perPage) async {
          final mine = ++call;
          if (mine == 1) await gate.future;
          return SalesReportResponse(
              rows: [_row(mine)], currentPage: 1, lastPage: 1, perPage: 25);
        });
    addTearDown(report.dispose);
    final slow = report.load();
    await Future<void>.delayed(Duration.zero); // the first request is out
    await report.select(SalesReportFilter.store, {'1'});
    expect(report.rows.single.orderId, 2);
    gate.complete();
    await slow;
    expect(report.rows.single.orderId, 2);
    expect(report.loading, isFalse);
  });

  test('a failed reload keeps rows, blocks export and paging; retry recovers',
      () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.load();
    await report.goToPage(2);
    server.fail = true;
    await report.select(SalesReportFilter.store, {'5'});
    expect(report.errorKey, 'order_sales_report.unavailable');
    expect(report.canRetry, isTrue);
    expect(report.rows.map((r) => r.orderId), [21, 22]);
    expect(report.canExport, isFalse);
    expect(report.canPage, isFalse);
    server.fail = false;
    await report.retry();
    expect(server.calls.last.page, 1, reason: 'retry the new filters');
    expect(server.calls.last.params['store_ids'], '5');
    expect(report.errorKey, isNull);
  });

  test('a failed page change retries that page', () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.load();
    server.fail = true;
    await report.goToPage(2);
    expect(report.page, 1);
    expect(report.errorKey, SalesReportController.unavailable);
    server.fail = false;
    await report.retry();
    expect(server.calls.last.page, 2);
    expect(report.page, 2);
  });

  test('a page from another session is rejected', () async {
    var store = 2;
    final report = _sales(_Server(),
        scope: () async => (
              token: 't',
              tenant: 'tenant',
              activeStoreId: store++,
              endpoint: 'e'
            ));
    addTearDown(report.dispose);
    await report.load();
    expect(report.errorKey, 'order_sales_report.unavailable');
    expect(report.rows, isEmpty);
  });

  test('export reads all pages, 100 rows at a time, with the loaded filters',
      () async {
    final server = _Server();
    final report = _sales(server);
    addTearDown(report.dispose);
    await report.select(SalesReportFilter.store, {'5'});
    final progress = <(int, int)>[];
    final rows = await report.export(
        build: (rows) async => rows,
        permissionUnchanged: () => true,
        progress: (p, t) => progress.add((p, t)));
    expect(rows.map((r) => r.orderId), [11, 12, 21, 22]);
    expect(progress, [(1, 2), (2, 2)]);
    final exportCalls = server.calls.skip(1);
    expect(exportCalls.map((c) => c.perPage),
        everyElement(SalesReportController.exportPageSize));
    expect(exportCalls.map((c) => c.perPage), everyElement(100));
    expect(exportCalls.map((c) => c.params['store_ids']), everyElement('5'));
  });

  test('export is unavailable until the shown rows match the filters',
      () async {
    final server = _Server()..gate = Completer();
    final report = _sales(server);
    addTearDown(report.dispose);
    expect(report.canExport, isFalse, reason: 'nothing loaded');
    final load = report.load();
    expect(report.canExport, isFalse, reason: 'still loading');
    server.gate!.complete();
    await load;
    expect(report.canExport, isTrue);
    report.selected[SalesReportFilter.store] = {'5'};
    expect(report.canExport, isFalse, reason: 'filters moved on');
    await expectLater(
        report.export(
            build: (rows) async => rows, permissionUnchanged: () => true),
        throwsStateError);
  });

  test('an empty result cannot be exported', () async {
    final report = SalesReportController(
        readScope: () async => _scope,
        clock: () => _now,
        fetch: (params, page, perPage) async => const SalesReportResponse(
            rows: [], currentPage: 1, lastPage: 1, perPage: 25));
    addTearDown(report.dispose);
    await report.load();
    expect(report.errorKey, isNull);
    expect(report.canExport, isFalse);
  });

  test('export stops when filters, permission or session change', () async {
    final server = _Server();
    var store = 2;
    final report = _sales(server,
        scope: () async => (
              token: 't',
              tenant: 'tenant',
              activeStoreId: store,
              endpoint: 'e'
            ));
    addTearDown(report.dispose);
    await report.load();
    var allowed = true;
    final export = report.export(
        build: (rows) async => rows,
        permissionUnchanged: () => allowed,
        progress: (page, _) {
          if (page == 1) allowed = false;
        });
    await expectLater(export, throwsStateError);

    await report.load();
    final gate = Completer<void>();
    server.gate = gate;
    final second = report.export(
        build: (rows) async => rows, permissionUnchanged: () => true);
    await Future<void>.delayed(Duration.zero);
    unawaited(report.select(SalesReportFilter.store, {'9'}));
    gate.complete();
    await expectLater(second, throwsStateError);

    server.gate = null;
    await report.select(SalesReportFilter.store, const {});
    expect(report.canExport, isTrue);
    final third = report.export(
        build: (rows) async => rows,
        permissionUnchanged: () => true,
        progress: (page, _) {
          if (page == 1) store = 3; // another store became active
        });
    await expectLater(third, throwsStateError);
  });

  test('export rereads when live orders move rows, up to three times',
      () async {
    var moving = 2, reads = 0;
    final report = SalesReportController(
        readScope: () async => _scope,
        clock: () => _now,
        fetch: (params, page, perPage) async {
          final export = perPage == SalesReportController.exportPageSize;
          if (export && page == 1) reads++;
          // A sale lands between the page reads of the next [moving] exports.
          final grew = export && page == 2 && moving-- > 0;
          return SalesReportResponse(
              rows: [_row(page * 10 + 1)],
              currentPage: page,
              lastPage: 2,
              perPage: 1,
              total: grew ? 3 : 2);
        });
    addTearDown(report.dispose);
    await report.load();
    final rows = await report.export(
        build: (rows) async => rows, permissionUnchanged: () => true);
    expect(rows.map((r) => r.orderId), [11, 21]);
    expect(reads, 3);

    moving = 99;
    reads = 0;
    await expectLater(
        report.export(
            build: (rows) async => rows, permissionUnchanged: () => true),
        throwsA(isA<SalesReportSnapshotChanged>()));
    expect(reads, SalesReportController.exportAttempts);
  });

  test('filters load independently; executives seen in rows are added',
      () async {
    final report = _sales(_Server(), loaders: {
      SalesReportFilter.store: () async =>
          const [SalesReportOption('5', 'Main'), SalesReportOption('', 'x')],
      SalesReportFilter.salesExecutive: () async =>
          const [SalesReportOption('516', 'salesexecutiv2')],
      SalesReportFilter.customer: () async => throw StateError('down'),
    });
    addTearDown(report.dispose);
    await report.initialize();
    expect(report.optionMap(SalesReportFilter.store), {'5': 'Main'});
    expect(report.optionMap(SalesReportFilter.customer), isEmpty);
    expect(report.optionsFailed, isTrue);
    expect(report.optionsLoading(SalesReportFilter.customer), isFalse,
        reason: 'a failed list is not left spinning');
    expect(report.rows, isNotEmpty, reason: 'the report still loads');
    expect(report.optionMap(SalesReportFilter.salesExecutive),
        {'516': 'salesexecutiv2', '1060': 'SALESMEDINA'});
    // Only the executive picker takes names from the rows.
    expect(report.optionMap(SalesReportFilter.product), isEmpty);
  });

  test('locked filters: selected from the start, fixed, kept by Reset',
      () async {
    final server = _Server();
    final report = SalesReportController(
        fetch: server.fetch,
        readScope: () async => _scope,
        clock: () => _now,
        locked: const {
          SalesReportFilter.salesExecutive: SalesReportOption('4', 'Asha'),
          SalesReportFilter.store: SalesReportOption('5', ''),
        });
    addTearDown(report.dispose);
    const own = {
      'period': 'this_month',
      'sales_executive_ids': '4',
      'store_ids': '5'
    };
    await report.load();
    expect(server.calls.last.params, own);
    // A known name shows at once; the locks are not "active filters".
    expect(report.optionMap(SalesReportFilter.salesExecutive),
        containsPair('4', 'Asha'));
    expect(report.hasActiveFilters, isFalse);
    expect(report.isLocked(SalesReportFilter.store), isTrue);
    expect(report.isLocked(SalesReportFilter.customer), isFalse);

    final before = server.calls.length;
    await report.select(SalesReportFilter.salesExecutive, {'9'});
    await report.select(SalesReportFilter.store, const {});
    expect(server.calls, hasLength(before), reason: 'locked filters stay');

    await report.select(SalesReportFilter.customer, {'7'});
    expect(report.hasActiveFilters, isTrue);
    await report.reset();
    expect(server.calls.last.params, own);
    expect(report.hasActiveFilters, isFalse);
  });

  test('applied filters name what was picked', () async {
    final report = _sales(_Server(), loaders: {
      SalesReportFilter.store: () async => const [
            SalesReportOption('5', 'Main'),
            SalesReportOption('6', 'Branch')
          ],
    });
    addTearDown(report.dispose);
    await report.initialize();
    expect(report.appliedFilters, [
      (
        'order_sales_report.date_range',
        'report_period.thisMonth',
        translate: true
      )
    ]);
    await report.select(SalesReportFilter.store, {'6', '5'});
    await report.select(SalesReportFilter.product, {'42'});
    await report.setCustomDate(DateTime(2026, 10, 1), from: true);
    expect(report.appliedFilters, [
      (
        'order_sales_report.date_range',
        'report_period.custom',
        translate: true
      ),
      ('order_sales_report.from_date', '2026-10-01', translate: false),
      // Names are data, never translated.
      ('order_sales_report.filter_stores', 'Main, Branch', translate: false),
      // An id without a loaded name is kept as the id.
      ('order_sales_report.filter_products', '42', translate: false),
    ]);
  });

  test('late responses after dispose are ignored', () async {
    final server = _Server()..gate = Completer();
    final report = _sales(server);
    var notified = 0;
    report.addListener(() => notified++);
    final load = report.load();
    await Future<void>.delayed(Duration.zero);
    final before = notified;
    report.dispose();
    server.gate!.complete();
    await load;
    expect(notified, before);
    await report.load();
    await report.reset();
    expect(server.calls, hasLength(1));
  });
}
