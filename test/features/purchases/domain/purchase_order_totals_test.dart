import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchases/domain/purchase_order_totals.dart';

void main() {
  group('PurchaseOrderTotals', () {
    test('calculates net payable after a valid flat discount', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 50,
      );

      expect(totals.netPayable, 450);
      expect(totals.discountErrorKey, isNull);
    });

    test('allows discount equal to gross total', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 500,
      );

      expect(totals.netPayable, 0);
      expect(totals.discountErrorKey, isNull);
    });

    test('rejects discount greater than gross total', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 500.01,
      );

      expect(totals.netPayable, 0);
      expect(
        totals.discountErrorKey,
        'purchase_order.discount_exceeds_gross',
      );
    });

    test('rejects a negative discount', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: -1,
      );

      expect(
        totals.discountErrorKey,
        'purchase_order.discount_negative',
      );
    });

    test('accepts partial and exact payments', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 50,
      );

      expect(totals.paymentErrorKey(200), isNull);
      expect(totals.paymentErrorKey(450), isNull);
    });

    test('rejects payment greater than net payable', () {
      const totals = PurchaseOrderTotals(
        grossAmount: 500,
        discountAmount: 50,
      );

      expect(
        totals.paymentErrorKey(450.01),
        'purchase_order.payment_exceeds_net',
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

  group('resolveEffectivePurchaseRate', () {
    test('uses entered rate when purchase price includes tax', () {
      expect(
        resolveEffectivePurchaseRate(
          enteredRate: 100,
          taxIncludePurchase: true,
          calculatedPurchaseRate: 118,
        ),
        100,
      );
    });

    test('uses backend-calculated rate when purchase price excludes tax', () {
      expect(
        resolveEffectivePurchaseRate(
          enteredRate: 100,
          taxIncludePurchase: false,
          calculatedPurchaseRate: 118,
        ),
        118,
      );
    });

    test('falls back to entered rate without a valid calculated rate', () {
      expect(
        resolveEffectivePurchaseRate(
          enteredRate: 100,
          taxIncludePurchase: false,
        ),
        100,
      );
      expect(
        resolveEffectivePurchaseRate(
          enteredRate: 100,
          taxIncludePurchase: false,
          calculatedPurchaseRate: 0,
        ),
        100,
      );
    });
  });

  group('partiallyReceivedPurchaseGross', () {
    test('sums only received lines when some lines are received', () {
      final gross = partiallyReceivedPurchaseGross([
        {'status': 'Y', 'quantity': '1', 'unit_price': '2', 'total_price': '2'},
        {'status': 'N', 'quantity': '1', 'unit_price': '3', 'total_price': '3'},
        {'status': 'pending', 'quantity': '1', 'unit_price': '16'},
      ]);

      expect(gross, 2);
    });

    test('falls back to quantity times unit price without a total', () {
      final gross = partiallyReceivedPurchaseGross([
        {'status': 'received', 'quantity': '3', 'unit_price': '2.5'},
        {'status': 'N', 'quantity': '1', 'unit_price': '10'},
      ]);

      expect(gross, 7.5);
    });

    test('returns null when every line is received', () {
      expect(
        partiallyReceivedPurchaseGross([
          {'status': 'Y', 'total_price': '2'},
          {'status': 'FULLY_RECEIVED', 'total_price': '3'},
        ]),
        isNull,
      );
    });

    test('returns null when no line is received', () {
      expect(
        partiallyReceivedPurchaseGross([
          {'status': 'N', 'total_price': '2'},
          {'status': null, 'total_price': '3'},
        ]),
        isNull,
      );
    });
  });
}
