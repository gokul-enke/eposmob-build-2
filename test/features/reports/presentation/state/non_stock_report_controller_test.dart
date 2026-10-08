import 'package:pos_machine/features/reports/domain/models/non_stock_report_pagination.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/data/non_stock_report_snapshot.dart';
import 'package:pos_machine/features/reports/domain/models/non_stock_report.dart';
import 'package:pos_machine/features/reports/presentation/state/non_stock_report_controller.dart';
import '../../support/non_stock_fixtures.dart';

void main() {
  test('out-of-order responses and failures cannot replace newer filters',
      () async {
    final a = Completer<GetNonStockReportResponse>(),
        b = Completer<GetNonStockReportResponse>();
    final report = NonStockReportController(
        readScope: () async => nonStockScope,
        fetch: (q, p) => q.product == 'B' ? b.future : a.future);
    addTearDown(report.dispose);
    final first = report.load();
    await Future<void>.delayed(Duration.zero);
    final second = report.setProduct('B');
    await Future<void>.delayed(Duration.zero);
    b.complete(nonStockPage(1, rows: [nonStockRow(2)]));
    await second;
    a.completeError(StateError('late'));
    await first;
    expect(report.report!.data.single.id, 2);
    expect(report.errorKey, isNull);
    expect(report.canExport, isTrue);
  });
  test('failed filter change retains displayed rows but retry starts at page 1',
      () async {
    final calls = <NonStockCall>[];
    var fail = false;
    final report = NonStockReportController(
        readScope: () async => nonStockScope,
        fetch: (q, p) async {
          calls.add((query: q, page: p));
          if (fail) {
            throw StateError('outage');
          }
          return nonStockPage(p, last: 3);
        });
    addTearDown(report.dispose);
    await report.load();
    await report.goToPage(3);
    fail = true;
    await report.setStore('Other');
    expect(report.page, 3);
    expect(report.canExport, isFalse);
    await report.goToPage(2);
    expect(calls.last.page, 1);
    fail = false;
    await report.retry();
    expect(calls.last.page, 1);
    expect(calls.last.query.store, 'Other');
    expect(report.page, 1);
  });
  testWidgets(
      'barcode edits invalidate immediately, debounce, submit and reset cancel timers',
      (tester) async {
    final calls = <NonStockCall>[];
    final report = NonStockReportController(
        readScope: () async => nonStockScope,
        fetch: (q, p) async {
          calls.add((query: q, page: p));
          return nonStockPage(p);
        });
    addTearDown(report.dispose);
    await report.load();
    report.barcode.text = '001';
    expect(report.canExport, isFalse);
    await tester.pump(const Duration(milliseconds: 299));
    expect(calls.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(calls.last.query.barcode, '001');
    report.barcode.text = '002';
    await report.submit();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls.length, 3);
    report.barcode.text = '003';
    await report.reset();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls.length, 4);
    expect(calls.last.query.isEmpty, isTrue);
    report.barcode.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls.length, 4);
  });
  test(
      'export uses captured filters/all pages and preserves visible pagination',
      () async {
    final calls = <NonStockCall>[];
    final report = NonStockReportController(
        readScope: () async => nonStockScope,
        fetch: (q, p) async {
          calls.add((query: q, page: p));
          return nonStockPage(p, last: 2, total: 2);
        });
    addTearDown(report.dispose);
    await report.setCategory('Breakfast');
    await report.goToPage(2);
    final displayed = report.report;
    final count = await report.export(
        build: (rows) async => rows.length, permissionUnchanged: () => true);
    expect(count, 2);
    expect(report.report, same(displayed));
    expect(report.page, 2);
    expect(calls.map((c) => c.query.category), everyElement('Breakfast'));
  });
  for (final cause in ['input', 'session', 'permission', 'dispose']) {
    test('export stops before build when $cause changes during fetch',
        () async {
      var scope = nonStockScope,
          allowed = true,
          exporting = false,
          built = false;
      final delayed = Completer<GetNonStockReportResponse>();
      final report = NonStockReportController(
          readScope: () async => scope,
          fetch: (q, p) =>
              exporting ? delayed.future : Future.value(nonStockPage(p)));
      await report.load();
      exporting = true;
      final result = report.export(
          build: (rows) async {
            built = true;
            return rows.length;
          },
          permissionUnchanged: () => allowed);
      final assertion = expectLater(result, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      if (cause == 'input') {
        report.barcode.text = 'new';
      }
      if (cause == 'session') {
        scope = (
          token: 'new',
          tenant: 'tenant',
          activeStoreId: 4,
          endpoint: nonStockScope.endpoint
        );
      }
      if (cause == 'permission') {
        allowed = false;
      }
      if (cause == 'dispose') {
        report.dispose();
      }
      delayed.complete(nonStockPage(1));
      await assertion;
      expect(built, isFalse);
      if (cause != 'dispose') {
        report.dispose();
      }
    });
  }
  test(
      'listing preserves optional pagination defaults while export requires complete metadata',
      () async {
    final report = NonStockReportController(
        readScope: () async => nonStockScope,
        fetch: (q, p) async => GetNonStockReportResponse(
            status: 'success',
            message: '',
            data: [nonStockRow(p)],
            pagination: const NonStockReportPagination(lastPage: 2)));
    addTearDown(report.dispose);
    await report.load();
    expect(report.errorKey, isNull);
    expect(report.page, 1);
    expect(report.perPage, 20);
    await report.goToPage(2);
    expect(report.page, 2);
    await expectLater(
        report.export(
            build: (rows) async => rows.length,
            permissionUnchanged: () => true),
        throwsStateError);
  });
  test('export rereads when live data moves, and gives up after the limit',
      () async {
    for (final failures in [1, NonStockReportController.exportAttempts]) {
      var exporting = false, attempt = 0;
      final report = NonStockReportController(
          readScope: () async => nonStockScope,
          fetch: (q, p) async {
            if (!exporting) return nonStockPage(p, last: 2, total: 2);
            if (p == 1) attempt++;
            // A sale adds a low-stock product between page 1 and page 2.
            final moved = attempt <= failures;
            return nonStockPage(p, last: 2, total: moved && p == 2 ? 3 : 2);
          });
      await report.load();
      exporting = true;
      final export = report.export(
          build: (rows) async => rows.length, permissionUnchanged: () => true);
      if (failures == 1) {
        expect(await export, 2);
        expect(attempt, 2);
      } else {
        await expectLater(
            export, throwsA(isA<NonStockReportSnapshotChanged>()));
        expect(attempt, NonStockReportController.exportAttempts);
      }
      report.dispose();
    }
  });
  test('changed session cannot publish a table response', () async {
    var scope = nonStockScope;
    final report = NonStockReportController(
        readScope: () async => scope,
        fetch: (q, p) async {
          scope = (
            token: 'test',
            tenant: 'other',
            activeStoreId: 4,
            endpoint: scope.endpoint
          );
          return nonStockPage(p);
        });
    addTearDown(report.dispose);
    await report.load();
    expect(report.report, isNull);
    expect(report.canExport, isFalse);
    expect(report.errorKey, isNotNull);
  });
}
