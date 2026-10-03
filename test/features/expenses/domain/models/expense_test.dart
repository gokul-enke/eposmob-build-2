import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/expenses/domain/models/expense.dart';

void main() {
  test('model retains aliases, identifiers, decimal amount and copy fields',
      () {
    final e = Expense.fromJson({
      'reference_no': '00001',
      'payment_date': '2026-10-03',
      'category_id': 12,
      'category_name': 'Rent',
      'expense_account_id': 4,
      'expense_account_name': 'Office',
      'payment_account_id': 5,
      'payment_account_name': 'Cash',
      'payment_method_id': 6,
      'payment_method_name': 'Cash',
      'amount': 1.234,
      'description': 'Rent',
      'notes': 'paid',
      'status': 'SUCC'
    });
    expect(e.categoryId, '12');
    expect(e.amount, 1.234);
    expect(e.referenceNumber, '00001');
    final copy = e.copyWith(category: 'Resolved');
    expect(copy.category, 'Resolved');
    expect(copy.creditAccountId, e.creditAccountId);
    expect(copy.amount, e.amount);
    expect(Expense.fromJson(e.toJson()).amount, e.amount);
  });
}
