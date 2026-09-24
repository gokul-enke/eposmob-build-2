import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/invoice_details.dart';

void main() {
  test('parses decimal-string invoice item quantities', () {
    final details = InvoiceDetails.fromJson({
      'id': 6208,
      'customer_id': 2527,
      'invoice_number': 'INV-OR1001916',
      'type': 'Order',
      'company_id': 2,
      'amount': '35.000',
      'invoice_date': '2026-09-24',
      'due_date': '2026-09-24',
      'status': 'paid',
      'created_by': 516,
      'created_at': '2026-09-24 00:00:00',
      'updated_at': '2026-09-24 00:00:00',
      'company': null,
      'customer': {
        'id': 2527,
        'user_id': 1005,
        'user': {
          'name': 'Test Default',
          'email': '',
          'phone': '0011001100',
        },
      },
      'invoice_items': [
        {
          'id': 13336,
          'invoice_id': 6208,
          'item_name': 'Product',
          'quantity': '1.000',
          'unit_amount': '13.760',
          'tax': '1.240',
          'total_amount': '15.000',
        },
      ],
    });

    expect(details.invoiceItems.single.quantity, 1.0);
    expect(details.invoiceItems.single.displayQuantity, '1');
  });

  test('keeps fractional invoice item quantities visible', () {
    final item = InvoiceItem.fromJson({
      'id': 1,
      'invoice_id': 2,
      'item_name': 'Weighted Product',
      'quantity': '1.5',
      'unit_amount': '10.00',
      'tax': '0.00',
      'total_amount': '15.00',
    });

    expect(item.quantity, 1.5);
    expect(item.displayQuantity, '1.5');
  });
}
