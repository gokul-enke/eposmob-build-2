import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/expenses/presentation/state/expense_form_controller.dart';

ExpenseFormController validForm() =>
    ExpenseFormController(referenceNo: 'EXP00001')
      ..selectedCategory = {'id': 1}
      ..selectedDebitAccount = {'id': 2}
      ..selectedCreditAccount = {'id': 3}
      ..selectedPaymentMethod = {'id': 4, 'name': 'Cash'}
      ..amountController.text = '1.234';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
      'required selections, amount and account payment restrictions are retained',
      () {
    final c = ExpenseFormController(referenceNo: 'EXP00001');
    expect(c.selectionError, 'expense.error_no_category');
    c.dispose();
    final v = validForm();
    expect(v.selectionError, isNull);
    v.selectCreditAccount({'id': 5}, ['Card']);
    expect(v.selectedPaymentMethod, isNull);
    expect(
        v.filteredPaymentMethods([
          {'name': 'Cash'},
          {'name': 'Card'}
        ]),
        [
          {'name': 'Card'}
        ]);
    v.dispose();
  });
  test(
      'create-another resets inputs after success and rejects duplicate submission',
      () async {
    final c = validForm();
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    Future<Map<String, dynamic>> create(Map<String, dynamic> payload) {
      calls++;
      expect(payload['amount'], 1.234);
      return pending.future;
    }

    final first = c.submit(
        create: create, nextReference: () => 'EXP00002', createAnother: true);
    expect(c.isSubmitting, isTrue);
    expect(await c.submit(create: create, nextReference: () => ''), isNull);
    expect(calls, 1);
    pending.complete({'status': 'success'});
    await first;
    expect(c.isSubmitting, isFalse);
    expect(c.referenceNo, 'EXP00002');
    expect(c.amountController.text, '');
    expect(c.selectedCategory, isNull);
    c.dispose();
  });
  test('late completion after dispose does not notify or touch disposed inputs',
      () async {
    final c = validForm();
    final pending = Completer<Map<String, dynamic>>();
    final result = c.submit(
        create: (_) => pending.future,
        nextReference: () => throw StateError('disposed'),
        createAnother: true);
    c.dispose();
    pending.complete({'status': 'success'});
    expect(await result, isNull);
  });
  test('failed creation keeps input and releases loading state for retry',
      () async {
    final c = validForm();
    await c.submit(
        create: (_) async => {'status': 'error'},
        nextReference: () => '',
        createAnother: true);
    expect(c.amountController.text, '1.234');
    expect(c.isSubmitting, isFalse);
    c.dispose();
  });
}
