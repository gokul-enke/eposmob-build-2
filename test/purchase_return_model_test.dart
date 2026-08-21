import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/purchase_return_model.dart';

void main() {
  test('parses purchase return pagination and fractional item data', () {
    final model = ListPurchaseReturnModel.fromJson({
      'status': 'success',
      'data': {
        'current_page': '2',
        'last_page': 4,
        'data': [
          {
            'id': '17',
            'purchase_voucher_id': '31',
            'reference': 17,
            'return_date': '2026-08-21',
            'total_amount': '25.50',
            'items': [
              {
                'id': '8',
                'purchase_item_id': '9',
                'product_id': '12',
                'product_name': 'Coffee',
                'quantity': '0.125',
                'amount': '25.50',
              },
            ],
          },
        ],
      },
    });

    final data = model.data!;
    final item = data.data!.single.items!.single;

    expect(data.currentPage, 2);
    expect(data.lastPage, 4);
    expect(data.data!.single.id, 17);
    expect(data.data!.single.purchaseVoucherId, 31);
    expect(item.purchaseItemId, 9);
    expect(item.quantity, closeTo(0.125, 0.000001));
  });
}
