import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/expenses/domain/expense_options.dart';

void main() {
  test('normalizes account aliases and deduplicates by trimmed ID', () {
    expect(
        normalizeExpenseOptionList([
          {'account_id': 1, 'name': ' Office '},
          {'id': '1', 'name': 'Duplicate'},
          {'code': 'C', 'description': 'Cash'},
          'Card',
          {},
          null
        ]),
        [
          {'id': '1', 'name': 'Office'},
          {'id': 'C', 'name': 'Cash'},
          {'id': 'Card', 'name': 'Card'}
        ]);
  });
  test('extracts only requested options, including nested arrays', () {
    expect(
        extractExpenseOptionList({
          'expense_accounts': {
            'items': [1, 2]
          },
          'payment_accounts': [3]
        }, [
          'expense_accounts'
        ]),
        [1, 2]);
    expect(
        extractExpenseOptionList({
          'payment_accounts': [3]
        }, [
          'expense_accounts'
        ]),
        isEmpty);
  });
}
