import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/purchase_returns/domain/purchase_return_filter.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/return_line_item.dart';
import 'package:pos_machine/features/purchase_returns/domain/models/purchase_return.dart';

void main() {
  test('optional filter trims dates and omits blank values', () {
    expect(PurchaseReturnFilter.optional('  '), isNull);
    expect(PurchaseReturnFilter.optional(' 2026-09-30 '), '2026-09-30');
  });
  test('line payload preserves quantity, optional reason and amount rounding',
      () {
    final item = ReturnLineItem(
        source: ReturnableItem(purchaseItemId: 12),
        unitPrice: 4.195,
        quantity: 1);
    expect(item.amount, 4.2);
    expect(item.toPayload(), {'purchase_item_id': 12, 'quantity': 1.0});
    item.reason = 'Damaged';
    expect(item.toPayload()['reason'], 'Damaged');
  });
}
