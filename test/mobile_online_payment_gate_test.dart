import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/providers/billing_provider.dart';

void main() {
  group('BillingMobilePaymentController.validatePaymentReadyForConfirm', () {
    const controller = BillingMobilePaymentController();

    test('blocks ONLINE without terminal success', () {
      final bp = BillingProvider();
      bp.setPaymentMethod('ONLINE', true);
      bp.setPineLabsPaymentSuccess(false);

      final result = controller.validatePaymentReadyForConfirm(bp);
      expect(result.isValid, isFalse);
      expect(result.message, contains('Pine Labs'));
    });

    test('blocks ONLINE without transaction reference', () {
      final bp = BillingProvider();
      bp.setPaymentMethod('ONLINE', true);
      bp.setPineLabsPaymentSuccess(true);
      bp.transactionNumberController.clear();

      final result = controller.validatePaymentReadyForConfirm(bp);
      expect(result.isValid, isFalse);
      expect(result.message, contains('reference'));
    });

    test('allows ONLINE when terminal succeeded with reference', () {
      final bp = BillingProvider();
      bp.setTotalOrderAmount(100);
      bp.setPaymentMethod('ONLINE', true);
      bp.setPineLabsPaymentSuccess(true);
      bp.transactionNumberController.text = 'TXN-123';
      bp.markPaymentStepVisited();

      final result = controller.validatePaymentReadyForConfirm(bp);
      expect(result.isValid, isTrue);
    });
  });

  group('CreateOrderAndPrintResult', () {
    test('printFailed is true when order created but print failed', () {
      const result = CreateOrderAndPrintResult(
        orderCreated: true,
        orderNumber: 'ORD-1',
        printSucceeded: false,
      );
      expect(result.printFailed, isTrue);
    });
  });
}
