/// Unit tests for [BillingMobileController.restorePaymentMethods] — the most
/// intricate logic extracted out of `billing_page_mobile.dart`. It's now
/// context-free, so it can be exercised against a real [BillingProvider]
/// without mounting a widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final controller = BillingMobileController();

  SavedOrder orderWith(String? paymentMethod, {String? paidAmount}) => SavedOrder(
        id: 'o1',
        orderNumber: '1',
        items: const [],
        createdAt: '2024-01-01',
        total: 0,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
      );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('multi-payment JSON restores CASH + CARD with their amounts', () {
    final bp = BillingProvider();
    controller.restorePaymentMethods(
      orderWith(
          '{"isMultiPayment":true,"methods":["CASH","CARD"],"amounts":{"CASH":"100","CARD":"50"}}'),
      bp,
    );
    expect(bp.isCashSelected, isTrue);
    expect(bp.isCardSelected, isTrue);
    expect(bp.cashAmountController.text, '100');
    expect(bp.cardAmountController.text, '50');
  });

  test('multi-payment JSON restores dynamic CHEQUE method', () {
    final bp = BillingProvider();
    controller.restorePaymentMethods(
      orderWith(
        '{"isMultiPayment":true,"methods":["CASH","99"],"amounts":{"CASH":"50","99":"75"}}',
      ),
      bp,
      resolvePaymentMethodValue: (id) => id == '99' ? 'CHEQUE' : null,
    );

    expect(bp.isCashSelected, isTrue);
    expect(bp.cashAmountController.text, '50');
    expect(bp.isExtraMethodSelected('99'), isTrue);
    expect(bp.extraPaymentAmounts['99'], '75');
    expect(bp.extraPaymentValues['99'], 'CHEQUE');
    expect(bp.getExtraAmountController('99').text, '75');
  });

  test('multi-payment ONLINE marks pine-labs success', () {
    final bp = BillingProvider();
    controller.restorePaymentMethods(
      orderWith('{"isMultiPayment":true,"methods":["ONLINE"],"amounts":{}}'),
      bp,
    );
    expect(bp.isOnlineSelected, isTrue);
  });

  test('single CASH method restores with the paid amount', () {
    final bp = BillingProvider();
    controller.restorePaymentMethods(orderWith('CASH', paidAmount: '250'), bp);
    expect(bp.isCashSelected, isTrue);
    expect(bp.cashAmountController.text, '250');
  });

  test('null payment method leaves nothing selected', () {
    final bp = BillingProvider();
    controller.restorePaymentMethods(orderWith(null), bp);
    expect(bp.isCashSelected, isFalse);
    expect(bp.isCardSelected, isFalse);
    expect(bp.isOnlineSelected, isFalse);
  });

  test('restoreOrderDetails rehydrates delivery date and time', () {
    final bp = BillingProvider();
    controller.restoreOrderDetails(
      _FakeBuildContext(),
      SavedOrder(
        id: 'o-delivery',
        orderNumber: '42',
        items: const [],
        createdAt: '2024-01-01',
        total: 100,
        deliveryMethod: 'Store Takeaway',
        deliveryMethodId: '1',
        deliveryDate: '2024-06-15T00:00:00.000',
        deliveryTime: '14:30',
      ),
      bp,
    );

    expect(bp.deliveryDate, DateTime.parse('2024-06-15T00:00:00.000'));
    expect(bp.deliveryTime, '14:30');
  });
}

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
