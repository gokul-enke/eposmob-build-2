import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchases/domain/models/purchase_order_model.dart';
import 'package:pos_machine/features/purchases/domain/purchase_order_filter.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_order_list_controller.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';

ListPurchaseOrderModel page(int n, {String amount = '1.000'}) =>
    ListPurchaseOrderModel.fromJson({
      'status': 'success',
      'data': {
        'current_page': n,
        'last_page': 5,
        'data': [
          {'id': n, 'amount_total': amount}
        ]
      }
    });
void main() {
  test('reset during directory loading still populates filter options',
      () async {
    final stores = Completer<List<GetStoreModelData>>();
    final pages = <int>[];
    final controller = PurchaseOrderListController(
      fetch: (f, p) async {
        pages.add(p);
        return page(p);
      },
      fetchStores: () => stores.future,
      fetchSuppliers: () async =>
          [GetSuppliersModelData(id: 7, name: 'Supplier')],
    );
    final loading = controller.initialize(canLoad: true);
    await controller.resetSearch();
    stores.complete([GetStoreModelData(id: 4, name: 'Shop')]);
    await loading;
    expect(controller.stores, ['All', 'Shop']);
    expect(controller.suppliers, ['All', 'Supplier']);
    expect(pages, [1]);
    controller.storeController.text = 'Shop';
    expect(controller.filter.storeId, '4');
    expect(controller.initLoading, false);
    controller.dispose();
  });
  test(
      'initial directory load and filters preserve IDs and explicit all stores',
      () async {
    final queries = <PurchaseOrderFilter>[];
    final pages = <int>[];
    final controller = PurchaseOrderListController(
        fetch: (f, p) async {
          queries.add(f);
          pages.add(p);
          return page(p);
        },
        fetchStores: () async => [GetStoreModelData(id: 4, name: 'Shop')],
        fetchSuppliers: () async =>
            [GetSuppliersModelData(id: 7, user: User(name: 'Supplier'))]);
    await controller.initialize(canLoad: true);
    expect(queries.single.storeId, 'all');
    expect(controller.stores, ['All', 'Shop']);
    controller.storeController.text = 'Shop';
    controller.supplierController.text = 'Supplier';
    controller.fromDateController.text = ' 2026-10-01 ';
    controller.toDateController.text = '2026-10-03';
    await controller.fetchPurchases(page: 3);
    expect(queries.last.storeId, '4');
    expect(queries.last.supplierId, '7');
    expect(queries.last.dateFrom, '2026-10-01');
    expect(pages.last, 3);
    await controller.resetSearch();
    expect(queries.last.storeId, 'all');
    expect(queries.last.supplierId, isNull);
    expect(queries.last.dateFrom, isNull);
    expect(pages.last, 1);
    expect(controller.hasActiveFilters, isFalse);
    controller.dispose();
  });
  test('late page completion cannot overwrite a newer reset', () async {
    final old = Completer<ListPurchaseOrderModel>();
    final controller = PurchaseOrderListController(
        fetch: (f, p) => p == 4 ? old.future : Future.value(page(p)),
        fetchStores: () async => [],
        fetchSuppliers: () async => []);
    final first = controller.fetchPurchases(page: 4);
    await controller.resetSearch();
    old.complete(page(4));
    await first;
    expect(controller.listPurchaseOrderCurrentPage, 1);
    expect(controller.purchaseOrdersList.single.id, 1);
    expect(controller.initLoading, isFalse);
    controller.dispose();
  });
  test('dispose during directory or page request ignores late work', () async {
    final pending = Completer<ListPurchaseOrderModel>();
    final controller = PurchaseOrderListController(
        fetch: (f, p) => pending.future,
        fetchStores: () async => [],
        fetchSuppliers: () async => []);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final operation = controller.fetchPurchases();
    controller.dispose();
    final before = notifications;
    pending.complete(page(2));
    await operation;
    expect(notifications, before);
  });
  test('failed load can be retried and loading is cleared', () async {
    var fail = true;
    final controller = PurchaseOrderListController(
        fetch: (f, p) async {
          if (fail) throw StateError('offline');
          return page(p);
        },
        fetchStores: () async => [],
        fetchSuppliers: () async => []);
    await controller.fetchPurchases();
    expect(controller.initLoading, isFalse);
    expect(controller.purchaseOrdersList, isEmpty);
    fail = false;
    await controller.refreshData();
    expect(controller.purchaseOrdersList.single.id, 1);
    controller.dispose();
  });
}
