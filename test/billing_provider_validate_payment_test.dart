library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/billing_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('validatePayment includes extra payment method amounts', () {
    final bp = BillingProvider();
    bp.setTotalOrderAmount(100);

    bp.setPaymentMethod('CASH', true);
    bp.cashAmountController.text = '25';
    bp.toggleExtraMethod('99', displayValue: 'CHEQUE');
    bp.setExtraPaymentAmount('99', '75', displayValue: 'CHEQUE');

    expect(bp.validatePayment(), isTrue);
  });

  test('validatePayment fails when extra amounts do not cover total', () {
    final bp = BillingProvider();
    bp.setTotalOrderAmount(100);

    bp.setPaymentMethod('CASH', true);
    bp.cashAmountController.text = '10';
    bp.toggleExtraMethod('99', displayValue: 'CHEQUE');
    bp.setExtraPaymentAmount('99', '20', displayValue: 'CHEQUE');

    expect(bp.validatePayment(), isFalse);
    expect(bp.paymentValidationError, isNotNull);
  });

  test('validatePayment accepts cash plus customer credit sale', () {
    final bp = BillingProvider();
    bp.setPaymentValidationCustomerContext(
      isDefaultCustomer: false,
      configuredDefaultCustomerPhone: '',
    );
    bp.setSelectedCustomer(
      CustomerListModelData(
        id: 42,
        name: 'Credit Customer',
        phone: '9876543210',
      ),
    );
    bp.setTotalOrderAmount(100);
    bp.setPaymentMethod('CASH', true);
    bp.cashAmountController.text = '40';
    bp.setPaymentMethod('DEBIT', true);
    bp.debitAmountController.text = '60';

    expect(bp.validatePayment(), isTrue);
  });
}
