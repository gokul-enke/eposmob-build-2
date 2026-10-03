import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/presentation/state/customer_transactions_report_controller.dart';
import 'package:pos_machine/features/reports/presentation/state/report_load_error.dart';

import '../../support/report_fixtures.dart';

typedef _Call = ({CustomerReportQuery query, int page});

void main() {
  late List<_Call> calls;
  late Future<dynamic> Function(int page) handler;
  late CustomerTransactionsReportController report;

  setUp(() {
    calls = [];
    handler = (p) async => customerReportResponse(p, [customerGroup(p)]);
    report = CustomerTransactionsReportController(fetch: (query, page) {
      calls.add((query: query, page: page));
      return handler(page);
    });
  });
  tearDown(() => report.dispose());

  test('loads a page and allows the export', () async {
    handler = (p) async =>
        customerReportResponse(p, [customerGroup(p, 'Page $p')], last: 2);
    await report.load();
    expect(report.rows.single.name, 'Page 1');
    expect(report.pages, 2);
    expect(report.canExport, isTrue);

    await report.load(2);
    expect(calls.last.page, 2);
    expect(report.page, 2);
  });

  test('a failed reload keeps the rows and blocks the export', () async {
    await report.load();
    handler = (_) async => throw StateError('failure');
    await report.load();
    expect(report.rows, hasLength(1));
    expect(report.error, ReportLoadError.failed);
    expect(report.canExport, isFalse);
  });

  test('retry reloads the page that failed', () async {
    handler =
        (p) async => customerReportResponse(p, [customerGroup(p)], last: 2);
    await report.load();
    handler = (_) async => throw StateError('network');
    await report.load(2);
    expect(report.page, 1);

    handler =
        (p) async => customerReportResponse(p, [customerGroup(p)], last: 2);
    await report.retry();
    expect(calls.last.page, 2);
    expect(report.page, 2);
    expect(report.error, isNull);
  });

  test('From after To issues no request', () async {
    await report.load();
    report.setFrom(DateTime(2026, 10, 2));
    await pumpEventQueue();
    final before = calls.length;
    report.setTo(DateTime(2026, 10, 1));
    await pumpEventQueue();
    expect(calls.length, before);
    expect(report.error, ReportLoadError.invertedRange);
    expect(report.canExport, isFalse);
  });

  test('reset clears the customer and dates and loads page 1', () async {
    report = CustomerTransactionsReportController(
        customerId: '42',
        fetch: (query, page) {
          calls.add((query: query, page: page));
          return handler(page);
        });
    report.setFrom(DateTime(2026, 10, 1));
    await pumpEventQueue();
    expect(calls.last.query.customerId, '42');
    expect(calls.last.query.range.apiFrom, '2026-10-01 00:00:00');
    expect(report.hasActiveFilters, isTrue);

    await report.reset();
    expect(calls.last.query, const CustomerReportQuery());
    expect(calls.last.page, 1);
    expect(report.hasActiveFilters, isFalse);
  });

  test('a late, stale response cannot replace newer filters', () async {
    final pending = Completer<dynamic>();
    handler = (_) => pending.future;
    final old = report.load();
    handler =
        (_) async => customerReportResponse(1, [customerGroup(2, 'Newest')]);
    await report.load();
    pending.complete(customerReportResponse(1, [customerGroup(1, 'Stale')]));
    await old;
    expect(report.rows.single.name, 'Newest');
  });

  test('the export reads every page with the loaded filters', () async {
    handler = (p) async =>
        customerReportResponse(p, [customerGroup(p)], last: 2, total: 2);
    report.setCustomer('42');
    await pumpEventQueue();
    final rows = await report.exportRows();
    expect(rows, hasLength(2));
    expect(calls.map((c) => c.page), [1, 1, 2]);
    expect(calls.every((c) => c.query.customerId == '42'), isTrue);
  });

  test('the export refuses rows that do not match the filters', () async {
    expect(() => report.exportRows(), throwsStateError);
  });
}
