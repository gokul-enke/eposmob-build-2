import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/services/sales_only_print_helper.dart';

void main() {
  OrderDetailsModelDataCartItem cartItem({
    required String name,
    required num quantity,
    String unitPrice = '10.00',
    String totalPrice = '10.00',
    String taxAmount = '1.50',
  }) {
    return OrderDetailsModelDataCartItem(
      productName: name,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      taxAmount: taxAmount,
    );
  }

  test('subtracts returned quantity and recalculates line totals', () {
    final result = buildSalesOnlyCartItems(
      <OrderDetailsModelDataCartItem>[
        cartItem(
          name: 'Product A',
          quantity: 3,
          totalPrice: '30.00',
          taxAmount: '4.50',
        ),
      ],
      <OrderReturnItem>[
        OrderReturnItem(productName: 'Product A', quantity: 1),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.quantity, 2);
    expect(result.single.totalPrice, '20.00');
    expect(result.single.taxAmount, '3.00');
  });

  test('returns an empty cart when every sold quantity was returned', () {
    final result = buildSalesOnlyCartItems(
      <OrderDetailsModelDataCartItem>[
        cartItem(name: 'Product A', quantity: 1),
      ],
      <OrderReturnItem>[
        OrderReturnItem(productName: 'Product A', quantity: 1),
      ],
    );

    expect(result, isEmpty);
  });

  test('applies a returned quantity only once across duplicate item rows', () {
    final result = buildSalesOnlyCartItems(
      <OrderDetailsModelDataCartItem>[
        cartItem(name: 'Product A', quantity: 1),
        cartItem(name: 'Product A', quantity: 1),
      ],
      <OrderReturnItem>[
        OrderReturnItem(productName: 'Product A', quantity: 1),
      ],
    );

    expect(result, hasLength(1));
    expect(result.single.quantity, 1);
  });

  test('preserves fractional returned quantities', () {
    final result = buildSalesOnlyCartItems(
      <OrderDetailsModelDataCartItem>[
        cartItem(
          name: 'Flour',
          quantity: 2,
          unitPrice: '10.00',
          totalPrice: '20.00',
          taxAmount: '3.00',
        ),
      ],
      <OrderReturnItem>[
        OrderReturnItem(productName: 'Flour', quantity: 0.5),
      ],
    );

    expect(result.single.quantity, 1.5);
    expect(result.single.totalPrice, '15.00');
    expect(result.single.taxAmount, '2.25');
  });

  test('deducts an identified return from its own duplicate-name cart line', () {
    final result = buildSalesOnlyCartItems([
      OrderDetailsModelDataCartItem(id: 10, productName: 'Same product',
          quantity: 2, unitPrice: '5', totalPrice: '10', taxAmount: '1'),
      OrderDetailsModelDataCartItem(id: 20, productName: 'Same product',
          quantity: 3, unitPrice: '20', totalPrice: '60', taxAmount: '6'),
    ], [OrderReturnItem(cartItemId: 20, productName: 'Same product', quantity: 1)]);
    expect(result.map((item) => item.quantity), [2, 2]);
    expect(result.map((item) => item.totalPrice), ['10.00', '40.00']);
    expect(result.map((item) => item.taxAmount), ['1.00', '4.00']);
  });

  test('completed snapshot survives model roundtrip and deducts the specified cart line', () {
    final data = OrderDetailsModelData.fromJson({
      'return_state': {'has_completed_return': true, 'has_draft_return': false,
        'items': [{'cart_item_id': '30', 'returned_quantity': '2'}]},
    });
    final restored = OrderDetailsModelData.fromJson(data.toJson());
    final cart = [
      for (final row in [(10, 1, '180', '27.46'), (20, 2, '360', '54.92'), (30, 7, '1260', '192.20')])
        OrderDetailsModelDataCartItem(id: row.$1, productName: 'Same product',
            quantity: row.$2, unitPrice: '180', totalPrice: row.$3, taxAmount: row.$4),
    ];
    final summary = [OrderReturnItem(productName: 'Same product', quantity: 2)];
    final result = buildSalesOnlyCartItems(cart, summary,
        completedReturnCartItems: restored.completedReturnCartItems);
    expect(result.map((item) => item.id), [10, 20, 30]);
    expect(result.map((item) => item.quantity), [1, 2, 5]);
    expect(result.map((item) => item.totalPrice), ['180.00', '360.00', '900.00']);
    expect(result.map((item) => item.taxAmount), ['27.46', '54.92', '137.29']);
    for (final snapshot in [
      [OrderReturnItem(cartItemId: 30, quantity: 3)],
      [OrderReturnItem(cartItemId: 999, quantity: 2)],
      [OrderReturnItem(cartItemId: 10, quantity: 2)],
      [OrderReturnItem(cartItemId: 30, quantity: 1), OrderReturnItem(cartItemId: 30, quantity: 1)],
    ]) {
      final fallback = buildSalesOnlyCartItems(cart, summary,
          completedReturnCartItems: snapshot);
      expect(fallback.map((item) => item.quantity), [1, 7],
          reason: 'Unreconciled snapshots cannot replace the available return record');
    }
  });

  test('draft, missing and invalid return snapshots are not used for sales subtraction', () {
    for (final state in [
      null,
      {'has_completed_return': false, 'has_draft_return': true, 'items': []},
      {'has_completed_return': true, 'has_draft_return': true,
        'items': [{'cart_item_id': 10, 'returned_quantity': 2}]},
      {'has_completed_return': true, 'items': [{'cart_item_id': 10, 'returned_quantity': 'NaN'}]},
      {'has_completed_return': true, 'items': [{'cart_item_id': 0, 'returned_quantity': 2}]},
    ]) {
      expect(OrderDetailsModelData.fromJson({'return_state': state}).completedReturnCartItems, isNull);
    }
  });

  test('variant returns stay on the matching variant and unknown cart IDs do not fall back to names', () {
    final cart = [
      for (final variant in [1, 2])
        OrderDetailsModelDataCartItem(id: variant, productVariantId: variant,
            productName: 'Coffee', quantity: 2, unitPrice: '10', totalPrice: '20', taxAmount: '2'),
    ];
    final result = buildSalesOnlyCartItems(cart,
        [OrderReturnItem(productName: 'Coffee', productVariantId: 2, quantity: 0.5)]);
    expect(result.map((item) => item.quantity), [2, 1.5]);
    final unknown = buildSalesOnlyCartItems(cart,
        [OrderReturnItem(cartItemId: 999, productName: 'Coffee', quantity: 1)]);
    expect(unknown.map((item) => item.quantity), [2, 2]);
  });
}
