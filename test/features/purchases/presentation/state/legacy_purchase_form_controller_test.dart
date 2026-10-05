import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchases/domain/models/list_purchase.dart';
import 'package:pos_machine/features/purchases/presentation/state/legacy_purchase_form_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  test(
      'add, reload, remove and finish preserve command IDs and close busy state',
      () async {
    final calls = <String>[];
    final busy = <bool>[];
    final messages = <String>[];
    var back = 0;
    final items = [PurchaseItem(id: 4, purchaseId: 22)];
    final c = LegacyPurchaseFormController(
        readStores: () => [],
        readSuppliers: () => [],
        readItems: () => items,
        fetchItems: () async {
          calls.add('fetch');
        },
        addItem: (
            {required categoryId,
            required productId,
            required quantity,
            required unit,
            required supplierId,
            required storeId,
            required batchNumber}) async {
          calls.add(
              '$categoryId/$productId/$quantity/$unit/$supplierId/$storeId/$batchNumber');
          return {'status': 'success', 'message': 'added'};
        },
        removeItem: (id) async {
          calls.add('remove:$id');
          return {'status': 'success', 'message': 'removed'};
        },
        finishPurchase: (id) async {
          calls.add('finish:$id');
          return {'status': 'success', 'message': 'finished'};
        },
        onMessage: messages.add,
        onBusy: busy.add,
        onBack: () {
          back++;
        });
    await c.loadData();
    c.selectedValue = GetProduct.fromJson({'id': 9});
    c.selectedValueCategory = Category(categoryId: 2);
    c.categoryIDController.text = '2';
    c.productIDController.text = '9';
    c.quantity = 3;
    c.selectedProperty = 'PC';
    c.supplierIdController.text = '7';
    c.storeController.text = '5';
    c.batchNumber = 6;
    await c.submitItem();
    await c.deleteItem('4');
    await c.finish();
    expect(calls,
        ['fetch', '2/9/3/PC/7/5/6', 'fetch', 'remove:4', 'fetch', 'finish:22']);
    expect(busy, [true, false, true, false, true, false]);
    expect(messages, ['added', 'removed', 'finished']);
    expect(back, 1);
    expect(c.commandBusy, false);
    c.dispose();
  });
  test('duplicate command is ignored and disposal suppresses late UI callbacks',
      () async {
    final response = Completer<dynamic>();
    var calls = 0;
    final events = <String>[];
    final c = LegacyPurchaseFormController(
        readStores: () => [],
        readSuppliers: () => [],
        readItems: () => [],
        fetchItems: () async {
          events.add('fetch');
        },
        addItem: (
                {required categoryId,
                required productId,
                required quantity,
                required unit,
                required supplierId,
                required storeId,
                required batchNumber}) async =>
            {},
        removeItem: (id) {
          calls++;
          return response.future;
        },
        finishPurchase: (id) async => {},
        onMessage: events.add,
        onBusy: (b) => events.add('$b'),
        onBack: () => events.add('back'));
    final pending = c.deleteItem('4');
    await c.deleteItem('4');
    expect(calls, 1);
    c.dispose();
    response.complete({'status': 'success', 'message': 'deleted'});
    await pending;
    expect(events, ['true']);
  });
  test('failed command releases progress and a retry succeeds', () async {
    var attempts = 0;
    final busy = <bool>[];
    final messages = <String>[];
    final c = LegacyPurchaseFormController(
        readStores: () => [],
        readSuppliers: () => [],
        readItems: () => [],
        fetchItems: () async {},
        addItem: (
                {required categoryId,
                required productId,
                required quantity,
                required unit,
                required supplierId,
                required storeId,
                required batchNumber}) async =>
            {},
        removeItem: (id) async {
          if (attempts++ == 0) throw StateError('offline');
          return {'status': 'success', 'message': 'removed'};
        },
        finishPurchase: (id) async => {},
        onMessage: messages.add,
        onBusy: busy.add,
        onBack: () {});
    await c.deleteItem('4');
    await c.deleteItem('4');
    expect(busy, [true, false, true, false]);
    expect(messages.last, 'removed');
    expect(c.commandBusy, false);
    c.dispose();
  });
}
