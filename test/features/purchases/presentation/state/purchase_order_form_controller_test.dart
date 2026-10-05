import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchases/data/purchase_order_draft_cache.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_order_editable_item.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_order_form_controller.dart';
import 'package:pos_machine/features/purchases/presentation/state/purchase_order_form_ports.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/get_store.dart';
import 'package:pos_machine/models/get_suppliers.dart';

import '../../support/fixed_session.dart';

class MemoryDraft extends PurchaseOrderDraftCache {
  dynamic value;
  bool opened = false;
  int clears = 0;
  int reads = 0;
  @override
  Future<void> open() async {
    opened = true;
  }

  @override
  bool get isOpen => opened;
  @override
  dynamic read() {
    reads++;
    return value;
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    value = data;
  }

  @override
  Future<void> clear() async {
    value = null;
    clears++;
  }
}

class Harness {
  Map<String, dynamic>? details;
  final cache = MemoryDraft();
  final errors = <String>[];
  final requests = <Map<String, dynamic>>[];
  int completed = 0;
  int refreshes = 0;
  dynamic response = {'status': 'success'};
  Completer<Map<String, dynamic>?>? productDialog;
  final store = GetStoreModelData(id: 42, name: 'Store');
  final supplier = GetSuppliersModelData(id: 9, name: 'Supplier');
  late final PurchaseOrderFormController controller =
      PurchaseOrderFormController(
          cache: cache,
          ports: PurchaseOrderFormPorts(
              purchases: PurchaseFormPurchasePort(
                  readStores: () => [store],
                  readSuppliers: () => [supplier],
                  readUnits: () => {'PC': 'Piece'},
                  readRacks: () => {},
                  readDetails: () => details,
                  writeDetails: (v) => details = v,
                  listAllStores: (a, b) async {},
                  listAllSuppliers: (a, b) async {},
                  createPurchaseOrder: (
                      {required accessToken,
                      required purchaseDate,
                      required supplierId,
                      required storeId,
                      voucherNumber,
                      invoiceRef,
                      required discount,
                      paymentMethods,
                      paidAmounts,
                      required items}) async {
                    requests.add({
                      'kind': 'create',
                      'store': storeId,
                      'supplier': supplierId,
                      'items': items,
                      'paymentMethods': paymentMethods,
                      'paidAmounts': paidAmounts
                    });
                    return response is Future ? await response : response;
                  },
                  receivePurchaseOrder: (
                      {required accessToken,
                      required purchaseId,
                      required items,
                      invoiceRef,
                      required discount,
                      paymentMethods,
                      paidAmounts}) async {
                    requests.add({
                      'kind': 'receive',
                      'id': purchaseId,
                      'items': items,
                      'paymentMethods': paymentMethods,
                      'paidAmounts': paidAmounts
                    });
                    return response is Future ? await response : response;
                  },
                  listPurchaseOrders: (
                      {required accessToken,
                      storeId,
                      supplierId,
                      dateFrom,
                      dateTo,
                      page}) async {
                    refreshes++;
                  }),
              products: PurchaseFormProductsPort(
                  read: () => [],
                  filterProductByBarcode: ({required barCode}) => []),
              categories: PurchaseFormCategoryPort(() => []),
              masterData: PurchaseFormMasterDataPort(
                  read: () => [], fetchPaymentMethods: () async => []),
              stores: PurchaseFormStorePort(() => store),
              auth: PurchaseFormAuthPort(() => 'token'),
              stock: PurchaseFormStockPort((
                      {required accessToken,
                      required price,
                      required productId,
                      required categoryId,
                      required taxInclude}) async =>
                  null),
              currency: () => 'SAR',
              pickProduct: (_) => productDialog!.future,
              pickSupplier: () async => null,
              validate: () => true,
              onError: errors.add,
              onSuccess: (_) {},
              onComplete: () {
                completed++;
              },
              session: const FixedSession()));
  PurchaseOrderItem item(
          {int id = 11, bool received = false, bool receive = false}) =>
      PurchaseOrderItem(
          id: id,
          productData: GetProduct(productId: 5, productName: 'Item'),
          quantity: '2',
          purchaseRate: '10',
          retailPrice: '12',
          wholesalePrice: '11',
          mrp: '15',
          alreadyReceived: received,
          receive: receive);
  void prepare() {
    controller.selectedStore = store;
    controller.selectedSupplier = supplier;
  }
}

