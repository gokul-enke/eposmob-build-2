import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/payment_auto_fill_helper.dart';

void main() {
  group('PaymentAutoFillHelper.autoFillSingleMethod', () {
    test('subtracts extra method amounts when filling a typed method', () {
      final amount = PaymentAutoFillHelper.autoFillSingleMethod(
        paymentType: 'card',
        currentTargetAmount: '',
        cashAmount: '105',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        cartTotal: 105,
        extraAmounts: const {},
      );

      expect(amount, '');
    });

    test('fills remaining after another extra method already holds part of total',
        () {
      final amount = PaymentAutoFillHelper.autoFillSingleMethod(
        paymentType: 'card',
        currentTargetAmount: '',
        cashAmount: '',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        cartTotal: 105,
        extraAmounts: const {'8010': '50'},
      );

      expect(amount, '55.00');
    });

    test('autoFillRemaining supports split between typed and extra methods', () {
      final amount = PaymentAutoFillHelper.autoFillRemaining(
        targetMethodKey: 'extra_8010',
        targetCurrentAmount: '',
        collectedAmounts: const {
          'cash': '50',
          'extra_8010': '',
        },
        cartTotal: 105,
      );

      expect(amount, '55.00');
    });

    test('autoFillRemaining refills nothing when balance already covered', () {
      final amount = PaymentAutoFillHelper.autoFillRemaining(
        targetMethodKey: 'card',
        targetCurrentAmount: '',
        collectedAmounts: const {'cash': '105'},
        cartTotal: 105,
      );

      expect(amount, '');
    });
  });

  group('PaymentAutoFillHelper.remapAmountsAfterDiscount', () {
    test('remaps a single full cash payment to the new payable total', () {
      final result = PaymentAutoFillHelper.remapAmountsAfterDiscount(
        isCashSelected: true,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '100.00',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        oldEffectiveTotal: 100,
        newEffectiveTotal: 80,
      );

      expect(result.cash, '80.00');
      expect(result.card, '');
      expect(result.upi, '');
      expect(result.cod, '');
    });

    test('preserves manually split typed payments', () {
      final result = PaymentAutoFillHelper.remapAmountsAfterDiscount(
        isCashSelected: true,
        isCardSelected: true,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '50',
        cardAmount: '55',
        upiAmount: '',
        codAmount: '',
        oldEffectiveTotal: 105,
        newEffectiveTotal: 95,
      );

      expect(result.cash, '50');
      expect(result.card, '55');
    });

    test('does not remap when debit is the only visible selection', () {
      final result = PaymentAutoFillHelper.remapAmountsAfterDiscount(
        isCashSelected: false,
        isCardSelected: false,
        isUpiSelected: false,
        isCodSelected: false,
        cashAmount: '',
        cardAmount: '',
        upiAmount: '',
        codAmount: '',
        oldEffectiveTotal: 100,
        newEffectiveTotal: 80,
      );

      expect(result.cash, '');
      expect(result.card, '');
      expect(result.upi, '');
      expect(result.cod, '');
    });
  });

  group('PaymentAutoFillHelper.remapSingleExtraAfterDiscount', () {
    test('remaps one selected extra method that covered the old payable', () {
      final result = PaymentAutoFillHelper.remapSingleExtraAfterDiscount(
        anyTypedMethodSelected: false,
        selectedExtraMethodIds: const {'99'},
        extraAmounts: const {'99': '200.00'},
        oldEffectiveTotal: 200,
        newEffectiveTotal: 150,
      );

      expect(result, {'99': '150.00'});
    });

    test('skips remap when typed methods are also selected', () {
      final result = PaymentAutoFillHelper.remapSingleExtraAfterDiscount(
        anyTypedMethodSelected: true,
        selectedExtraMethodIds: const {'99'},
        extraAmounts: const {'99': '200.00'},
        oldEffectiveTotal: 200,
        newEffectiveTotal: 150,
      );

      expect(result, isNull);
    });
  });
}
