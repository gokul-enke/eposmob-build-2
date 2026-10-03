import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/expenses/domain/expense_filter.dart';
import 'package:pos_machine/features/expenses/domain/models/expense.dart';
import '../support/expense_fixtures.dart';

void main() {
  test('filters combine exact account/category/status and caseless reference',
      () {
    final rows = [
      Expense.fromJson(row(1)),
      Expense.fromJson({...row(2), 'status': 'FAIL'})
    ];
    expect(
        applyExpenseFilters(rows,
            reference: '0001',
            category: 'Rent',
            debitAccount: 'Office',
            status: 'SUCC'),
        [rows.first]);
    expect(
        applyExpenseFilters(rows,
            reference: '',
            category: 'rent',
            debitAccount: 'All',
            status: 'All'),
        isEmpty);
    expect(
        applyExpenseFilters(rows,
            reference: '', category: 'All', debitAccount: 'All', status: 'All'),
        rows);
  });
  test('localized All remains a nonmeaningful filter selection', () {
    expect(isMeaningfulExpenseFilterSelection(' الكل ', allLabel: 'الكل'),
        isFalse);
    expect(
        isMeaningfulExpenseFilterSelection(' All ', allLabel: 'الكل'), isFalse);
    expect(isMeaningfulExpenseFilterSelection('Cash', allLabel: 'All'), isTrue);
  });
}
