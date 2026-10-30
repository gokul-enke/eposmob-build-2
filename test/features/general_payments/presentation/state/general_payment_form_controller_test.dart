import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_entry.dart';
import 'package:pos_machine/features/general_payments/domain/general_payment_type.dart';
import 'package:pos_machine/features/general_payments/presentation/state/general_payment_form_controller.dart';

const _cash = GeneralPaymentOption('11', 'Cash Account');
const _bank = GeneralPaymentOption('12', 'Bank Account');

/// The live accounts per kind, plus what was asked for and saved.
class _Backend {
  final asked = <(GeneralPaymentType, GeneralPaymentLoan?)>[];
  final saved = <Map<String, dynamic>>[];
  Completer<void>? accountsGate;
  bool accountsFail = false, categoriesFail = false;
  GeneralPaymentSaveResult answer =
      const GeneralPaymentSaved(reference: 'EXP00120');

  Future<GeneralPaymentAccounts> accounts(
      GeneralPaymentType type, GeneralPaymentLoan? loan) async {
    asked.add((type, loan));
    final gate = accountsGate;
    if (gate != null) await gate.future;
    if (accountsFail) throw StateError('down');
    return switch (type) {
      GeneralPaymentType.expense => const GeneralPaymentAccounts(debit: [
          GeneralPaymentOption('20', 'Indirect Expense Account'),
          GeneralPaymentOption('15', 'Purchase Account'),
        ], credit: [
          _cash,
          _bank
        ]),
      GeneralPaymentType.asset => const GeneralPaymentAccounts(
          debit: [GeneralPaymentOption('341', 'Fixed Asset Account')],
          credit: [_cash, _bank]),
      GeneralPaymentType.income => const GeneralPaymentAccounts(debit: [
          _cash,
          _bank
        ], credit: [
          GeneralPaymentOption('342', 'Indirect Income Account'),
          GeneralPaymentOption('375', 'Direct Income Account'),
        ]),
      GeneralPaymentType.loan => loan == GeneralPaymentLoan.repaid
          ? const GeneralPaymentAccounts(
              debit: [GeneralPaymentOption('376', 'Loan Account')],
              credit: [_cash, _bank])
          : const GeneralPaymentAccounts(
              debit: [_cash, _bank],
              credit: [GeneralPaymentOption('376', 'Loan Account')]),
    };
  }

  Future<List<GeneralPaymentOption>> categories(GeneralPaymentType type) async {
    if (categoriesFail) throw StateError('down');
    return [GeneralPaymentOption('${type.index + 1}', '${type.name} category')];
  }

  Future<List<GeneralPaymentOption>> methods() async => const [
        GeneralPaymentOption('7973', 'CARD', code: 'CARD'),
        GeneralPaymentOption('7974', 'CASH', code: 'CASH'),
      ];

  Future<GeneralPaymentSaveResult> save(Map<String, dynamic> payload) async {
    saved.add(payload);
    return answer;
  }
}

GeneralPaymentFormController _form(_Backend backend,
        {GeneralPaymentType type = GeneralPaymentType.expense,
        Map<String, List<String>>? methodRules}) =>
    GeneralPaymentFormController(
        type: type,
        nextReferences: const {
          'EXP': 'EXP00120',
          'INC': 'INC00008',
          'LRP': 'LRP00002',
        },
        loadAccounts: backend.accounts,
        loadCategories: backend.categories,
        loadPaymentMethods: backend.methods,
        loadAllowedMethods:
            methodRules == null ? null : () async => methodRules,
        save: backend.save,
        clock: () => DateTime(2026, 10, 30, 15));

