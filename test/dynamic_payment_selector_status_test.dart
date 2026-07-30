import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/components/build_dynamic_payment_selector.dart';

void main() {
  test('accepts cent-rounded payment as exact', () {
    expect(
      dynamicPaymentAmountStatus(
        total: 99.999,
        expectedAmount: 100,
        allowPartialPayment: true,
      ),
      DynamicPaymentAmountStatus.exact,
    );
  });

  test('shows an allowed partial payment as partial', () {
    expect(
      dynamicPaymentAmountStatus(
        total: 60,
        expectedAmount: 100,
        allowPartialPayment: true,
      ),
      DynamicPaymentAmountStatus.partial,
    );
  });

  test('shows an overpayment as overpaid', () {
    expect(
      dynamicPaymentAmountStatus(
        total: 100.01,
        expectedAmount: 100,
        allowPartialPayment: true,
      ),
      DynamicPaymentAmountStatus.overpaid,
    );
  });

  test('shows a disallowed partial payment as underpaid', () {
    expect(
      dynamicPaymentAmountStatus(
        total: 60,
        expectedAmount: 100,
        allowPartialPayment: false,
      ),
      DynamicPaymentAmountStatus.underpaid,
    );
  });
}
