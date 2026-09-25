import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/billing/domain/order_customer_fields.dart';
import 'package:pos_machine/models/customer_list.dart';

void main() {
  group('OrderCustomerFields.addressForReceipt', () {
    test('uses explicit delivery address before customer master data', () {
      final customer = CustomerListModelData(
        address: 'Customer road',
        pincode: '111111',
      );

      expect(
        OrderCustomerFields.addressForReceipt(
          customer: customer,
          orderAddress: 'Delivery road',
          orderPincode: '222222',
        ),
        'Delivery road, 222222',
      );
    });

    test('uses the selected saved address for takeaway receipts', () {
      final customer = CustomerListModelData(
        address: 'Legacy address',
        addresses: <Address>[
          Address(
            id: 54,
            address: '177, Kottakkal, Koduvally, Kerala 673572, India',
            city: '897',
            pincode: '673572',
          ),
        ],
      );

      expect(
        OrderCustomerFields.addressForReceipt(
          customer: customer,
          orderAddressId: 54,
        ),
        '177, Kottakkal, Koduvally, Kerala 673572, India, 897',
      );
    });

    test('falls back to flat customer address fields', () {
      final customer = CustomerListModelData(
        address: 'Main Street',
        city: 'Riyadh',
        pincode: '12345',
        country: 'Saudi Arabia',
      );

      expect(
        OrderCustomerFields.addressForReceipt(customer: customer),
        'Main Street, Riyadh, 12345, Saudi Arabia',
      );
    });
  });
}
