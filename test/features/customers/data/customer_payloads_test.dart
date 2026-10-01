import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/customers/data/customer_payloads.dart';

void main() {
  group('create', () {
    test('always sends the base fields and the store id', () {
      final body = CustomerPayloads.create(
        const CustomerFields(phone: '555', name: 'Ann'),
        storeId: '7',
      );
      expect(body, {
        'phone': '555',
        'name': 'Ann',
        'email': '',
        'store_id': '7',
        'address': '',
        'pin_code': '',
        'city': '',
        'state': '',
        'country': '',
      });
    });

    test('sends optional fields only when they are not empty', () {
      final body = CustomerPayloads.create(
        const CustomerFields(
          balance: '10',
          paymentType: '',
          customerType: 'B2B',
          crNumber: 'CR1',
          vatNumber: 'VAT1',
          altPhone: '999',
          gender: 'female',
          dob: '2000-01-02',
        ),
        storeId: '1',
      );
      expect(body['balance'], '10');
      expect(body.containsKey('payment_type'), isFalse);
      expect(body['customer_type'], 'B2B');
      expect(body['cr_number'], 'CR1');
      expect(body['vat_number'], 'VAT1');
      expect(body['alt_phone'], '999');
      expect(body['gender'], 'female');
      expect(body['dob'], '2000-01-02');
    });
  });

  group('update', () {
    test('sends the id plus every non-null field, empty strings included', () {
      final body = CustomerPayloads.update(
        12,
        const CustomerFields(name: 'New', email: '', pincode: '600001'),
        storeId: 3,
      );
      expect(body, {
        'customer_id': 12,
        'name': 'New',
        'email': '',
        'pin_code': '600001',
        'store_id': 3,
      });
    });

    test('with no changes only the id is sent', () {
      expect(CustomerPayloads.update(5, const CustomerFields()),
          {'customer_id': 5});
    });
  });
}
