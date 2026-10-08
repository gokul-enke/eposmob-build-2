import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales_returns/data/sales_return_api.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return_items.dart';
import 'package:pos_machine/features/sales_returns/domain/models/sales_return_refund_breakdown.dart';
import 'package:pos_machine/features/sales_returns/presentation/state/sales_return_form_controller.dart';
import 'package:pos_machine/features/sales_returns/presentation/state/sales_return_form_ports.dart';
import '../../support/return_fixtures.dart';

SalesReturnFormController makeForm({
  Future<SalesReturnItemsResponse> Function(String)? items,
  ReturnComplete? complete,
  ReturnSubmit? submit,
  String passedNumber = '',
  void Function(String)? error,
  Future<int?> Function()? store,
  ReturnFetchOrders? fetchOrders,
}) =>
    SalesReturnFormController(SalesReturnFormPorts(
        token: () => 'token',
        storeId: store ?? () async => 1,
        passedNumber: () => passedNumber,
        passedId: () => '',
        clearNavigation: () {},
        fetchOrders: fetchOrders ??
            (
                {required accessToken,
                storeId,
                orderNumber,
                customerId,
                date,
                page}) async {},
        orders: () => [],
        currentPage: () => 1,
        totalPages: () => 1,
        items: items ?? (_) async => returnItems(),
        details: (_) async => {'status': 'success'},
        submit: submit ??
            (
                    {required accessToken,
                    required orderId,
                    required price,
                    required quantity,
                    required cartItemId,
                    required reason,
                    isDeliveryRefundable = false}) async =>
                const SalesReturnSubmission(75, null),
        complete: complete ??
            (
                    {required accessToken,
                    required returnOrderId,
                    paymentMethod,
                    paidAmount,
                    hasPayment,
                    isDeliveryRefundable = false}) async =>
                null,
        error: error ?? (_) {}));

