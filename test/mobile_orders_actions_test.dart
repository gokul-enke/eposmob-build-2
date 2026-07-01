import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';

void main() {
  group('BillingMobileController saved order actions', () {
    test('CreateOrderAndPrintResult distinguishes print failure', () {
      const result = CreateOrderAndPrintResult(
        orderCreated: true,
        orderNumber: 'ORD-99',
        printSucceeded: false,
      );
      expect(result.printFailed, isTrue);
      expect(result.orderCreated, isTrue);
    });
  });
}
