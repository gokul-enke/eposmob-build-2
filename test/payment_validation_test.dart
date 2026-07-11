import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/payment_validation.dart';

void main() {
  group('PaymentValidation', () {
    test('hasCollectedPayment requires positive amount, not just selection',
        () {
      expect(
        PaymentValidation.hasCollectedPayment(
          isCashSelected: true,
          isCardSelected: false,
          isUpiSelected: false,
          isCodSelected: false,
          cashAmount: '0',
          cardAmount: '',
          upiAmount: '',
          codAmount: '',
        ),
        isFalse,
      );

      expect(
        PaymentValidation.hasCollectedPayment(
          isCashSelected: true,
          isCardSelected: false,
          isUpiSelected: false,
          isCodSelected: false,
          cashAmount: '100',
          cardAmount: '',
          upiAmount: '',
          codAmount: '',
        ),
        isTrue,
      );
    });

    test('hasCollectedPayment includes extra methods', () {
      expect(
        PaymentValidation.hasCollectedPayment(
          isCashSelected: false,
          isCardSelected: false,
          isUpiSelected: false,
          isCodSelected: false,
          cashAmount: '',
          cardAmount: '',
          upiAmount: '',
          codAmount: '',
          extraAmounts: {'8010': '250.00'},
        ),
        isTrue,
      );
    });

    test(
        'computeNetDue subtracts positive customer balance when credit toggle on',
        () {
      expect(
        PaymentValidation.computeNetDue(
          orderTotal: 500,
          toCustomerCreditEnabled: true,
          isDefaultCustomer: false,
          customerPrevBalance: 200,
        ),
        300,
      );
    });

    test('validateForOrder rejects insufficient payment', () {
      final result = PaymentValidation.validateForOrder(
        orderTotal: 500,
        toCustomerCreditEnabled: false,
        isDefaultCustomer: true,
        customerPrevBalance: 0,
        isCashSelected: true,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '100',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
      );

      expect(result.isValid, isFalse);
      expect(result.message, contains('less than'));
    });

    test('validateForOrder accepts full cash payment', () {
      final result = PaymentValidation.validateForOrder(
        orderTotal: 500,
        toCustomerCreditEnabled: false,
        isDefaultCustomer: true,
        customerPrevBalance: 0,
        isCashSelected: true,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '500',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
      );

      expect(result.isValid, isTrue);
    });

    test('accepts partial cash with the remainder as customer credit sale', () {
      final result = PaymentValidation.validateForOrder(
        orderTotal: 500,
        toCustomerCreditEnabled: false,
        isDefaultCustomer: false,
        customerPrevBalance: 0,
        isCashSelected: true,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '200',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        isCreditSelected: true,
        creditAmount: '300',
      );

      expect(result.isValid, isTrue);
    });

    test('accepts a credit-only sale for a selected customer', () {
      final result = PaymentValidation.validateForOrder(
        orderTotal: 500,
        toCustomerCreditEnabled: false,
        isDefaultCustomer: false,
        customerPrevBalance: 0,
        isCashSelected: false,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        isCreditSelected: true,
        creditAmount: '500',
      );

      expect(result.isValid, isTrue);
    });

    test('rejects a credit sale for the default customer', () {
      final result = PaymentValidation.validateForOrder(
        orderTotal: 500,
        toCustomerCreditEnabled: false,
        isDefaultCustomer: true,
        customerPrevBalance: 0,
        isCashSelected: false,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        isCreditSelected: true,
        creditAmount: '500',
      );

      expect(result.isValid, isFalse);
      expect(result.message, contains('selected customer'));
    });

    test('does not treat excess allocated to customer credit as payment', () {
      final result = PaymentValidation.validateForOrder(
        orderTotal: 500,
        toCustomerCreditEnabled: true,
        isDefaultCustomer: false,
        customerPrevBalance: 0,
        isCashSelected: true,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '200',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        isCreditSelected: false,
        creditAmount: '300',
      );

      expect(result.isValid, isFalse);
      expect(result.message, contains('less than'));
    });

    test('isCheckoutPaymentComplete allows payment step autofill', () {
      expect(
        PaymentValidation.isCheckoutPaymentComplete(
          paymentStepVisited: false,
          onPaymentStep: true,
          orderTotal: 105,
          toCustomerCreditEnabled: false,
          isDefaultCustomer: true,
          customerPrevBalance: 0,
          isCashSelected: true,
          isCardSelected: false,
          isUpiSelected: false,
          isCodSelected: false,
          cashAmount: '105',
          cardAmount: '',
          upiAmount: '',
          codAmount: '',
        ),
        isTrue,
      );
    });

    test('isCheckoutPaymentComplete blocks unvisited invalid payment', () {
      expect(
        PaymentValidation.isCheckoutPaymentComplete(
          paymentStepVisited: false,
          onPaymentStep: false,
          orderTotal: 105,
          toCustomerCreditEnabled: false,
          isDefaultCustomer: true,
          customerPrevBalance: 0,
          isCashSelected: true,
          isCardSelected: false,
          isUpiSelected: false,
          isCodSelected: false,
          cashAmount: '',
          cardAmount: '',
          upiAmount: '',
          codAmount: '',
        ),
        isFalse,
      );
    });
  });
}
