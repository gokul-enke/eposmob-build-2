import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/discount_sale_report_snapshot.dart';
import 'package:pos_machine/features/reports/domain/discount_sale_report_query.dart';
import 'package:pos_machine/features/reports/domain/models/discount_sale_report.dart';
import 'package:pos_machine/features/reports/domain/report_period.dart';
import 'package:pos_machine/features/reports/presentation/state/discount_sale_report_controller.dart';

typedef _Call = ({Map<String, String> params, int page, int perPage});

const DiscountSaleReportScope _scope =
    (token: 't', tenant: 'tenant', activeStoreId: 2, endpoint: 'e');

DiscountSaleReportRow _row(int id, {int? executiveId, String? executive}) =>
    DiscountSaleReportRow(
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

  Future<DiscountSaleReportResponse> fetch(
      Map<String, String> params, int page, int perPage) async {
    calls.add((params: params, page: page, perPage: perPage));
    final wait = gate;
    if (wait != null) await wait.future;
    if (fail) throw StateError('outage');
    return DiscountSaleReportResponse(
        rows: [
          _row(page * 10 + 1, executiveId: 1060, executive: 'SALESMEDINA'),
          _row(page * 10 + 2)
        ],
        currentPage: page,
        lastPage: lastPage,
        perPage: 2,
        total: lastPage * 2,
        summary: {'orders': lastPage * 2.0, 'total_discount': 9.5});
  }
}

final _now = DateTime(2026, 10, 14, 15);

DiscountSaleReportController _report(_Server server,
        {Map<DiscountSaleReportFilter, DiscountSaleReportOptionsLoader>
            loaders = const {},
        Future<DiscountSaleReportScope> Function()? scope}) =>
    DiscountSaleReportController(
        fetch: server.fetch,
        readScope: scope ?? () async => _scope,
        loaders: loaders,
        clock: () => _now);

Future<void> _typingSettles() =>
    Future<void>.delayed(const Duration(milliseconds: 350));