void main() {
  test('delayed draft restore stops before reading after disposal', () async {
    final h = Harness();
    final pending = h.controller.loadDraftFromHive();
    await h.cache.open();
    h.controller.draftBox = h.cache;
    h.cache.value = {'invoiceRef': 'must not restore'};
    h.controller.dispose();
    await pending;
    expect(h.cache.reads, 0);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  test('create preserves selected IDs and numeric item payload', () async {
    final h = Harness();
    h.prepare();
    h.controller.orderItems.add(h.item());
    await h.controller.submitPurchaseOrder();
    expect(h.errors, isEmpty);
    expect(h.requests.single['kind'], 'create');
    expect(h.requests.single['store'], '42');
    expect(h.requests.single['supplier'], '9');
    final row = (h.requests.single['items'] as List).single;
    expect(row['product_id'], 5);
    expect(row['quantity'], 2.0);
    expect(row['unit_price'], 10.0);
    expect(h.completed, 1);
    expect(h.refreshes, 1);
    h.controller.dispose();
  });
  test(
      'receive submits only selected outstanding rows and omits fully paid payment',
      () async {
    final h = Harness();
    h.prepare();
    h.controller.purchaseOrderId = 123;
    h.controller.isPaymentDisabled = true;
    h.controller.orderItems.addAll([
      h.item(received: true),
      h.item(id: 12, receive: true),
      h.item(id: 13)
    ]);
    await h.controller.submitPurchaseOrder();
    expect(h.errors, isEmpty);
    expect(h.requests.single['id'], '123');
    expect((h.requests.single['items'] as List).single['purchase_item_id'], 12);
    expect(h.requests.single['paymentMethods'], isNull);
    expect(h.requests.single['paidAmounts'], isNull);
    h.controller.dispose();
  });
  test('validation 422 retains editable payments and draft', () async {
    final h = Harness();
    h.prepare();
    h.controller.orderItems.add(h.item());
    h.response = {
      'http_status_code': 422,
      'errors': {
        'quantity': ['Invalid quantity']
      }
    };
    await h.controller.submitPurchaseOrder();
    expect(h.errors, ['Invalid quantity']);
    expect(h.controller.isPaymentDisabled, isFalse);
    expect(h.completed, 0);
    expect(h.cache.clears, 0);
    h.controller.dispose();
  });
  test('late product dialog cannot write to disposed controllers', () async {
    final h = Harness();
    h.productDialog = Completer();
    final pending = h.controller.performBarcodeAutoFill('new-barcode');
    h.controller.dispose();
    h.productDialog!.complete({'product': GetProduct(productId: 99)});
    await pending;
    expect(h.requests, isEmpty);
  });
  test('leaving during submission does not navigate or clear a later draft',
      () async {
    final h = Harness();
    h.prepare();
    h.controller.orderItems.add(h.item());
    final response = Completer<Map<String, dynamic>>();
    h.response = response.future;
    final pending = h.controller.submitPurchaseOrder();
    h.controller.dispose();
    response.complete({'status': 'success'});
    await pending;
    expect(h.completed, 0);
    expect(h.refreshes, 0);
    expect(h.cache.clears, 0);
  });
  test('draft round trip restores IDs and edited quantity', () async {
    final h = Harness();
    h.prepare();
    await h.controller.initDraftBox();
    h.controller.orderItems.add(h.item());
    h.controller.invoiceRefController.text = 'REF';
    h.controller.saveDraftToHive();
    await Future<void>.delayed(const Duration(milliseconds: 550));
    expect(h.cache.value, isNotNull);
    h.controller.orderItems.clear();
    h.controller.invoiceRefController.clear();
    await h.controller.loadDraftFromHive();
    expect(h.controller.selectedSupplier!.id, 9);
    expect(h.controller.selectedStore!.id, 42);
    expect(h.controller.invoiceRefController.text, 'REF');
    expect(h.controller.orderItems.single.quantity, '2');
    h.controller.dispose();
  });
}
