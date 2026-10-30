import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_entry.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_method_rules.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';

const _card = GeneralPaymentOption('7973', 'card', code: 'CARD');
const _cash = GeneralPaymentOption('7974', 'cash', code: 'CASH');
const _upi = GeneralPaymentOption('10160', 'UPI', code: 'UPI');
const _cod = GeneralPaymentOption('8185', 'Cash On Delivery', code: 'COD');
const _methods = [_card, _cash, _cod, _upi];

void main() {
  final rules = GeneralPaymentMethodRules({
    ' Cash Account ': ['CASH'],
    'Bank Account': ['card', 'Upi'],
    'Petty Cash': [],
    'Odd Account': ['CHEQUE'],
  });

  test('an account offers only its methods, by code or name in any case', () {
    expect(rules.methodsFor('cash account', _methods), [_cash]);
    expect(rules.methodsFor('Bank Account', _methods), [_card, _upi]);
  });

  test('without a rule every method stays', () {
    expect(rules.methodsFor(null, _methods), _methods);
    expect(rules.methodsFor('Unknown', _methods), _methods);
    expect(rules.methodsFor('Petty Cash', _methods), _methods,
        reason: 'an empty list is no rule');
    expect(GeneralPaymentMethodRules.none.methodsFor('Cash Account', _methods),
        _methods);
  });

  test('a rule that matches no method leaves every method', () {
    expect(rules.methodsFor('Odd Account', _methods), _methods);
  });

  test('which accounts limit their methods', () {
    expect(rules.limits('CASH ACCOUNT'), isTrue);
    expect(rules.limits('Petty Cash'), isFalse);
    expect(rules.limits(null), isFalse);
  });

  test('income and loans received take money in on the debit side', () {
    expect(
        GeneralPaymentMethodRules.receivesOnDebit(
            GeneralPaymentType.income, null),
        isTrue);
    expect(
        GeneralPaymentMethodRules.receivesOnDebit(
            GeneralPaymentType.loan, GeneralPaymentLoan.received),
        isTrue);
    expect(
        GeneralPaymentMethodRules.receivesOnDebit(
            GeneralPaymentType.loan, GeneralPaymentLoan.repaid),
        isFalse);
    expect(
        GeneralPaymentMethodRules.receivesOnDebit(
            GeneralPaymentType.expense, null),
        isFalse);
    expect(
        GeneralPaymentMethodRules.receivesOnDebit(
            GeneralPaymentType.asset, null),
        isFalse);
  });
}