void main() {
  test('first load: this month, page one, 25 rows, no other filters', () async {
    final server = _Server();
    final report = _report(server);
    await report.load();
    expect(server.calls.single.page, 1);
    expect(server.calls.single.perPage, DiscountSaleReportController.pageSize);
    expect(server.calls.single.params, {'sales_date_range': 'month'});
    expect(report.periods, DiscountSaleReportParams.periods);
    expect(report.rows.map((r) => r.orderId), [11, 12]);
    expect((report.page, report.totalPages, report.total), (1, 2, 4));
    expect(report.summary, {'orders': 4.0, 'total_discount': 9.5});
    expect(report.hasActiveFilters, isFalse);
    expect(report.canExport, isTrue);
    report.dispose();
  });

  test('filters use the keys the API understands', () async {
    final server = _Server();
    final report = _report(server);
    await report.select(DiscountSaleReportFilter.salesExecutive, '1060');
    await report.select(DiscountSaleReportFilter.store, '70');
    await report.select(DiscountSaleReportFilter.customer, '2527');
    await report.setDiscountType(DiscountType.overallOrder);
    await report.setPeriod(ReportPeriod.thisWeek);
    report.orderNumber.text = ' 4749 ';
    await _typingSettles();
    expect(server.calls.last.params, {
      'sales_date_range': 'week',
      'executive_id': '1060',
      'store_id': '70',
      'customer_id': '2527',
      'discount_type': 'order',
      'order_number': '4749',
    });
    await report.setDiscountType(DiscountType.cartItems);
    expect(server.calls.last.params['discount_type'], 'items');
    await report.setDiscountType(DiscountType.all);
    expect(server.calls.last.params.containsKey('discount_type'), isFalse);
    await report.select(DiscountSaleReportFilter.store, null);
    expect(server.calls.last.params.containsKey('store_id'), isFalse);
    report.dispose();
  });

  test('single-choice pickers: trimmed ids, blanks mean All, repeats ignored',
      () async {
    final server = _Server();
    final report = _report(server);
    await report.select(DiscountSaleReportFilter.store, ' 70 ');
    expect(server.calls.last.params['store_id'], '70');
    expect(report.hasActiveFilters, isTrue);
    final before = server.calls.length;
    await report.select(DiscountSaleReportFilter.store, '70');
    await report.setDiscountType(DiscountType.all);
    await report.setDiscountType(null);
    expect(server.calls, hasLength(before), reason: 'nothing changed');
    await report.select(DiscountSaleReportFilter.store, '  ');
    expect(server.calls, hasLength(before + 1));
    expect(report.selected, isEmpty);
    expect(server.calls.last.params, {'sales_date_range': 'month'});
    report.dispose();
  });

  test('periods and custom dates', () async {
    final server = _Server();
    final report = _report(server);
    // Custom starts from the month on screen.
    await report.setPeriod(ReportPeriod.custom);
    expect(server.calls.last.params, {
      'sales_date_range': 'custom',
      'from': '2026-10-01',
      'to': '2026-10-31'
    });
    await report.setCustomDate(DateTime(2026, 10, 2, 9, 30), from: true);
    expect(report.customFrom, DateTime(2026, 10, 2));
    expect(server.calls.last.params['from'], '2026-10-02');

    // A cleared date blocks the request until it is picked again.
    final before = server.calls.length;
    await report.setCustomDate(null, from: false);
    expect(server.calls, hasLength(before));
    expect(report.errorKey, DiscountSaleReportController.missingDates);
    expect((report.canRetry, report.canExport, report.canPage),
        (false, false, false));
    await report.retry();
    expect(server.calls, hasLength(before), reason: 'retry cannot fix dates');
    await report.setCustomDate(DateTime(2026, 10, 9), from: false);
    expect(server.calls.last.params, {
      'sales_date_range': 'custom',
      'from': '2026-10-02',
      'to': '2026-10-09'
    });
    expect(report.errorKey, isNull);

    // A preset sends only its code and drops the custom dates.
    await report.setPeriod(ReportPeriod.today);
    expect(server.calls.last.params, {'sales_date_range': 'today'});
    expect((report.customFrom, report.customTo), (null, null));
    // Not offered by this report: ignored.
    await report.setPeriod(ReportPeriod.last3Months);
    await report.setPeriod(ReportPeriod.lastMonth);
    expect(report.period, ReportPeriod.today);
    // Custom from Today starts on today.
    await report.setPeriod(ReportPeriod.custom);
    expect(server.calls.last.params, {
      'sales_date_range': 'custom',
      'from': '2026-10-14',
      'to': '2026-10-14'
    });
    report.dispose();
  });

  test('picking a date switches to Custom', () async {
    final server = _Server();
    final report = _report(server);
    await report.setCustomDate(DateTime(2026, 10, 3), from: true);
    expect(report.period, ReportPeriod.custom);
    expect(report.errorKey, DiscountSaleReportController.missingDates);
    expect(server.calls, isEmpty);
    report.dispose();
  });

  test('From after To never reaches the API', () async {
    final server = _Server();
    final report = _report(server);
    await report.setCustomDate(DateTime(2026, 10, 9), from: true);
    final before = server.calls.length;
    await report.setCustomDate(DateTime(2026, 10, 2), from: false);
    expect(server.calls, hasLength(before));
    expect(report.errorKey, 'discount_sale_report.inverted_dates');
    expect((report.canRetry, report.canExport), (false, false));
    report.dispose();
  });

  test('typing the order number waits for a pause', () async {
    final server = _Server();
    final report = _report(server);
    await report.load();
    report.orderNumber.text = '4';
    report.orderNumber.text = '47';
    report.orderNumber.text = '4749';
    expect(server.calls, hasLength(1));
    // The shown result is stale at once: no export or paging meanwhile.
    expect((report.canExport, report.canPage), (false, false));
    expect(report.hasActiveFilters, isTrue);
    await _typingSettles();
    expect(server.calls, hasLength(2));
    expect(server.calls.last.params['order_number'], '4749');
    expect(report.canExport, isTrue);
    report.dispose();
  });

  test('spaces around the order number change nothing', () async {
    final server = _Server();
    final report = _report(server);
    addTearDown(report.dispose);
    report.orderNumber.text = 'ORD';
    await _typingSettles();
    await report.goToPage(2);
    final before = server.calls.length;
    report.orderNumber.text = ' ORD ';
    expect((report.canPage, report.canExport), (true, true),
        reason: 'the shown page still matches the request');
    await _typingSettles();
    expect(server.calls, hasLength(before));
    expect(report.page, 2);
  });

  test('typing drops a request already on its way', () async {
    final server = _Server()..gate = Completer();
    final report = _report(server);
    final first = report.load();
    await Future<void>.delayed(Duration.zero);
    expect(report.loading, isTrue);
    report.orderNumber.text = 'ORD';
    expect(report.loading, isFalse);
    server.gate!.complete();
    await first;
    expect(report.rows, isEmpty, reason: 'the old filters came back late');
    await _typingSettles();
    expect(server.calls.last.params['order_number'], 'ORD');
    expect(report.rows.map((r) => r.orderId), [11, 12]);
    report.dispose();
  });

  test('reset clears every filter and reloads page one, once', () async {
    final server = _Server();
    final report = _report(server);
    await report.select(DiscountSaleReportFilter.salesExecutive, '516');
    await report.setDiscountType(DiscountType.cartItems);
    await report.setPeriod(ReportPeriod.custom);
    report.orderNumber.text = 'ORD';
    await _typingSettles();
    await report.goToPage(2);
    expect(server.calls.last.page, 2);
    final revision = report.resetRevision, before = server.calls.length;

    await report.reset();
    await _typingSettles();

    expect(server.calls, hasLength(before + 1),
        reason: 'clearing the number does not schedule a second request');
    expect(server.calls.last.page, 1);
    expect(server.calls.last.params, {'sales_date_range': 'month'});
    expect(report.selected, isEmpty);
    expect(report.discountType, DiscountType.all);
    expect(report.orderNumber.text, isEmpty);
    expect(report.period, ReportPeriod.thisMonth);
    expect((report.customFrom, report.customTo), (null, null));
    expect(report.hasActiveFilters, isFalse);
    expect(report.resetRevision, revision + 1);
    report.dispose();
  });

  test('paging only moves to valid pages', () async {
    final server = _Server();
    final report = _report(server);
    await report.load();
    await report.goToPage(2);
    expect(report.page, 2);
    await report.goToPage(2);
    await report.goToPage(3);
    await report.goToPage(0);
    expect(server.calls.map((c) => c.page), [1, 2]);
    report.dispose();
  });

  test('a result that shrank below the page shows its new last page', () async {
    final server = _Server();
    final report = _report(server);
    await report.load();
    await report.goToPage(2);
    server.lastPage = 1; // e.g. the month rolled over before Refresh
    await report.retry();
    expect(server.calls.map((c) => c.page), [1, 2, 2, 1]);
    expect((report.page, report.totalPages, report.errorKey), (1, 1, null));
    expect(report.rows.map((r) => r.orderId), [11, 12]);
    expect(report.canPage, isTrue);
    report.dispose();
  });

  test('stale response does not replace newer rows', () async {
    final gate = Completer<void>();
    var call = 0;
    final report = DiscountSaleReportController(
        readScope: () async => _scope,
        clock: () => _now,
        fetch: (params, page, perPage) async {
          final mine = ++call;
          if (mine == 1) await gate.future;
          return DiscountSaleReportResponse(
              rows: [_row(mine)], currentPage: 1, lastPage: 1, perPage: 25);
        });
    final slow = report.load();
    await Future<void>.delayed(Duration.zero); // the first request is out
    await report.select(DiscountSaleReportFilter.store, '1');
    expect(report.rows.single.orderId, 2);
    gate.complete();
    await slow;
    expect(report.rows.single.orderId, 2);
    expect(report.loading, isFalse);
    report.dispose();
  });

  test('a failed reload keeps rows, blocks export and paging; retry recovers',
      () async {
    final server = _Server();
    final report = _report(server);
    await report.load();
    await report.goToPage(2);
    server.fail = true;
    await report.select(DiscountSaleReportFilter.store, '5');
    expect(report.errorKey, 'discount_sale_report.unavailable');
    expect(report.canRetry, isTrue);
    expect(report.rows.map((r) => r.orderId), [21, 22]);
    expect(report.canExport, isFalse);
    expect(report.canPage, isFalse);
    server.fail = false;
    await report.retry();
    expect(server.calls.last.page, 1, reason: 'retry the new filters');
    expect(server.calls.last.params['store_id'], '5');
    expect(report.errorKey, isNull);
    expect(report.canExport, isTrue);
    report.dispose();
  });

  test('Refresh after a failed page retries that page', () async {
    final server = _Server();
    final report = _report(server);
    await report.load();
    server.fail = true;
    await report.goToPage(2);
    expect(report.errorKey, DiscountSaleReportController.unavailable);
    expect(report.page, 1, reason: 'the shown rows are still page one');
    server.fail = false;
    await report.retry();
    expect(server.calls.last.page, 2);
    expect(report.page, 2);
    report.dispose();
  });

  test('a page from another session is rejected', () async {
    var store = 2;
    final report = _report(_Server(),
        scope: () async => (
              token: 't',
              tenant: 'tenant',
              activeStoreId: store++,
              endpoint: 'e'
            ));
    await report.load();
    expect(report.errorKey, 'discount_sale_report.unavailable');
    expect(report.rows, isEmpty);
    report.dispose();
  });

  test('an invalid page is an error', () async {
    final report = DiscountSaleReportController(
        readScope: () async => _scope,
        fetch: (params, page, perPage) async => DiscountSaleReportResponse(
            rows: [_row(1), _row(2)], currentPage: 1, lastPage: 1, perPage: 1));
    await report.load();
    expect(report.errorKey, DiscountSaleReportController.unavailable);
    expect(report.rows, isEmpty);
    report.dispose();
  });

  test('export reads all pages, 100 rows at a time, with the loaded filters',
      () async {
    final server = _Server();
    final report = _report(server);
    await report.select(DiscountSaleReportFilter.store, '5');
    final progress = <(int, int)>[];
    final rows = await report.export(
        build: (rows) async => rows,
        permissionUnchanged: () => true,
        progress: (p, t) => progress.add((p, t)));
    expect(rows.map((r) => r.orderId), [11, 12, 21, 22]);
    expect(progress, [(1, 2), (2, 2)]);
    final exportCalls = server.calls.skip(1);
    expect(exportCalls.map((c) => c.perPage),
        everyElement(DiscountSaleReportController.exportPageSize));
    expect(DiscountSaleReportController.exportPageSize, 100);
    expect(exportCalls.map((c) => c.params['store_id']), everyElement('5'));
    expect(report.rows.map((r) => r.orderId), [11, 12],
        reason: 'the table is untouched');
    report.dispose();
  });

  test('export is unavailable before a load, when empty or while typing',
      () async {
    final empty = DiscountSaleReportController(
        readScope: () async => _scope,
        fetch: (params, page, perPage) async =>
            const DiscountSaleReportResponse(
                rows: [], currentPage: 1, lastPage: 1, perPage: 25));
    expect(empty.canExport, isFalse);
    await empty.load();
    expect(empty.canExport, isFalse);
    await expectLater(
        empty.export(
            build: (rows) async => rows, permissionUnchanged: () => true),
        throwsStateError);
    empty.dispose();

    final report = _report(_Server());
    await report.load();
    report.orderNumber.text = '1';
    expect(report.canExport, isFalse);
    report.dispose();
  });

  test('paging or refreshing during an export does not stop it', () async {
    final server = _Server();
    final report = _report(server);
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
    report.dispose();
  });

  test('export rereads when live orders move rows, up to three times',
      () async {
    var moving = 2, reads = 0;
    final report = DiscountSaleReportController(
        readScope: () async => _scope,
        clock: () => _now,
        fetch: (params, page, perPage) async {
          final export = perPage == DiscountSaleReportController.exportPageSize;
          if (export && page == 1) reads++;
          // A sale lands between the page reads of the next [moving] exports.
          final grew = export && page == 2 && moving-- > 0;
          return DiscountSaleReportResponse(
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
        throwsA(isA<DiscountSaleReportSnapshotChanged>()));
    expect(reads, DiscountSaleReportController.exportAttempts);
  });

  test('export stops when filters or permission change', () async {
    final server = _Server();
    final report = _report(server);
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
    unawaited(report.select(DiscountSaleReportFilter.store, '9'));
    gate.complete();
    await expectLater(second, throwsStateError);
    report.dispose();
  });

  test('export stops when the session changes', () async {
    var scope = _scope;
    final report = _report(_Server(), scope: () async => scope);
    await report.load();
    final export = report.export(
        build: (rows) async => rows,
        permissionUnchanged: () => true,
        progress: (page, _) {
          if (page == 1) {
            scope =
                (token: 't', tenant: 'other', activeStoreId: 2, endpoint: 'e');
          }
        });
    await expectLater(export, throwsStateError);
    report.dispose();
  });

  test('export stops when the page is disposed', () async {
    final server = _Server();
    final report = _report(server);
    await report.load();
    final gate = Completer<void>();
    server.gate = gate;
    final export = report.export(
        build: (rows) async => rows, permissionUnchanged: () => true);
    await Future<void>.delayed(Duration.zero);
    report.dispose();
    gate.complete();
    await expectLater(export, throwsStateError);
  });

  group('picker options', () {
    test('each picker is ready as soon as its own list arrives', () async {
      final slow = Completer<List<DiscountSaleReportOption>>();
      final report = _report(_Server(), loaders: {
        DiscountSaleReportFilter.store: () async =>
            const [DiscountSaleReportOption('5', 'Main')],
        DiscountSaleReportFilter.customer: () => slow.future,
      });
      final options = report.loadOptions();
      expect(report.optionsLoading(DiscountSaleReportFilter.store), isTrue);
      expect(report.optionsLoading(DiscountSaleReportFilter.customer), isTrue);
      expect(report.optionsLoading(DiscountSaleReportFilter.salesExecutive),
          isFalse,
          reason: 'no loader');
      await Future<void>.delayed(Duration.zero);
      expect(report.optionsLoading(DiscountSaleReportFilter.store), isFalse);
      expect(report.optionMap(DiscountSaleReportFilter.store), {'5': 'Main'});
      expect(report.optionsLoading(DiscountSaleReportFilter.customer), isTrue);
      slow.complete(const [DiscountSaleReportOption('9', 'Ayswariya')]);
      await options;
      expect(report.optionsLoading(DiscountSaleReportFilter.customer), isFalse);
      expect(report.optionMap(DiscountSaleReportFilter.customer),
          {'9': 'Ayswariya'});
      report.dispose();
    });

    test('a failed list shows at once; Retry reloads only the failed ones',
        () async {
      final slow = Completer<List<DiscountSaleReportOption>>();
      final loads = <DiscountSaleReportFilter>[];
      var storeDown = true;
      final report = _report(_Server(), loaders: {
        DiscountSaleReportFilter.store: () async {
          loads.add(DiscountSaleReportFilter.store);
          if (storeDown) throw StateError('down');
          return const [DiscountSaleReportOption('5', 'Main')];
        },
        DiscountSaleReportFilter.customer: () {
          loads.add(DiscountSaleReportFilter.customer);
          return slow.future;
        },
      });
      final first = report.loadOptions();
      await Future<void>.delayed(Duration.zero);
      expect(report.optionsFailed, isTrue,
          reason: 'not held back by the slow customer list');
      expect(report.optionsLoading(DiscountSaleReportFilter.store), isFalse);
      expect(report.optionsLoading(DiscountSaleReportFilter.customer), isTrue);

      storeDown = false;
      await report.retryOptions();
      expect(loads, [
        DiscountSaleReportFilter.store,
        DiscountSaleReportFilter.customer,
        DiscountSaleReportFilter.store
      ]);
      expect(report.optionsFailed, isFalse);
      expect(report.optionMap(DiscountSaleReportFilter.store), {'5': 'Main'});
      expect(report.optionsLoading(DiscountSaleReportFilter.customer), isTrue,
          reason: 'the retry does not drop the list still loading');
      slow.complete(const [DiscountSaleReportOption('9', 'Ayswariya')]);
      await first;
      expect(report.optionMap(DiscountSaleReportFilter.customer),
          {'9': 'Ayswariya'});
      report.dispose();
    });

    test('the newest request per picker wins', () async {
      final old = Completer<List<DiscountSaleReportOption>>();
      var call = 0;
      final report = _report(_Server(), loaders: {
        DiscountSaleReportFilter.store: () => ++call == 1
            ? old.future
            : Future.value(const [DiscountSaleReportOption('6', 'New')]),
      });
      final first = report.loadOptions();
      await report.loadOptions();
      expect(report.optionMap(DiscountSaleReportFilter.store), {'6': 'New'});
      old.complete(const [DiscountSaleReportOption('5', 'Old')]);
      await first;
      expect(report.optionMap(DiscountSaleReportFilter.store), {'6': 'New'});
      expect(report.optionsLoading(DiscountSaleReportFilter.store), isFalse);
      report.dispose();
    });

    test('lists load independently; executives seen in rows are added',
        () async {
      final report = _report(_Server(), loaders: {
        DiscountSaleReportFilter.store: () async => const [
              DiscountSaleReportOption('5', 'Main'),
              DiscountSaleReportOption('', 'x')
            ],
        DiscountSaleReportFilter.salesExecutive: () async =>
            const [DiscountSaleReportOption('516', 'salesexecutiv2')],
        DiscountSaleReportFilter.customer: () async => throw StateError('down'),
      });
      await report.initialize();
      expect(report.optionMap(DiscountSaleReportFilter.store), {'5': 'Main'});
      expect(report.optionMap(DiscountSaleReportFilter.customer), isEmpty);
      expect(report.optionsFailed, isTrue);
      expect(report.optionsLoading(DiscountSaleReportFilter.customer), isFalse,
          reason: 'a failed list is not left spinning');
      expect(report.rows, isNotEmpty, reason: 'the report still loads');
      expect(report.optionMap(DiscountSaleReportFilter.salesExecutive),
          {'516': 'salesexecutiv2', '1060': 'SALESMEDINA'});
      // Only the Executive picker learns from rows.
      expect(report.optionMap(DiscountSaleReportFilter.store), {'5': 'Main'});
      report.dispose();
    });

    test('a listed executive keeps the directory name', () async {
      final report = _report(_Server(), loaders: {
        DiscountSaleReportFilter.salesExecutive: () async =>
            const [DiscountSaleReportOption('1060', 'Medina Sales')],
      });
      await report.initialize();
      expect(report.optionMap(DiscountSaleReportFilter.salesExecutive),
          {'1060': 'Medina Sales'});
      report.dispose();
    });
  });

  test('locked filters: selected from the start, fixed, kept by Reset',
      () async {
    final server = _Server();
    final report = DiscountSaleReportController(
        fetch: server.fetch,
        readScope: () async => _scope,
        clock: () => _now,
        locked: const {
          DiscountSaleReportFilter.salesExecutive:
              DiscountSaleReportOption('4', 'Asha'),
          DiscountSaleReportFilter.store: DiscountSaleReportOption('5', ''),
        });
    addTearDown(report.dispose);
    const own = {
      'sales_date_range': 'month',
      'executive_id': '4',
      'store_id': '5'
    };
    await report.load();
    expect(server.calls.last.params, own);
    expect(report.optionMap(DiscountSaleReportFilter.salesExecutive),
        containsPair('4', 'Asha'));
    expect(report.hasActiveFilters, isFalse);

    final before = server.calls.length;
    await report.select(DiscountSaleReportFilter.salesExecutive, '9');
    await report.select(DiscountSaleReportFilter.store, null);
    expect(server.calls, hasLength(before), reason: 'locked filters stay');

    await report.select(DiscountSaleReportFilter.customer, '7');
    expect(report.hasActiveFilters, isTrue);
    await report.reset();
    expect(server.calls.last.params, own);
    expect(report.hasActiveFilters, isFalse);
  });

  test('applied filters name what was picked', () async {
    final report = _report(_Server(), loaders: {
      DiscountSaleReportFilter.store: () async => const [
            DiscountSaleReportOption('5', 'Main'),
            DiscountSaleReportOption('6', 'Branch')
          ],
    });
    await report.initialize();
    expect(report.appliedFilters, [
      (
        'discount_sale_report.date_range',
        'report_period.thisMonth',
        translate: true
      )
    ]);
    await report.select(DiscountSaleReportFilter.customer, '77');
    await report.select(DiscountSaleReportFilter.store, '6');
    await report.select(DiscountSaleReportFilter.salesExecutive, '1060');
    await report.setDiscountType(DiscountType.cartItems);
    report.orderNumber.text = ' 4749 ';
    await _typingSettles();
    await report.setCustomDate(DateTime(2026, 10, 1), from: true);
    expect(report.appliedFilters, [
      (
        'discount_sale_report.date_range',
        'report_period.custom',
        translate: true
      ),
      ('discount_sale_report.from_date', '2026-10-01', translate: false),
      // Names and the typed number are data, never translated.
      ('discount_sale_report.filter_store', 'Branch', translate: false),
      (
        'discount_sale_report.filter_executive',
        'SALESMEDINA',
        translate: false
      ),
      // Not in the loaded list: the id is kept.
      ('discount_sale_report.filter_customer', '77', translate: false),
      (
        'discount_sale_report.filter_discount_type',
        'discount_sale_report.type_cart_items',
        translate: true
      ),
      ('discount_sale_report.filter_order_number', '4749', translate: false),
    ]);
    report.dispose();
  });

  test('late responses after dispose are ignored', () async {
    final server = _Server()..gate = Completer();
    final report = _report(server);
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
    await report.loadOptions();
    await report.reset();
  });
}