void main() {
  test('late item submission cannot restore draft after Reset', () async {
    final pending = Completer<SalesReturnSubmission>();
    final controller = makeForm(
        submit: (
                {required accessToken,
                required orderId,
                required price,
                required quantity,
                required cartItemId,
                required reason,
                isDeliveryRefundable = false}) =>
            pending.future);
    final submit = controller.submitSalesReturn(
        accessToken: 'token',
        orderId: 100,
        price: 10,
        quantity: 1,
        cartItemId: 40,
        reason: 'Damaged');
    controller.resetSearch();
    pending.complete(const SalesReturnSubmission(75, null));
    await submit;
    expect(controller.draftReturnOrderId, isNull);
    controller.dispose();
  });
  test('late completion after Reset does not request navigation away',
      () async {
    final pending = Completer<SalesReturnRefundBreakdown?>();
    final controller = makeForm(
        complete: (
                {required accessToken,
                required returnOrderId,
                paymentMethod,
                paidAmount,
                hasPayment,
                isDeliveryRefundable = false}) =>
            pending.future);
    controller.salesReturnItems = returnItems().data;
    controller.activeReturnOrderId = 75;
    controller.isOrderSelected = true;
    final complete = controller.completeCurrentReturn();
    controller.resetSearch();
    pending.complete(null);
    expect(await complete, isFalse);
    controller.dispose();
  });
  test('refresh during completion still reports success once', () async {
    final pending = Completer<SalesReturnRefundBreakdown?>();
    final controller = makeForm(
        complete: (
                {required accessToken,
                required returnOrderId,
                paymentMethod,
                paidAmount,
                hasPayment,
                isDeliveryRefundable = false}) =>
            pending.future);
    controller.salesReturnItems = returnItems().data;
    controller.activeReturnOrderId = 75;
    controller.selectedOrderNumber = 'ORD-1';
    controller.isOrderSelected = true;
    final complete = controller.completeCurrentReturn();
    // A pull-to-refresh (non-resetting getOrderDetails) bumps the counter.
    controller.detailsRequest++;
    pending.complete(null);
    expect(await complete, isTrue);
    expect(controller.canCompleteReturn, isFalse);
    controller.dispose();
  });
  test('Reset during passed-order initialization cannot reopen the order',
      () async {
    final pending = Completer<void>();
    var calls = 0;
    final controller = makeForm(
        passedNumber: 'old',
        fetchOrders: (
            {required accessToken,
            storeId,
            orderNumber,
            customerId,
            date,
            page}) {
          calls++;
          return calls == 1 ? pending.future : Future<void>.value();
        });
    final init = controller.initialize();
    controller.resetSearch();
    pending.complete();
    await init;
    expect(controller.isOrderSelected, isFalse);
    expect(controller.salesReturnItems, isEmpty);
    controller.dispose();
  });
  test('pending search cannot restore selection after Reset', () async {
    final pending = Completer<void>();
    var calls = 0;
    final controller = makeForm(fetchOrders: (
        {required accessToken, storeId, orderNumber, customerId, date, page}) {
      calls++;
      return calls == 1 ? pending.future : Future<void>.value();
    });
    controller.isOrderSelected = true;
    controller.selectedOrderId = '100';
    controller.selectedOrderNumber = 'old';
    final search = controller.searchOrders(1);
    controller.resetSearch();
    pending.complete();
    await search;
    expect(controller.isOrderSelected, isFalse);
    expect(controller.selectedOrderNumber, isNull);
    controller.dispose();
  });
  test('pending search cannot replace a newly selected order', () async {
    final pending = Completer<void>();
    final controller = makeForm(
        fetchOrders: (
                {required accessToken,
                storeId,
                orderNumber,
                customerId,
                date,
                page}) =>
            pending.future);
    controller.isOrderSelected = true;
    controller.selectedOrderId = '100';
    controller.selectedOrderNumber = 'old';
    final search = controller.searchOrders(1);
    await controller.getOrderDetails('new');
    pending.complete();
    await search;
    expect(controller.selectedOrderNumber, 'new');
    controller.dispose();
  });
  test('reset while item lookup is pending cannot restore previous selection',
      () async {
    final pending = Completer<SalesReturnItemsResponse>();
    final controller = makeForm(items: (_) => pending.future);
    final load = controller.getOrderDetails('old');
    controller.resetSearch();
    pending.complete(returnItems());
    await load;
    expect(controller.isOrderSelected, isFalse);
    expect(controller.salesReturnItems, isEmpty);
    controller.dispose();
  });
  test(
      'newer item request wins without older loading flag or baseline overwrites',
      () async {
    final pending = <Completer<SalesReturnItemsResponse>>[];
    final controller = makeForm(items: (_) {
      final item = Completer<SalesReturnItemsResponse>();
      pending.add(item);
      return item.future;
    });
    final old = controller.getOrderDetails('old');
    final newer = controller.getOrderDetails('new');
    pending[1].complete(returnItems(id: 50));
    await newer;
    pending[0].complete(returnItems());
    await old;
    expect(controller.selectedOrderNumber, 'new');
    expect(controller.salesReturnItems.single.cartItemId, 50);
    expect(controller.initialReturnedTotals.keys, [50]);
    controller.dispose();
  });
  test('disposed form does not fetch orders after delayed store lookup',
      () async {
    final store = Completer<int?>();
    var calls = 0;
    final controller = makeForm(
        store: () => store.future,
        fetchOrders: (
            {required accessToken,
            storeId,
            orderNumber,
            customerId,
            date,
            page}) async {
          calls++;
        });
    final load = controller.loadInitData();
    controller.dispose();
    store.complete(1);
    await load;
    expect(calls, 0);
  });
  test('submit stores draft ID and refresh preserves session baseline',
      () async {
    final controller = makeForm();
    await controller.getOrderDetails('INV');
    expect(controller.initialReturnedTotals[40], 10);
    final id = await controller.submitSalesReturn(
        accessToken: 'token',
        orderId: 100,
        price: 10,
        quantity: 1,
        cartItemId: 40,
        reason: 'Damaged');
    expect(id, 75);
    expect(controller.draftReturnOrderId, 75);
    await controller.getOrderDetails('INV', resetInitialState: false);
    expect(controller.draftReturnOrderId, 75);
    expect(controller.initialReturnedTotals[40], 10);
    controller.dispose();
  });
  test('completion validates payment, sends once and ignores late disposal',
      () async {
    final pending = Completer<SalesReturnRefundBreakdown?>();
    var calls = 0;
    final errors = <String>[];
    final controller = makeForm(
        error: errors.add,
        complete: (
            {required accessToken,
            required returnOrderId,
            paymentMethod,
            paidAmount,
            hasPayment,
            isDeliveryRefundable = false}) {
          calls++;
          expect(returnOrderId, 75);
          expect(hasPayment, isFalse);
          return pending.future;
        });
    controller.salesReturnItems = returnItems().data;
    controller.activeReturnOrderId = 75;
    controller.isOrderSelected = true;
    controller.hasPayment = true;
    controller.paidAmountController.text = '11';
    expect(await controller.completeCurrentReturn(), isFalse);
    expect(calls, 0);
    expect(errors, isNotEmpty);
    controller.hasPayment = false;
    final submit = controller.completeCurrentReturn();
    expect(await controller.completeCurrentReturn(), isFalse);
    expect(calls, 1);
    controller.dispose();
    pending.complete(null);
    expect(await submit, isFalse);
  });
}
