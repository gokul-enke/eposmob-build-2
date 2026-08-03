import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:pos_machine/screens/sales_return/widgets/sales_return_detail_modal.dart';

void main() {
  test('loaded sales-return item keeps an endpoint reason', () {
    final loadedItem = SalesReturnCart.fromJson({
      'cart_item_id': 40,
      'product_name': 'Kitkat',
      'quantity': 1,
      'returned_quantity': 1,
      'is_returned': true,
      'reason': 'Expired',
    });

    expect(loadedItem.reason, 'Expired');
    expect(resolveSalesReturnItemReason(loadedItem, const []), 'Expired');
  });

  test('loaded sales-return item falls back to the summary reason', () {
    final order = SalesReturnOrder.fromJson({
      'id': 10,
      'order_id': 20,
      'total_amount': '2.00',
      'user_id': 1,
      'status': 1,
      'items': [
        {
          'id': 30,
          'order_return_id': 10,
          'cart_item_id': 40,
          'price': '2.00',
          'reason': 'Damaged package',
          'quantity': 1,
          'cart_item': {
            'id': 40,
            'product_name': 'Kitkat',
          },
        },
      ],
    });
    final loadedItem = SalesReturnCart.fromJson({
      'cart_item_id': 40,
      'product_name': 'Kitkat',
      'quantity': 1,
      'returned_quantity': 1,
      'is_returned': true,
    });

    expect(
      resolveSalesReturnItemReason(loadedItem, order.items),
      'Damaged package',
    );
  });
}
