import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/cart_provider.dart';

void main() {
  test('list-cart URI preserves customer, cart, and store context', () {
    final uri = buildListCartUri(
      customerId: 42,
      cartId: 9,
      storeId: 3,
    );

    expect(uri.queryParameters['customer_id'], '42');
    expect(uri.queryParameters['cart_id'], '9');
    expect(uri.queryParameters['store_id'], '3');
  });
}
