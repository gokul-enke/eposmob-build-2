import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/expenses/data/expense_payloads.dart';

void main() {
  test('expense payload preserves date, trimmed values and original ID types',
      () {
    expect(
        expenseCreatePayload(
            date: DateTime(2026, 10, 3),
            category: {'id': 12},
            debitAccount: {'id': 4},
            creditAccount: {'id': '8'},
            paymentMethod: {'id': 9},
            description: ' Rent ',
            amount: 1.234,
            notes: ' paid '),
        {
          'entry_type': 'EXPENSE',
          'payment_date': '2026-10-03',
          'category': '12',
          'description': 'Rent',
          'amount': 1.234,
          'payment_method': '9',
          'expense_account_id': 4,
          'payment_account_id': '8',
          'status': 'SUCC',
          'notes': 'paid',
        });
  });
}
