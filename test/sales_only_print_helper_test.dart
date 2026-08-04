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
}
