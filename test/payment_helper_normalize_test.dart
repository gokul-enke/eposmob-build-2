/// Phase-0 characterization tests for [PaymentHelper.normalizePaidMethodsForApi].
///
/// This is the one piece of the payment pipeline that is pure (no BuildContext /
/// Provider), so it can be pinned directly. It governs how customer change /
/// balance is deducted from the cash/COD leg of a multi-payment order before the
/// payload is sent to the API. The responsive refactor must not alter this math.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/payment_helper.dart';

void main() {
  group('PaymentHelper.normalizePaidMethodsForApi', () {
    test('with no balance, cleans and passes methods through', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'CASH', 'amount': 100},
        ],
        balanceAmount: 0,
      );
      expect(result, [
        {'method': 'CASH', 'amount': 100.0},
      ]);
    });

    test('drops empty-method and non-positive-amount entries', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': '', 'amount': 50},
          {'method': 'CARD', 'amount': 0},
          {'method': 'CASH', 'amount': 100},
        ],
        balanceAmount: 0,
      );
      expect(result, [
        {'method': 'CASH', 'amount': 100.0},
      ]);
    });

    test('parses string amounts to doubles', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'CASH', 'amount': '100'},
        ],
        balanceAmount: 0,
      );
      expect(result.single['amount'], 100.0);
    });

    test('deducts balance from the CASH leg, leaves others intact', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'CASH', 'amount': 100},
          {'method': 'CARD', 'amount': 50},
        ],
        balanceAmount: 20,
      );
      expect(result, [
        {'method': 'CASH', 'amount': 80.0},
        {'method': 'CARD', 'amount': 50.0},
      ]);
    });

    test('deducts balance from a COD leg', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'COD', 'amount': 100},
        ],
        balanceAmount: 40,
      );
      expect(result, [
        {'method': 'COD', 'amount': 60.0},
      ]);
    });

    test('clamps deduction at zero and removes a fully-consumed cash leg', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'CASH', 'amount': 20},
        ],
        balanceAmount: 50,
      );
      expect(result, isEmpty);
    });

    test('matches the configured numeric cashMethodId', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': '7974', 'amount': 100},
        ],
        balanceAmount: 30,
        cashMethodId: '7974',
      );
      expect(result, [
        {'method': '7974', 'amount': 70.0},
      ]);
    });

    test('no cash/COD leg → balance is not deducted from card-only payment', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [
          {'method': 'CARD', 'amount': 100},
        ],
        balanceAmount: 20,
      );
      expect(result, [
        {'method': 'CARD', 'amount': 100.0},
      ]);
    });

    test('empty input returns empty', () {
      final result = PaymentHelper.normalizePaidMethodsForApi(
        paidMethods: [],
        balanceAmount: 25,
      );
      expect(result, isEmpty);
    });
  });
}
