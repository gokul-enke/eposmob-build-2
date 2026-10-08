import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales/data/sales_orders_api.dart';
import 'package:pos_machine/features/sales/data/sales_repository.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/features/sales/domain/sales_action_error.dart';
import 'package:pos_machine/features/sales/domain/sales_order_query.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';

class Orders extends SalesOrdersApi {
  final pending = <Completer<ListSalesOrderModel>>[];
  final queries = <SalesOrderQuery>[];
  @override
  Future<ListSalesOrderModel> fetchOrders(String token, SalesOrderQuery query) {
    queries.add(query);
    final c = Completer<ListSalesOrderModel>();
    pending.add(c);
    return c.future;
  }
}

ListSalesOrderModel page(int id) =>
    ListSalesOrderModel(data: [ListOrderModelData(id: id)]);
void main() {
  test('new query beats older response and realtime supersedes in-flight load',
      () async {
    final api = Orders();
    final p = SalesProvider(repository: SalesRepository(orders: api));
    addTearDown(p.dispose);
    var notifications = 0;
    p.addListener(() => notifications++);
    final first = p.fetchOrders(accessToken: 'token', filterName: 'old');
    final second = p.fetchOrders(accessToken: 'token', filterName: 'new');
    api.pending[1].complete(page(2));
    await second;
    api.pending[0].complete(page(1));
    await first;
    expect(p.orders.single.id, 2);
    expect(notifications, 1);
    final third = p.fetchOrders(accessToken: 'token');
    p.applyRealtimeOrders([ListOrderModelData(id: 3)]);
    api.pending[2].complete(page(4));
    await third;
    expect(p.orders.single.id, 3);
    expect(notifications, 2);
  });
  test('failed refresh preserves rows and successful query replay', () async {
    final api = Orders();
    final p = SalesProvider(repository: SalesRepository(orders: api));
    addTearDown(p.dispose);
    final initial = p.fetchOrders(
        accessToken: 'token', customerId: 12, filterStatus: 'paid', page: 3);
    api.pending[0].complete(page(1));
    await initial;
    final bad = p.fetchOrders(accessToken: 'token', filterName: 'failed');
    final assertion = expectLater(bad, throwsException);
    api.pending[1].completeError(const SalesApiException('server failed'));
    await assertion;
    expect(p.orders.single.id, 1);
    expect(p.ordersError, contains('server failed'));
    final refresh =
        p.refreshOrdersForRealtime(accessToken: 'new-token', storeId: 7);
    expect(api.queries.last.customerId, 12);
    expect(api.queries.last.filterStatus, 'paid');
    expect(api.queries.last.page, 3);
    api.pending[2].complete(page(2));
    await refresh;
    expect(p.ordersError, isNull);
  });
  test('late completion after provider disposal does not notify', () async {
    final api = Orders();
    final p = SalesProvider(repository: SalesRepository(orders: api));
    var notifications = 0;
    p.addListener(() => notifications++);
    final request = p.fetchOrders(accessToken: 'token');
    p.dispose();
    api.pending.single.complete(page(1));
    await request;
    expect(notifications, 0);
  });
}
