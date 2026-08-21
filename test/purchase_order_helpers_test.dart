import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/screens/purchase/helpers/purchase_order_error_helpers.dart';
import 'package:pos_machine/screens/purchase/helpers/purchase_order_item_helpers.dart';

void main() {
  group('purchase order payment errors', () {
    test(
      'does not disable payment for a generic paid_amounts validation error',
      () {
        expect(
          isAlreadyFullyPaidPurchaseOrderError({
            'errors': {
              'paid_amounts': ['Paid amount cannot exceed the balance'],
            },
          }, 'Paid amount cannot exceed the balance'),
          isFalse,
        );
      },
    );

    test('recognizes an explicit already-paid API response', () {
      expect(
        isAlreadyFullyPaidPurchaseOrderError({
          'error_code': 'PURCHASE_ORDER_ALREADY_PAID',
        }, 'Payment could not be applied'),
        isTrue,
      );
      expect(
        isAlreadyFullyPaidPurchaseOrderError({
          'message': 'This purchase order is fully paid',
        }, null),
        isTrue,
      );
    });
  });

  group('purchase order purchase-unit matching', () {
    final box = SaleUnit(id: 1, unitName: 'Box', conversionRate: '12');
    final caseUnit = SaleUnit(id: 2, unitName: 'Case', conversionRate: '12');

    test('matches the same unit and conversion rate', () {
      expect(
        purchaseOrderPurchaseUnitsMatch(box, '12', SaleUnit(id: 1), '12.0'),
        isTrue,
      );
    });

    test('keeps different purchase units separate', () {
      expect(
        purchaseOrderPurchaseUnitsMatch(box, '12', caseUnit, '12'),
        isFalse,
      );
      expect(
        purchaseOrderPurchaseUnitsMatch(box, '12', SaleUnit(id: 1), '6'),
        isFalse,
      );
    });

    test(
      'matches two base-unit rows when neither selected a purchase unit',
      () {
        expect(purchaseOrderPurchaseUnitsMatch(null, null, null, null), isTrue);
      },
    );
  });
}
