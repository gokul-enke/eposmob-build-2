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
            'transactions': []
          }
        ],
        'current_page': page,
        'last_page': 3,
      }
    };
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const option = SupplierReportOption(id: '7', name: 'Supplier');
  test(
      'initialize -> page -> supplier/date filters -> Reset -> page carries exact filters',
      () async {
    final calls = <({SupplierReportQuery query, int page})>[];
    var directories = 0;
    final controller =
        SupplierTransactionsReportController(fetchDirectory: () async {
      directories++;
      return [option];
    }, fetch: (query, page) async {
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
        fetchDirectory: () async => [],
        fetch: (_, __) {
          final call = Completer<Map<String, dynamic>>();
          pending.add(call);
          return call.future;
        });
    addTearDown(controller.dispose);
    final first = controller.load();
    final second = controller.selectSupplier(option);
    pending[1].complete(report(1, 'New'));
    await second;
    pending[0].complete(report(2, 'Old'));
    await first;
    expect(controller.rows['7']!.displayName, 'New');
    expect(controller.page, 1);
    final failed = controller.load();
    pending[2].completeError(StateError('network'));
    await failed;
    expect(controller.rows['7']!.displayName, 'New');
    expect(controller.loading, isFalse);
    expect(controller.errorKey, isNotNull);
    final retry = controller.load();
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
        fetchDirectory: () async => [],
        fetch: (_, __) {
          calls++;
          return pending.future;
        });
    addTearDown(controller.dispose);
    final first = controller.load();
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
        fetchDirectory: () async => [option],
        fetch: (query, page) {
          calls++;
          return calls == 1
              ? pending.future
              : Future.value(report(page, 'All'));
        });
    addTearDown(controller.dispose);
    final filtered = controller.selectSupplier(option);
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
