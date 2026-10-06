import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/reports/domain/supplier_report.dart';
import 'package:pos_machine/features/reports/presentation/state/supplier_transactions_report_controller.dart';

Map<String, dynamic> report(int page, [String name = 'Supplier']) => {
      'data': {
        'data': [
          {
            'supplier_id': 7,
            'supplier_name': name,
            'balance': -5,
            'total_debit': 10,
            'total_credit': 5,
            'transactions': []
          }
        ],
        'current_page': page,
        'last_page': 3,
      }
    };
Future<SupplierReportScope> fixedScope() async =>
    (token: 'token', tenant: 'tenant', storeId: 1, endpoint: 'report');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const option = SupplierReportOption(id: '7', name: 'Supplier');
  for (final change in ['store', 'tenant', 'token', 'endpoint']) {
    for (final moment in ['before export', 'during fetch', 'during workbook']) {
      test('$change change $moment cancels export; refreshed scope can export',
          () async {
        var scope = await fixedScope();
        var fetches = 0;
        var exporting = false;
        void switchScope() {
          scope = (
            token: change == 'token' ? 'new-token' : scope.token,
            tenant: change == 'tenant' ? 'new-tenant' : scope.tenant,
            storeId: change == 'store' ? 2 : scope.storeId,
            endpoint: change == 'endpoint' ? 'new-report' : scope.endpoint,
          );
        }

        final controller = SupplierTransactionsReportController(
            readScope: () async => scope,
            fetchDirectory: () async => [option],
            fetch: (_, page) async {
              fetches++;
              if (exporting && moment == 'during fetch') switchScope();
              return report(page)..['data']['last_page'] = 1;
            });
        addTearDown(controller.dispose);
        await controller.initialize();
        final visible = controller.rows;
        exporting = true;
        if (moment == 'before export') switchScope();
        await expectLater(controller.export(build: (rows) async {
          if (moment == 'during workbook') switchScope();
          return rows;
        }), throwsStateError);
        expect(fetches, moment == 'before export' ? 1 : 2);
        expect(controller.rows, same(visible));
        expect(controller.page, 1);
        exporting = false;
        await controller.retry();
        expect(controller.errorKey, isNull);
        expect(await controller.exportRows(), hasLength(1));
      });
    }
  }
  test('scope change during refresh rejects its response and retains old rows',
      () async {
    var scope = await fixedScope();
    var change = false;
    final controller = SupplierTransactionsReportController(
        readScope: () async => scope,
        fetchDirectory: () async => [],
        fetch: (_, page) async {
          if (change) {
            scope = (
              token: 'new-token',
              tenant: 'tenant',
              storeId: 2,
              endpoint: 'report'
            );
          }
          return report(page, change ? 'Wrong scope' : 'Original');
        });
    addTearDown(controller.dispose);
    await controller.load();
    change = true;
    await controller.load();
    expect(controller.rows['7']!.displayName, 'Original');
    expect(controller.canExport, isFalse);
    expect(controller.loading, isFalse);
    expect(controller.errorKey, isNotNull);
    change = false;
    await controller.retry();
    expect(controller.errorKey, isNull);
    expect(controller.canExport, isTrue);
  });
  test('filter change and disposal during workbook creation prevent delivery',
      () async {
    for (final dispose in [false, true]) {
      final controller = SupplierTransactionsReportController(
          readScope: fixedScope,
          fetchDirectory: () async => [],
          fetch: (_, page) async => report(page)..['data']['last_page'] = 1);
      await controller.load();
      await expectLater(controller.export(build: (rows) async {
        if (dispose) {
          controller.dispose();
        } else {
          await controller.selectSupplier(option);
        }
        return rows;
      }), throwsStateError);
      if (!dispose) controller.dispose();
    }
  });
  test(
      'export snapshots filters, leaves visible page alone and aborts on Reset',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    var exporting = false;
    final queries = <SupplierReportQuery>[];
    final controller = SupplierTransactionsReportController(
        readScope: fixedScope,
        fetchDirectory: () async => [option],
        fetch: (query, page) async {
          queries.add(query);
          if (exporting) return pending.future;
          return report(page)..['data']['last_page'] = 1;
        });
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.selectSupplier(option);
    expect(controller.canExport, isTrue);
    final visible = controller.rows;
    exporting = true;
    final operation = controller.exportRows();
    final failure = expectLater(operation, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    exporting = false;
    await controller.reset();
    pending.complete(report(1)..['data']['last_page'] = 1);
    await failure;
    expect(queries[2].supplierId, '7');
    expect(visible['7']!.displayName, 'Supplier');
    expect(controller.selectedSupplierId, isNull);
  });
  test('export is disabled for pending loads, failed loads and invalid dates',
      () async {
    var failed = false;
    final controller = SupplierTransactionsReportController(
        readScope: fixedScope,
        fetchDirectory: () async => [option],
        fetch: (_, page) async {
          if (failed) throw StateError('network');
          return report(page);
        });
    addTearDown(controller.dispose);
    final loading = controller.initialize();
    expect(controller.canExport, isFalse);
    await loading;
    expect(controller.canExport, isTrue);
    failed = true;
    await controller.load();
    expect(controller.canExport, isFalse);
    expect(controller.rows, isNotEmpty);
    failed = false;
    await controller.retry();
    expect(controller.canExport, isTrue);
    controller.toInput.text = '2026-01-01';
    await controller.selectDate(DateTime(2026, 2, 1), true);
    expect(controller.canExport, isFalse);
    await expectLater(controller.exportRows(), throwsStateError);
  });
  test(
      'initialize -> page -> supplier/date filters -> Reset -> page carries exact filters',
      () async {
    final calls = <({SupplierReportQuery query, int page})>[];
    var directories = 0;
    final controller = SupplierTransactionsReportController(
        readScope: fixedScope,
        fetchDirectory: () async {
          directories++;
          return [option];
        },
        fetch: (query, page) async {
          calls.add((query: query, page: page));
          return report(page);
        });
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.goToPage(2);
    await controller.selectSupplier(option);
    await controller.selectDate(DateTime(2026, 9, 1), true);
    await controller.selectDate(DateTime(2026, 10, 1), false);
    expect(calls.last.query.supplierId, '7');
    expect(calls.last.query.fromDate, '2026-09-01');
    expect(calls.last.query.toDate, '2026-10-01');
    expect(calls.last.page, 1);
    expect(controller.hasActiveFilters, isTrue);
    await controller.reset();
    expect(directories, 2);
    expect(controller.page, 1);
    expect(controller.hasActiveFilters, isFalse);
    expect(calls.last.query.supplierId, isNull);
    expect(calls.last.query.fromDate, isNull);
    expect(calls.last.query.toDate, isNull);
    await controller.goToPage(2);
    expect(calls.last.page, 2);
  });
  test('newer response wins; failed refresh retains rows and page for retry',
      () async {
    final pending = <Completer<Map<String, dynamic>>>[];
    final controller = SupplierTransactionsReportController(
        readScope: fixedScope,
        fetchDirectory: () async => [],
        fetch: (_, __) {
          final call = Completer<Map<String, dynamic>>();
          pending.add(call);
          return call.future;
        });
    addTearDown(controller.dispose);
    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    final second = controller.selectSupplier(option);
    await Future<void>.delayed(Duration.zero);
    pending[1].complete(report(1, 'New'));
    await second;
    pending[0].complete(report(2, 'Old'));
    await first;
    expect(controller.rows['7']!.displayName, 'New');
    expect(controller.page, 1);
    final failed = controller.load();
    await Future<void>.delayed(Duration.zero);
    pending[2].completeError(StateError('network'));
    await failed;
    expect(controller.rows['7']!.displayName, 'New');
    expect(controller.loading, isFalse);
    expect(controller.errorKey, isNotNull);
    final retry = controller.load();
    await Future<void>.delayed(Duration.zero);
    pending[3].complete(report(1, 'Retry'));
    await retry;
    expect(controller.errorKey, isNull);
    expect(controller.rows['7']!.displayName, 'Retry');
  });
  test('inverted dates invalidate older response without sending a new request',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    final controller = SupplierTransactionsReportController(
        readScope: fixedScope,
        fetchDirectory: () async => [],
        fetch: (_, __) {
          calls++;
          return pending.future;
        });
    addTearDown(controller.dispose);
    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.toInput.text = '2026-09-01';
    await controller.selectDate(DateTime(2026, 10, 1), true);
    pending.complete(report(1));
    await first;
    expect(calls, 1);
    expect(controller.rows, isEmpty);
    expect(controller.errorKey,
        'supplier_transaction_report.from_date_after_to_date');
    expect(controller.loading, isFalse);
  });
  test('Reset invalidates a pending filtered page and starts on All suppliers',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    final controller = SupplierTransactionsReportController(
        readScope: fixedScope,
        fetchDirectory: () async => [option],
        fetch: (query, page) {
          calls++;
          return calls == 1
              ? pending.future
              : Future.value(report(page, 'All'));
        });
    addTearDown(controller.dispose);
    final filtered = controller.selectSupplier(option);
    await Future<void>.delayed(Duration.zero);
    await controller.reset();
    pending.complete(report(3, 'Filtered'));
    await filtered;
    expect(controller.rows['7']!.displayName, 'All');
    expect(controller.page, 1);
    expect(controller.selectedSupplierId, isNull);
  });
  test('disposal during directory load prevents report fetch and notifications',
      () async {
    final pending = Completer<List<SupplierReportOption>>();
    var calls = 0, notifications = 0;
    final controller = SupplierTransactionsReportController(
        readScope: fixedScope,
        fetchDirectory: () => pending.future,
        fetch: (_, __) async {
          calls++;
          return report(1);
        });
    controller.addListener(() => notifications++);
    final operation = controller.initialize();
    controller.dispose();
    pending.complete([option]);
    await operation;
    expect(calls, 0);
    expect(notifications, 1);
    await controller.selectSupplier(option);
    await controller.reset();
  });
  test('directory failure releases initialization and can retry', () async {
    var failed = true;
    final controller = SupplierTransactionsReportController(
        readScope: fixedScope,
        fetchDirectory: () async {
          if (failed) throw StateError('directory');
          return [option];
        },
        fetch: (_, page) async => report(page));
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.initializing, isFalse);
    expect(controller.errorKey, isNotNull);
    failed = false;
    await controller.initialize();
    expect(controller.errorKey, isNull);
    expect(controller.rows, isNotEmpty);
  });
}
