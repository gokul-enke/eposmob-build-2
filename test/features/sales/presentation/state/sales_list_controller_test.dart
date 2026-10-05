import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales/domain/sales_order_query.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_list_controller.dart';

void main() {
  test(
      'search snapshots every visible filter; reset preserves online/store scope',
      () async {
    final queries = <SalesOrderQuery>[];
    final controller = SalesListController(
      fetch: (query) async => queries.add(query),
      activeStore: () => '7',
      onError: (_) {},
      isOnlineSales: true,
    );
    addTearDown(controller.dispose);
    controller.orderNumberController.text = ' ord-1 ';
    controller.customerNameController.text = ' Customer ';
    controller.amountController.text = ' 4.190 ';
    controller.emailController.text = ' a@example.com ';
    controller.phoneController.text = ' 123 ';
    controller.fromDateController.text = '2026-10-01 00:00:00';
    controller.toDateController.text = '2026-10-05 23:59:59';
    controller.selectedBusinessDate = DateTime(2026, 10, 5);
    controller.selectedStatus = 'confirmed';
    await controller.searchOrders(3);
    expect(queries.single.parameters(null), {
      'number': 'ORD-1',
      'filter_name': 'Customer',
      'filter_price': '4.190',
      'filter_email': 'a@example.com',
      'filter_phone': '123',
      'filter_datetime[from]': '2026-10-01 00:00:00',
      'filter_datetime[until]': '2026-10-05 23:59:59',
      'business_date': '2026-10-05',
      'filter_status': 'confirmed',
      'filter_store': '7',
      'page': '3',
      'filter_online_sales': 'true',
    });
    await controller.resetSearch();
    expect(controller.hasActiveFilters, isFalse);
    expect(queries.last.parameters(null), {
      'filter_store': '7',
      'page': '1',
      'filter_online_sales': 'true',
    });
  });

  test('older failure cannot replace newer loading/result or show an error',
      () async {
    final pending = <Completer<void>>[];
    final errors = <String>[];
    final controller = SalesListController(
      fetch: (_) {
        final c = Completer<void>();
        pending.add(c);
        return c.future;
      },
      activeStore: () => '7',
      onError: errors.add,
    );
    addTearDown(controller.dispose);
    final old = controller.searchOrders(1);
    final latest = controller.searchOrders(2);
    pending.first.completeError(StateError('old failure'));
    await old;
    expect(controller.initLoading, isTrue);
    expect(errors, isEmpty);
    pending.last.complete();
    await latest;
    expect(controller.initLoading, isFalse);
    expect(controller.lastRequestFailed, isFalse);
  });

  testWidgets('dispose cancels debounce and ignores an in-flight failure',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    final errors = <String>[];
    final controller = SalesListController(
      fetch: (_) {
        calls++;
        return pending.future;
      },
      activeStore: () => '7',
      onError: errors.add,
    );
    final request = controller.searchOrders(1);
    controller.onFilterTextChanged();
    controller.dispose();
    pending.completeError(StateError('late failure'));
    await request;
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, 1);
    expect(errors, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
