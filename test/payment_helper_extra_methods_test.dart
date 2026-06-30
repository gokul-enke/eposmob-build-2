/// Tests for dynamic/extra payment methods (anything beyond CASH/CARD/UPI/COD,
/// e.g. BANK, Cheque, Online Payment) flowing through the payment pipeline.
///
/// The billing page appends extra methods to the paidMethods list *after* the
/// typed four, then hands the list to [PaymentHelper.normalizePaidMethodsForApi]
/// before posting. These tests pin two invariants that the dynamic-methods
/// feature relies on:
///   1. Extra methods are passed through to the API untouched.
///   2. Customer change/balance is still deducted only from the cash/COD leg —
///      never from an extra method — even when extras are present.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/payment_helper.dart';

void main() {
  group('PaymentHelper.normalizePaidMethodsForApi — extra methods', () {
    test('passes typed + extra methods through when there is no balance', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'CASH', 'amount': 50},
          {'method': '15', 'amount': 30}, // BANK (extra)
          {'method': '16', 'amount': 18}, // Cheque (extra)
        ],
        balanceAmount: 0,
      );
      expect(result, [
        {'method': 'CASH', 'amount': 50.0},
        {'method': '15', 'amount': 30.0},
        {'method': '16', 'amount': 18.0},
      ]);
    });

    test('deducts balance from CASH leg, leaves extra methods untouched', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'CASH', 'amount': 100},
          {'method': '15', 'amount': 40}, // BANK (extra)
        ],
        balanceAmount: 25,
      );
      expect(result, [
        {'method': 'CASH', 'amount': 75.0},
        {'method': '15', 'amount': 40.0},
      ]);
    });

    test(
        'extra-only payment: balance is NOT deducted from an extra method', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': '15', 'amount': 100}, // BANK (extra), no cash/COD leg
        ],
        balanceAmount: 20,
      );
      expect(result, [
        {'method': '15', 'amount': 100.0},
      ]);
    });

    test('balance hits configured numeric cashMethodId, not the extra', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': '7974', 'amount': 100}, // CASH by configured id
          {'method': '15', 'amount': 50}, // BANK (extra)
        ],
        balanceAmount: 30,
        cashMethodId: '7974',
      );
      expect(result, [
        {'method': '7974', 'amount': 70.0},
        {'method': '15', 'amount': 50.0},
      ]);
    });

    test('parses string amounts on extra methods', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': '17', 'amount': '45.50'}, // Online Payment (extra)
        ],
        balanceAmount: 0,
      );
      expect(result.single['amount'], 45.5);
    });

    test('drops extra methods with zero amount', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'CASH', 'amount': 100},
          {'method': '15', 'amount': 0}, // unselected extra
        ],
        balanceAmount: 0,
      );
      expect(result, [
        {'method': 'CASH', 'amount': 100.0},
      ]);
    });
  });
}
