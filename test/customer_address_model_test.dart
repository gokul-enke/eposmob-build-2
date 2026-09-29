import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/customer_list.dart';

void main() {
  test('Address parses readable location fields from customer details', () {
    final address = Address.fromJson({
      'id': 97,
      'customer_id': 2739,
      'address': 'uohj',
      'city': null,
      'state_id': 45,
      'state': 'Makkah',
      'district_id': 629,
      'district': 'Jeddah',
      'pincode_id': 4858,
      'pincode': '21442',
      'pincode_area': 'jeddah',
    });

    expect(address.state, 'Makkah');
    expect(address.district, 'Jeddah');
    expect(address.pincode, '21442');
    expect(address.pincodeArea, 'jeddah');
  });

  test('Address parses nested lookup labels for compatibility', () {
    final address = Address.fromJson({
      'state': {'name': 'Makkah'},
      'district': {'name': 'Jeddah'},
      'pincode': {'pin_code': '21442'},
      'pincode_area': {'area': 'jeddah'},
    });

    expect(address.state, 'Makkah');
    expect(address.district, 'Jeddah');
    expect(address.pincode, '21442');
    expect(address.pincodeArea, 'jeddah');
  });
}