/// Fills an expense's required choices and amount.
void _fill(GeneralPaymentFormController form) {
  form
    ..setCategory(form.categories.first.id)
    ..setDebitAccount(form.debitOptions.first.id)
    ..setCreditAccount(form.creditOptions.first.id)
    ..setPaymentMethod('7974');
  form.amount.text = '150.5';
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    Get.locale = const Locale('en');
  });

  test('starts today with the expense choices and no payment method', () async {
    final backend = _Backend();
    final form = _form(backend);
    addTearDown(form.dispose);
    await form.initialize();
    expect(form.date, DateTime(2026, 10, 30));
    expect(form.dateText.text, '2026 Oct 30');
    expect(form.reference.text, 'EXP00120');
    expect(form.paymentMethodId, isNull, reason: 'chosen on purpose');
    expect(form.debitOptions.map((o) => o.label),
        ['Indirect Expense Account', 'Purchase Account']);
    expect(form.debitAccountId, isNull, reason: 'two to choose from');
    expect(form.categories.single.label, 'expense category');
    expect(form.optionsFailed, isFalse);
  });

  test('payment methods follow the cash or bank account money moves through',
      () async {
    final form = _form(_Backend(), methodRules: {
      'Cash Account': ['CASH'],
      'Bank Account': ['CARD', 'UPI'],
    });
    addTearDown(form.dispose);
    await form.initialize();
    expect(form.paymentMethods, hasLength(2), reason: 'no account yet');
    form.setCreditAccount('11'); // paid from Cash Account
    expect(form.paymentMethods.map((m) => m.label), ['CASH']);
    expect(form.paymentMethodId, '7974', reason: 'its only method');
    form.setCreditAccount('12'); // paid from Bank Account
    expect(form.paymentMethods.map((m) => m.label), ['CARD']);
    expect(form.paymentMethodId, '7973', reason: 'cash no longer fits');
    await form.setType(GeneralPaymentType.income);
    form.setDebitAccount('11'); // received in Cash Account
    expect(form.paymentMethodId, '7974');
  });

  test('without Company Accounts rules every method stays to choose', () async {
    final form = _form(_Backend());
    addTearDown(form.dispose);
    await form.initialize();
    form.setCreditAccount('11');
    expect(form.paymentMethods, hasLength(2));
    expect(form.paymentMethodId, isNull);
  });

  test('a side with one account is chosen already', () async {
    final backend = _Backend();
    final form = _form(backend, type: GeneralPaymentType.asset);
    addTearDown(form.dispose);
    await form.initialize();
    expect(form.debitAccountName, 'Fixed Asset Account');
    expect(form.creditAccountId, isNull);
    expect(form.reference.text, isEmpty, reason: 'no asset reference known');
  });

  test('a new type clears its choices and loads its accounts', () async {
    final backend = _Backend();
    final form = _form(backend);
    addTearDown(form.dispose);
    await form.initialize();
    _fill(form);
    await form.setType(GeneralPaymentType.income);
    expect(backend.asked.last, (GeneralPaymentType.income, null));
    expect((form.categoryId, form.debitAccountId, form.creditAccountId),
        (null, null, null));
    expect(form.amount.text, '150.5', reason: 'typed values stay');
    expect(form.paymentMethodId, '7974');
    expect(form.reference.text, 'INC00008');
    expect(form.creditOptions.first.label, 'Indirect Income Account');
  });

  test('loans start as received and repaying swaps the accounts', () async {
    final backend = _Backend();
    final form = _form(backend);
    addTearDown(form.dispose);
    await form.initialize();
    await form.setType(GeneralPaymentType.loan);
    expect(form.loan, GeneralPaymentLoan.received);
    expect(form.creditAccountName, 'Loan Account');
    expect(form.reference.text, isEmpty, reason: 'no LON number known');
    await form.setLoan(GeneralPaymentLoan.repaid);
    expect(backend.asked.last,
        (GeneralPaymentType.loan, GeneralPaymentLoan.repaid));
    expect(form.debitAccountName, 'Loan Account');
    expect(form.creditAccountId, isNull);
    expect(form.reference.text, 'LRP00002',
        reason: 'repayments are numbered on their own (LRP)');
    await form.setType(GeneralPaymentType.expense);
    expect(form.loan, isNull);
  });

  test('a slower answer for an older type is ignored', () async {
    final backend = _Backend()..accountsGate = Completer();
    final form = _form(backend);
    addTearDown(form.dispose);
    final first = form.initialize();
    final late = backend.accountsGate!;
    backend.accountsGate = null;
    await form.setType(GeneralPaymentType.asset);
    expect(form.debitAccountName, 'Fixed Asset Account');
    late.complete();
    await first;
    expect(form.debitAccountName, 'Fixed Asset Account');
    expect(form.loadingAccounts, isFalse);
  });

  test('missing choices are named one at a time', () async {
    final backend = _Backend();
    final form = _form(backend);
    addTearDown(form.dispose);
    await form.initialize();
    expect(form.selectionError, 'general_payments.error_category');
    form.setCategory('1');
    expect(form.selectionError, 'general_payments.error_debit');
    form.setDebitAccount('11');
    expect(form.selectionError, 'general_payments.error_credit');
    form.setCreditAccount('11');
    expect(form.selectionError, 'general_payments.error_same_account');
    form.setCreditAccount('12');
    form.setPaymentMethod(null);
    expect(form.selectionError, 'general_payments.error_payment_method');
    form.setPaymentMethod('7973');
    expect(form.selectionError, isNull);
    expect(form.draft, isNull, reason: 'no amount yet');
  });

  test(
      'a method picked from a list opened before the account changed is '
      'dropped', () async {
    final form = _form(_Backend(), methodRules: {
      'Cash Account': ['CASH'],
      'Bank Account': ['CARD'],
    });
    addTearDown(form.dispose);
    await form.initialize();
    form.setCreditAccount('12'); // Bank Account: card only
    form.setPaymentMethod('7974'); // cash, from a stale list
    expect(form.paymentMethodId, '7973', reason: 'back to the only fit');
  });

  test('saving sends the entry; another keeps the kind for the next one',
      () async {
    final backend = _Backend();
    final form = _form(backend);
    addTearDown(form.dispose);
    await form.initialize();
    _fill(form);
    form.description.text = 'Fuel';
    final result = await form.submit(createAnother: true);
    expect(result, isA<GeneralPaymentSaved>());
    expect(backend.saved.single, {
      'entry_type': 'EXPENSE',
      'payment_date': '2026-10-30',
      'category': '1',
      'description': 'Fuel',
      'amount': 150.5,
      'payment_method': '7974',
      'expense_account_id': 20,
      'payment_account_id': 11,
      'status': 'SUCC',
      'notes': '',
    });
    expect(form.reference.text, 'EXP00121');
    expect((form.categoryId, form.amount.text, form.description.text),
        (null, '', ''));
    expect((form.debitAccountId, form.creditAccountId, form.paymentMethodId),
        ('20', '11', '7974'));
    expect(form.busy, isFalse);
  });

  test('a refused save keeps everything as typed', () async {
    final backend = _Backend()
      ..answer = const GeneralPaymentRejected('Period is closed');
    final form = _form(backend);
    addTearDown(form.dispose);
    await form.initialize();
    _fill(form);
    final result = await form.submit(createAnother: true);
    expect((result as GeneralPaymentRejected).message, 'Period is closed');
    expect((form.categoryId, form.amount.text), ('1', '150.5'));
    expect(form.reference.text, 'EXP00120');
  });

  test('an incomplete entry is not sent', () async {
    final backend = _Backend();
    final form = _form(backend);
    addTearDown(form.dispose);
    await form.initialize();
    expect(await form.submit(), isNull);
    expect(backend.saved, isEmpty);
  });

  test('an asset sends its useful life; a loan its direction', () async {
    final backend = _Backend();
    final form = _form(backend, type: GeneralPaymentType.asset);
    addTearDown(form.dispose);
    await form.initialize();
    _fill(form);
    form.usefulLife.text = '5';
    await form.submit();
    expect(backend.saved.last['useful_life_years'], 5);
    expect(backend.saved.last['expense_account_id'], 341);
    await form.setType(GeneralPaymentType.loan);
    await form.setLoan(GeneralPaymentLoan.repaid);
    _fill(form);
    await form.submit();
    expect(backend.saved.last['loan_type'], 'LOAN_REPAY');
    expect(backend.saved.last['expense_account_id'], 376);
    expect(backend.saved.last.containsKey('useful_life_years'), isFalse);
  });

  test('failed choices can be retried', () async {
    final backend = _Backend()
      ..accountsFail = true
      ..categoriesFail = true;
    final form = _form(backend);
    addTearDown(form.dispose);
    await form.initialize();
    expect(form.optionsFailed, isTrue);
    backend
      ..accountsFail = false
      ..categoriesFail = false;
    await form.retryOptions();
    expect(form.optionsFailed, isFalse);
    expect(form.debitOptions, hasLength(2));
  });

  test('answers after dispose change nothing', () async {
    final backend = _Backend()..accountsGate = Completer();
    final form = _form(backend);
    final load = form.initialize();
    form.dispose();
    backend.accountsGate!.complete();
    await load;
  });
}
