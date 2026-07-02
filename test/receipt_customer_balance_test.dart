import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/receipt_customer_balance.dart';

void main() {
  group('ReceiptCustomerBalance.compute', () {
    test('returns null balances for default customer', () {
      final result = ReceiptCustomerBalance.compute(
        isDefaultCustomer: true,
        customerBalance: 100,
        cartTotal: 50,
        totalPaid: 50,
      );

      expect(result.oldBalance, isNull);
      expect(result.currentBalance, isNull);
    });

    test('computes current balance from old balance, cart total, and paid', () {
      final result = ReceiptCustomerBalance.compute(
        isDefaultCustomer: false,
        customerBalance: 200,
        cartTotal: 150,
        totalPaid: 100,
      );

      expect(result.oldBalance, 200);
      // 200 - (150 - 100) = 150
      expect(result.currentBalance, 150);
    });

    test('increases balance when customer overpays', () {
      final result = ReceiptCustomerBalance.compute(
        isDefaultCustomer: false,
        customerBalance: 50,
        cartTotal: 100,
        totalPaid: 120,
      );

      expect(result.oldBalance, 50);
      // 50 - (100 - 120) = 70
      expect(result.currentBalance, 70);
    });
  });
}
