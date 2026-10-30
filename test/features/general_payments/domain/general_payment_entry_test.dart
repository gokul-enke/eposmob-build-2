import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_entry.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';

GeneralPaymentDraft _draft(GeneralPaymentType type,
        {GeneralPaymentLoan? loan, int? usefulLife}) =>
    GeneralPaymentDraft(
        type: type,
        loan: loan,
        date: DateTime(2026, 9, 4, 18, 30),
        categoryId: '8491',
        debitAccountId: '12',
        creditAccountId: '375',
        amount: 2000,
        paymentMethodId: '7973',
        description: '  Commission from sale ',
        notes: ' note ',
        usefulLifeYears: usefulLife);

void main() {
  test('an income entry posts like the web: debit and credit by id', () {
    expect(_draft(GeneralPaymentType.income).toPayload(), {
      'entry_type': 'INCOME',
      'payment_date': '2026-09-04',
      'category': '8491',
      'description': 'Commission from sale',
      'amount': 2000.0,
      'payment_method': '7973',
      'expense_account_id': 12,
      'payment_account_id': 375,
      'status': 'SUCC',
      'notes': 'note',
    });
  });

  test('loans say which way the money moves', () {
    expect(
        _draft(GeneralPaymentType.loan, loan: GeneralPaymentLoan.repaid)
            .toPayload()['loan_type'],
        'LOAN_REPAY');
    expect(_draft(GeneralPaymentType.loan).toPayload()['loan_type'], 'LOAN_IN',
        reason: 'received is the default');
    expect(
        _draft(GeneralPaymentType.expense, loan: GeneralPaymentLoan.repaid)
            .toPayload()
            .containsKey('loan_type'),
        isFalse);
  });

  test('only assets send a useful life, and only when given', () {
    expect(
        _draft(GeneralPaymentType.asset, usefulLife: 5)
            .toPayload()['useful_life_years'],
        5);
    expect(
        _draft(GeneralPaymentType.asset)
            .toPayload()
            .containsKey('useful_life_years'),
        isFalse);
    expect(
        _draft(GeneralPaymentType.expense, usefulLife: 5)
            .toPayload()
            .containsKey('useful_life_years'),
        isFalse);
  });

  test('account ids that are not numbers are sent as they are', () {
    final payload = GeneralPaymentDraft(
            type: GeneralPaymentType.expense,
            date: DateTime(2026),
            categoryId: 'c',
            debitAccountId: 'acc-1',
            creditAccountId: '11',
            amount: 1,
            paymentMethodId: 'm')
        .toPayload();
    expect((payload['expense_account_id'], payload['payment_account_id']),
        ('acc-1', 11));
  });

  test('amount and useful life checks', () {
    for (final bad in ['', '0', '0.00', '-5', 'abc', 'NaN', 'Infinity']) {
      expect(generalPaymentAmountError(bad), 'general_payments.error_amount',
          reason: bad);
    }
    expect(generalPaymentAmountError(' 12.5 '), isNull);
    expect(generalPaymentUsefulLifeError(''), isNull, reason: 'optional');
    expect(generalPaymentUsefulLifeError('5'), isNull);
    for (final bad in ['0', '-1', 'two', '2.5']) {
      expect(generalPaymentUsefulLifeError(bad),
          'general_payments.error_useful_life',
          reason: bad);
    }
  });

  test('every reference series is known, repayments included', () {
    expect(
        generalPaymentReferencePrefixes, ['EXP', 'AST', 'INC', 'LON', 'LRP']);
    expect(
        generalPaymentReferencePrefix(
            GeneralPaymentType.loan, GeneralPaymentLoan.repaid),
        'LRP');
    expect(
        generalPaymentReferencePrefix(
            GeneralPaymentType.loan, GeneralPaymentLoan.received),
        'LON');
    expect(
        generalPaymentReferencePrefix(GeneralPaymentType.asset, null), 'AST');
  });

  test('the next reference follows the highest of the type', () {
    final refs = ['EXP00119', 'EXP00007', 'INC00007', 'LON00003', 'X1'];
    expect(nextGeneralPaymentReference('EXP', refs), 'EXP00120');
    expect(nextGeneralPaymentReference('INC', refs), 'INC00008');
    expect(nextGeneralPaymentReference('AST', refs), isNull);
    expect(nextGeneralPaymentReference('LON', ['LON99999']), 'LON100000');
    expect(followingGeneralPaymentReference('INC00008'), 'INC00009');
    expect(followingGeneralPaymentReference('AST00099'), 'AST00100');
    expect(followingGeneralPaymentReference('none'), isNull);
  });

  test('every type has a reference prefix and category codes', () {
    expect([for (final t in GeneralPaymentType.values) t.referencePrefix],
        ['EXP', 'AST', 'INC', 'LON']);
    expect(GeneralPaymentType.expense.categoryCodes.first, 'EXPENSE_CATEGORY');
    for (final type in GeneralPaymentType.values) {
      expect(type.categoryCodes, isNotEmpty, reason: type.name);
    }
    expect([for (final l in GeneralPaymentLoan.values) l.code],
        ['LOAN_IN', 'LOAN_REPAY']);
  });
}
