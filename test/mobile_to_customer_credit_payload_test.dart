/// Mobile checkout / save payload contract for To-Customer-Credit allocation.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/billing_provider.dart';

void main() {
  const controller = BillingMobilePaymentController();

  group('mobile to-customer-credit checkout payload', () {
    test('createOrderData includes toCustomerCredit flag and DEBIT amount',
        () {
      final bp = BillingProvider();
      bp.setSelectedCustomer(
        CustomerListModelData(
          id: 42,
          name: 'Regular Customer',
          phone: '9876543210',
          balance: 10,
        ),
      );
      bp.setTotalOrderAmount(100);
      bp.cashAmountController.text = '120';
      bp.setPaymentMethod('CASH', true);

      controller.toggleToCustomerCredit(bp, true);

      expect(bp.toCustomerCreditEnabled, isTrue);
      expect(bp.debitAmountController.text, '20.00');

      final orderData = bp.createOrderData();
      expect(orderData['toCustomerCredit'], isTrue);

      final paymentJson =
          json.decode(orderData['paymentMethod'] as String) as Map<String, dynamic>;
      expect(paymentJson['methods'], contains('DEBIT'));
      expect(paymentJson['amounts']['DEBIT'], '20.00');
    });

    test('clampToCustomerCreditAmount limits credit to transaction excess', () {
      final bp = BillingProvider();
      bp.setSelectedCustomer(
        CustomerListModelData(
          id: 7,
          name: 'Debtor',
          phone: '111',
          balance: -50,
        ),
      );
      bp.setTotalOrderAmount(100);
      bp.cashAmountController.text = '130';
      bp.setPaymentMethod('CASH', true);

      controller.toggleToCustomerCredit(bp, true);
      expect(bp.debitAmountController.text, '30.00');

      bp.debitAmountController.text = '99';
      controller.clampToCustomerCreditAmount(bp);

      expect(bp.debitAmountController.text, '30.00');
    });

    test('prefill caps at customer debt when balance is negative', () {
      final bp = BillingProvider();
      bp.setSelectedCustomer(
        CustomerListModelData(
          id: 8,
          name: 'Small Debtor',
          phone: '222',
          balance: -15,
        ),
      );
      bp.setTotalOrderAmount(100);
      bp.cashAmountController.text = '200';
      bp.setPaymentMethod('CASH', true);

      controller.toggleToCustomerCredit(bp, true);

      expect(bp.debitAmountController.text, '15.00');
    });
  });
}
