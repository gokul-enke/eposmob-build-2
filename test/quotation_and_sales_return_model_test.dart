import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/sales_return_detail_helper.dart';
import 'package:pos_machine/models/list_sales_return.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';
import 'package:pos_machine/models/quotation_model.dart';

void main() {
  group('Quotation response parsing', () {
    test('reads a customer object in the quotation list response', () {
      final quotation = Quotation.fromJson({
        'id': 42,
        'quotation_number': 'QTN-00042',
        'customer_id': 7,
        'customer': {'id': 7, 'name': 'QA Customer', 'phone': '0500000000'},
      });

      expect(quotation.customerId, 7);
      expect(quotation.customer, 'QA Customer');
      expect(quotation.customerPhone, '0500000000');
    });

    test('keeps inline customer fields when the detail response is flat', () {
      final details = QuotationDetailsData.fromJson({
        'id': 43,
        'quotation_number': 'QTN-00043',
        'customer_name': 'Walk-in QA',
        'customer_phone': '0500111222',
      });

      expect(details.customer?.name, 'Walk-in QA');
      expect(details.customer?.phone, '0500111222');
      expect(details.customer?.isInline, isTrue);
    });
  });

  group('Sales return response parsing', () {
    test('renders product data when the API uses return_items and flat fields',
        () {
      final order = SalesReturnOrder.fromJson({
        'id': 10,
        'order_id': 20,
        'total_amount': '2.00',
        'user_id': 1,
        'status': 1,
        'return_items': [
          {
            'id': 30,
            'order_return_id': 10,
            'cart_item_id': 40,
            'price': '2.00',
            'reason': 'QA return',
            'quantity': 1,
            'product_name': 'Kitkat',
            'cart_item': null,
          },
        ],
      });

      final item = order.items.single;
      expect(item.cartItem.displayName, 'Kitkat');
      expect(item.cartItem.unitPrice, '2.00');
      expect(item.reason, 'QA return');
    });

    test('prints only items belonging to the selected return transaction', () {
      final selectedReturn = SalesReturnOrder.fromJson({
        'id': 10,
        'order_id': 20,
        'total_amount': '1.00',
        'user_id': 1,
        'status': 1,
        'return_items': [
          {
            'id': 30,
            'order_return_id': 10,
            'cart_item_id': 40,
            'price': '2.00',
            'reason': 'Selected return',
            'quantity': 0.5,
            'product_name': 'Flour',
          },
        ],
      });
      final orderWideItems = [
        SalesReturnCart.fromJson({
          'cart_item_id': 40,
          'return_order_id': 10,
          'product_name': 'Flour',
          'quantity': 2,
          'returned_quantity': 0.5,
          'unit_price': '2.00',
          'is_returned': true,
        }),
        SalesReturnCart.fromJson({
          'cart_item_id': 41,
          'return_order_id': 11,
          'product_name': 'Unrelated item',
          'quantity': 3,
          'returned_quantity': 2,
          'unit_price': '4.00',
          'is_returned': true,
        }),
      ];

      final printItems = buildTransactionReturnPrintItems(
          selectedReturn.items, orderWideItems);

      expect(printItems, hasLength(1));
      expect(printItems.single.productName, 'Flour');
      expect(printItems.single.quantity, 0.5);
      expect(printItems.single.reason, 'Selected return');
    });

    test('reads product unit for return quantity validation', () {
      final item = SalesReturnCart.fromJson({
        'cart_item_id': 40,
        'return_order_id': 10,
        'product_name': 'Flour',
        'quantity': 2,
        'unit_price': '2.00',
        'is_returned': false,
        'product': {'unit': 'KG'},
      });

      expect(item.productUnit, 'KG');
    });

    test('parses a nested product unit used by the return-items endpoint', () {
      final item = SalesReturnCart.fromJson({
        'cart_item_id': 1,
        'return_order_id': 2,
        'product': {
          'name': 'Weighted item',
          'unit': {'name': 'KG'},
        },
        'quantity': '1.000',
        'unit_price': '50.000',
        'total_price': '50.000',
        'returned_quantity': 0,
        'returned_total': '0',
        'is_returned': false,
      });

      expect(item.productUnit, 'KG');
    });
  });
}
