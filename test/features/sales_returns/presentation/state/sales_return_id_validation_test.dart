import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/providers/sales_provider.dart';

void main() {
  group('Sales return ID validation', () {
    test('does not submit a return with an invalid sales order ID', () async {
      final provider = SalesProvider();

      await expectLater(
        provider.submitSalesReturn(
          accessToken: 'token',
          orderId: 0,
          price: 10,
          quantity: 1,
          cartItemId: 20,
          reason: 'Damaged',
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains('sales order ID is missing'),
          ),
        ),
      );
    });

    test('does not submit a return with an invalid cart item ID', () async {
      final provider = SalesProvider();

      await expectLater(
        provider.submitSalesReturn(
          accessToken: 'token',
          orderId: 10,
          price: 10,
          quantity: 1,
          cartItemId: 0,
          reason: 'Damaged',
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains('cart item ID is missing'),
          ),
        ),
      );
    });

    test('does not complete a return with an invalid return order ID',
        () async {
      final provider = SalesProvider();

      await expectLater(
        provider.completeSalesReturn(
          accessToken: 'token',
          returnOrderId: 0,
        ),
        throwsA(
          predicate(
            (error) => error.toString().contains('return order ID is missing'),
          ),
        ),
      );
    });
  });
}
