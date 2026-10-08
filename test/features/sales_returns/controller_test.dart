import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales_returns/domain/sales_return_list.dart';
import 'package:pos_machine/features/sales_returns/presentation/state/sales_return_list_controller.dart';
import 'support.dart';

void main() {
  test(
      'failed next page retains the displayed page and Retry retries its target',
      () async {
    var fail = true;
    final source = ReturnSource((p) async {
      if (p == 2 && fail) throw StateError('offline');
      return returnData([returnRow(p)], page: p, perPage: 1, total: 2);
    });
    final controller = SalesReturnListController(() async => source);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.canExport, isTrue);
    await controller.load(page: 2);
    expect(controller.data!.page, 1);
    expect(controller.canExport, isFalse);
    expect(controller.error, isNotNull);
    fail = false;
    await controller.load();
    expect(controller.data!.page, 2);
    expect(controller.error, isNull);
    expect(source.calls, [1, 2, 2]);
    await controller.load();
    expect(source.calls.last, 2);
  });
  test('an older successful request cannot replace a newer page', () async {
    final pending = Completer<SalesReturnListData>();
    final source = ReturnSource((p) => p == 1
        ? pending.future
        : Future.value(
            returnData([returnRow(2)], page: 2, perPage: 1, total: 2)));
    final controller = SalesReturnListController(() async => source);
    addTearDown(controller.dispose);
    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    await controller.load(page: 2);
    pending.complete(returnData([returnRow(1)], perPage: 1, total: 2));
    await first;
    expect(controller.data!.page, 2);
    expect(controller.loading, isFalse);
  });
  test('disposal ignores a pending failure without notifying listeners',
      () async {
    final pending = Completer<SalesReturnListData>();
    final source = ReturnSource((_) => pending.future);
    final controller = SalesReturnListController(() async => source);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final load = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    final before = notifications;
    pending.completeError(StateError('offline'));
    await load;
    expect(notifications, before);
  });
  test('a changed store discards old rows before the new store fails',
      () async {
    var source = ReturnSource((_) async => returnData([returnRow(1)]));
    final controller = SalesReturnListController(() async => source);
    addTearDown(controller.dispose);
    await controller.load();
    source = ReturnSource((_) async => throw StateError('offline'),
        scope: const SalesReturnListScope(
            token: 'test-token',
            tenant: 'test-tenant',
            endpoint: 'https://example.invalid/returns',
            storeId: 3));
    await controller.load(page: 2);
    expect(controller.data, isNull);
    expect(source.calls, [1]);
    expect(controller.canExport, isFalse);
  });
  test('store change during fetch reloads page one of the current store',
      () async {
    final newer = ReturnSource((_) async => returnData([returnRow(2)]),
        scope: const SalesReturnListScope(
            token: 'new-token',
            tenant: 'test-tenant',
            endpoint: 'https://example.invalid/returns',
            storeId: 3));
    late ReturnSource source;
    source = ReturnSource((_) async {
      source = newer;
      return returnData([returnRow(1)]);
    });
    final controller = SalesReturnListController(() async => source);
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.data!.rows.single.id, 2);
    expect(controller.matchesScope(newer.scope), isTrue);
  });
  test('refresh recovers to the last page when total pages shrink', () async {
    var total = 3;
    final source = ReturnSource((p) async => returnData(
        p > total ? [] : [returnRow(p)],
        page: p,
        perPage: 1,
        total: total));
    final controller = SalesReturnListController(() async => source);
    addTearDown(controller.dispose);
    await controller.load(page: 3);
    total = 2;
    await controller.load();
    expect(source.calls, [3, 3, 2]);
    expect(controller.data!.page, 2);
    expect(controller.canExport, isTrue);
  });
}
