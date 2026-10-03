import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the billing purchase-history flow.
void main() {
  test('product cart helper does not block add-to-cart with history dialog',
      () {
    final helperSource =
        File('lib/helpers/product_cart_helper.dart').readAsStringSync();

    expect(helperSource, isNot(contains('CustomerPurchaseHistoryModal')));
    expect(helperSource, isNot(contains('CustomerPurchaseHistoryDialog')));
    expect(helperSource, isNot(contains('getCustomerLastPurchases')));
    expect(helperSource,
        contains('Add-to-cart does not fetch or show purchase history'));
  });

  test('billing opens the customers feature purchase-history dialog', () {
    const dialogImport = 'package:pos_machine/features/customers/presentation/'
        'widgets/purchase_history/customer_purchase_history_dialog.dart';
    for (final path in const [
      'lib/features/billing/presentation/pages/billing_page.dart',
      'lib/features/billing/presentation/widgets/mobile/cart/cart_item_card.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains(dialogImport), reason: path);
      expect(source, contains('CustomerPurchaseHistoryDialog('), reason: path);
      expect(source, isNot(contains('CustomerPurchaseHistoryModal')),
          reason: path);
    }
    expect(
        File('lib/widgets/customer_purchase_history_modal.dart').existsSync(),
        isFalse);
  });
}
