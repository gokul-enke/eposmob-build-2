import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/sales_returns/domain/models/list_sales_return_items.dart';
import 'package:pos_machine/features/sales_returns/presentation/state/sales_return_details_controller.dart';
import 'package:pos_machine/features/sales_returns/presentation/state/sales_return_item_dialog_controller.dart';
import '../../support/return_fixtures.dart';

void main() {
  test('details ignores old order, retries and does not fetch absent order',
      () async {
    final pending = <Completer<SalesReturnItemsResponse>>[];
    final controller = SalesReturnDetailsController(fetch: (_) {
      final result = Completer<SalesReturnItemsResponse>();
      pending.add(result);
      return result.future;
    });
    await controller.load(null);
    expect(pending, isEmpty);
    final old = controller.load('old');
    final latest = controller.load('new');
    pending[1].complete(returnItems(id: 50));
    await latest;
    pending[0].complete(returnItems());
    await old;
    expect(controller.items.single.cartItemId, 50);
    final last = controller.load('last');
    controller.dispose();
    pending[2].completeError(Exception('late'));
    await last;
  });
  test(
      'dialog field synchronization and decimal unit behavior survive extraction',
      () {
    final controller = SalesReturnItemDialogController(
        quantity: '2', unitPrice: '10', productUnit: 'KG', returnedQuantity: 1);
    expect(controller.allowsDecimals, isTrue);
    expect(controller.maxQuantity, 1);
    controller.quantityController.text = '0.5';
    expect(controller.returnTotalController.text, '5.00');
    controller.returnTotalController.text = '7.50';
    expect(controller.quantityController.text, '0.750');
    controller.dispose();
  });
}
