/// Unit tests for [BillingMobileController.restorePaymentMethods] — the most
/// intricate logic extracted out of `billing_page_mobile.dart`. It's now
/// context-free, so it can be exercised against a real [BillingProvider]
/// without mounting a widget.
library;

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
}
