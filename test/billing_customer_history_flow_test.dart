import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product cart helper does not block add-to-cart with history modal', () {
    final helperSource =
        File('lib/helpers/product_cart_helper.dart').readAsStringSync();

    expect(helperSource, isNot(contains('CustomerPurchaseHistoryModal')));
    expect(helperSource, isNot(contains('getCustomerLastPurchases')));
    expect(helperSource,
        contains('Add-to-cart does not fetch or show purchase history'));
  });
}
