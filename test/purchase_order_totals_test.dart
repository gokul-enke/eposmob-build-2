import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/screens/purchase/helpers/purchase_order_totals.dart';

void main() {
  group('PurchaseOrderTotals', () {
    test('calculates net payable after a valid flat discount', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 50,
      );

      expect(totals.netPayable, 450);
      expect(totals.discountValidationMessage, isNull);
    });

    test('allows discount equal to gross total', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 500,
      );

      expect(totals.netPayable, 0);
      expect(totals.discountValidationMessage, isNull);
    });

    test('rejects discount greater than gross total', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 500.01,
      );

      expect(totals.netPayable, 0);
      expect(
        totals.discountValidationMessage,
        'Overall discount cannot exceed the gross total.',
      );
    });

    test('rejects a negative discount', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: -1,
      );

      expect(
        totals.discountValidationMessage,
        'Overall discount cannot be negative.',
      );
    });

    test('accepts partial and exact payments', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 50,
      );

      expect(totals.validatePaymentAmount(200), isNull);
      expect(totals.validatePaymentAmount(450), isNull);
    });

    test('rejects payment greater than net payable', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 50,
      );

      expect(
        totals.validatePaymentAmount(450.01),
        'Payment amount cannot exceed the net payable.',
      );
    });
  });

  group('parsePurchaseAmount', () {
    test('parses trimmed decimal values', () {
      expect(parsePurchaseAmount(' 50.25 '), 50.25);
    });

    test('returns zero for empty and invalid values', () {
      expect(parsePurchaseAmount(''), 0);
      expect(parsePurchaseAmount('not-a-number'), 0);
    });
  });
}
