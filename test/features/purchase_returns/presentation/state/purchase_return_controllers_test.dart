import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/purchase_return.dart';
import 'package:pos_machine/features/purchase_returns/presentation/state/purchase_return_list_controller.dart';
import 'package:pos_machine/features/purchase_returns/presentation/state/create_purchase_return_controller.dart';
import 'package:pos_machine/features/purchase_returns/presentation/state/purchase_return_detail_controller.dart';
import 'package:pos_machine/models/get_suppliers.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/purchase_order_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('list initialization, filter query, pagination and reset', () async {
    final queries = <String?>[];
    final dates = <String?>[];
    final pages = <int>[];
    final controller = PurchaseReturnListController(
        fallbackError: 'Failed',
        onError: (_) {},
        fetchSuppliers: () async =>
            [GetSuppliersModelData(id: 7, user: User(name: 'Supplier'))],
        fetch: (filter, page) async {
          queries.add(filter.supplierId);
          dates.add(filter.dateFrom);
          pages.add(page);
          return ListPurchaseReturnData(
              currentPage: page,
              lastPage: 4,
              data: [PurchaseReturnData(id: page)]);
        });
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(controller.suppliers, ['All', 'Supplier']);
    controller.supplierController.text = 'Supplier';
    controller.fromDateController.text = ' 2026-09-01 ';
    expect(controller.hasActiveFilters(), isTrue);
    await controller.fetchReturns(page: 3);
    expect(queries.last, '7');
    expect(dates.last, '2026-09-01');
    expect(controller.currentPage, 3);
    await controller.resetFilters();
    expect(queries.last, isNull);
    expect(dates.last, isNull);
    expect(pages, [1, 3, 1]);
    expect(controller.hasActiveFilters(), isFalse);
  });
  test('older list response and post-dispose completion are ignored', () async {
    final requests = <Completer<ListPurchaseReturnData>>[];
    final controller = PurchaseReturnListController(
        fallbackError: 'Failed',
        onError: (_) {},
        fetchSuppliers: () async => [],
        fetch: (filter, page) {
          final c = Completer<ListPurchaseReturnData>();
          requests.add(c);
          return c.future;
        });
    final first = controller.fetchReturns(page: 2);
    final second = controller.fetchReturns(page: 3);
    requests[1].complete(ListPurchaseReturnData(
        currentPage: 3, data: [PurchaseReturnData(id: 3)]));
    await second;
    requests[0].complete(ListPurchaseReturnData(
        currentPage: 2, data: [PurchaseReturnData(id: 2)]));
    await first;
    expect(controller.purchaseReturnsList.single.id, 3);
    final pending = controller.fetchReturns(page: 4);
    controller.dispose();
    requests.last.complete(ListPurchaseReturnData(data: []));
    await pending;
  });
  test('list error remains visible and retry recovers', () async {
    var fail = true;
    final errors = <String>[];
    final controller = PurchaseReturnListController(
        fallbackError: 'Failed',
        onError: errors.add,
        fetchSuppliers: () async => [],
        fetch: (filter, page) async {
          if (fail) throw const HttpException('Denied');
          return ListPurchaseReturnData(data: [PurchaseReturnData(id: 1)]);
        });
    addTearDown(controller.dispose);
    await controller.fetchReturns();
    expect(controller.isLoading, isFalse);
    expect(controller.loadError, contains('Denied'));
    expect(errors, hasLength(1));
    fail = false;
    await controller.fetchReturns();
    expect(controller.loadError, isNull);
    expect(controller.purchaseReturnsList, hasLength(1));
  });
  CreatePurchaseReturnController form(
          {Future<ReturnableItemsData?> Function(int)? fetchItems,
          CreateReturn? create,
          Future<ListPurchaseOrderData> Function(int)? vouchers}) =>
      CreatePurchaseReturnController(
        fetchVouchers: vouchers ??
            (page) async => ListPurchaseOrderData(
                currentPage: page,
                lastPage: 3,
                data: [PurchaseOrderData(id: page)]),
        fetchItems: fetchItems ??
            (id) async => ReturnableItemsData(items: [
                  ReturnableItem(
                      purchaseItemId: id, unitPrice: 5, returnableQuantity: 3)
                ]),
        fetchPaymentMethods: () async =>
            [MasterDataValue(id: 2, value: 'Cash', description: 'Cash')],
        create: create ??
            (
                    {required purchaseVoucherId,
                    required returnDate,
                    required items,
                    required hasPayment,
                    paidAmount,
                    paymentMethod}) async =>
                {'status': 'success'},
      );
  test(
      'form loading, item edit/removal, pricing and manual payment preservation',
      () async {
    final controller = form();
    addTearDown(controller.dispose);
    await controller.loadVouchers(page: 2);
    await controller.loadPaymentMethods();
    await controller.onVoucherSelected(PurchaseOrderData(id: 10));
    expect(controller.listPurchaseOrderCurrentPage, 2);
    expect(controller.paymentMethods.single.id, 2);
    expect(controller.voucherSelected, isTrue);
    final item = controller.returnableItemsList.single;
    controller.addItem(item, 2, 'Damaged');
    expect(controller.totalReturnAmount, 10);
    expect(controller.paidAmountController.text, '10.00');
    controller.addItem(item, 1, 'Changed');
    expect(controller.returnItems, hasLength(1));
    expect(controller.returnItems.single.reason, 'Changed');
    expect(controller.totalReturnAmount, 5);
    controller.paidAmountController.text = '2.00';
    controller.paidAmountManuallyEdited = true;
    controller.addItem(item, 2, '');
    expect(controller.paidAmountController.text, '2.00');
    controller.removeReturnItem(0);
    expect(controller.totalReturnAmount, 0);
    expect(controller.totalReturnQty, 0);
  });
  test('returnable-item failure, retry and stale selection/back completion',
      () async {
    var fail = true;
    final pending = <int, Completer<ReturnableItemsData?>>{};
    final controller = form(fetchItems: (id) async {
      if (fail) throw const HttpException('Unavailable');
      return pending
          .putIfAbsent(id, Completer<ReturnableItemsData?>.new)
          .future;
    });
    await controller.onVoucherSelected(PurchaseOrderData(id: 1));
    expect(controller.itemsLoadError, 'Unavailable');
    expect(controller.isLoadingItems, isFalse);
    fail = false;
    final retry = controller.retryLoadReturnableItems();
    pending[1]!.complete(
        ReturnableItemsData(items: [ReturnableItem(purchaseItemId: 1)]));
    await retry;
    expect(controller.itemsLoadError, isNull);
    final newer = controller.onVoucherSelected(PurchaseOrderData(id: 2));
    controller.backToVouchers();
    pending[2]!.complete(
        ReturnableItemsData(items: [ReturnableItem(purchaseItemId: 2)]));
    await newer;
    expect(controller.voucherSelected, isFalse);
    expect(controller.returnableItemsList.single.purchaseItemId, 1);
    final disposed = controller.onVoucherSelected(PurchaseOrderData(id: 3));
    controller.dispose();
    pending[3]!.complete(null);
    await disposed;
  });
  test(
      'submit snapshots payload, blocks duplicates and resets loading on error',
      () async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    Map<String, dynamic>? payload;
    final controller = form(create: (
        {required purchaseVoucherId,
        required returnDate,
        required items,
        required hasPayment,
        paidAmount,
        paymentMethod}) {
      calls++;
      payload = {
        'id': purchaseVoucherId,
        'date': returnDate,
        'items': items,
        'hasPayment': hasPayment,
        'amount': paidAmount,
        'method': paymentMethod
      };
      return pending.future;
    });
    addTearDown(controller.dispose);
    expect(await controller.submitReturn(), isNull);
    await controller.onVoucherSelected(PurchaseOrderData(id: 10));
    controller.addItem(controller.returnableItemsList.single, 2, 'Damaged');
    controller.returnDate = DateTime(2026, 9, 30);
    controller.selectedPaymentMethod =
        MasterDataValue(id: 2, value: 'Cash', description: 'Cash');
    controller.paidAmountController.text = '11';
    expect(await controller.submitReturn(), isNull);
    expect(calls, 0);
    controller.paidAmountController.text = '10';
    final submit = controller.submitReturn();
    expect(await controller.submitReturn(), isNull);
    expect(calls, 1);
    expect(payload, {
      'id': 10,
      'date': '2026-09-30',
      'items': [
        {'purchase_item_id': 10, 'quantity': 2.0, 'reason': 'Damaged'}
      ],
      'hasPayment': true,
      'amount': 10.0,
      'method': '2'
    });
    pending.completeError(StateError('Failed'));
    await expectLater(submit, throwsStateError);
    expect(controller.isSubmitting, isFalse);
  });
  test('voucher request race and dispose do not notify stale values', () async {
    final requests = <Completer<ListPurchaseOrderData>>[];
    final controller = form(vouchers: (page) {
      final c = Completer<ListPurchaseOrderData>();
      requests.add(c);
      return c.future;
    });
    final first = controller.loadVouchers(page: 1);
    final second = controller.loadVouchers(page: 2);
    requests[1].complete(ListPurchaseOrderData(
        currentPage: 2, data: [PurchaseOrderData(id: 2)]));
    await second;
    requests[0].complete(ListPurchaseOrderData(
        currentPage: 1, data: [PurchaseOrderData(id: 1)]));
    await first;
    expect(controller.purchaseOrdersList.single.id, 2);
    final third = controller.loadVouchers(page: 3);
    controller.dispose();
    requests[2].complete(ListPurchaseOrderData(data: []));
    await third;
  });
  test('details retain summary on failure and ignore disposal', () async {
    final summary = PurchaseReturnData(id: 9, reference: 'RET-9');
    final pending = Completer<PurchaseReturnData?>();
    final controller = PurchaseReturnDetailController(
        initial: summary, fetch: (_) => pending.future);
    final fetch = controller.loadDetails();
    pending.complete(null);
    await fetch;
    expect(controller.displayData, same(summary));
    expect(controller.isLoading, isFalse);
    controller.dispose();
    final second = Completer<PurchaseReturnData?>();
    final disposed = PurchaseReturnDetailController(
        initial: summary, fetch: (_) => second.future);
    final loading = disposed.loadDetails();
    disposed.dispose();
    second.complete(PurchaseReturnData(id: 10));
    await loading;
    expect(disposed.displayData, same(summary));
  });
}
