/// Coverage for OrderDetailsModelDataDeliveryAddress, which feeds the
/// Shipping Details section of the order details screen.
///
/// DELIVERY_ADDRESS.props_value reaches the app in three shapes depending on
/// the endpoint and backend version — a real map, a JSON string, and Dart's
/// own Map.toString() output — and its lookup fields may be flat values or
/// nested objects. Getting any combination wrong puts a raw fragment such as
/// "{id: 10" in front of the user, or falls back to the customer's saved
/// address, which may not be where the order was sent.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/order_details.dart';

void main() {
  Map<String, dynamic> orderWith(dynamic propsValue, {List? savedAddress}) => {
        'order_props': [
          {'props_code': 'DELIVERY_ADDRESS', 'props_value': propsValue},
        ],
        if (savedAddress != null)
          'customer_details': {'address': savedAddress},
      };

  group('props_value shapes', () {
    test('reads a real map', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson(
        orderWith({'city': 'Koduvally', 'address': '177, Kottakkal, India'}),
      );

      expect(address?.city, 'Koduvally');
      expect(address?.address, '177, Kottakkal, India');
    });

    test('decodes a JSON string', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson(
        orderWith('{"city":"Koduvally","address":"177, Kottakkal, India"}'),
      );

      expect(address?.city, 'Koduvally');
      expect(address?.address, '177, Kottakkal, India');
    });

    test('decodes Dart Map.toString() output', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson(
        orderWith('{city: Koduvally, address: 177, Kottakkal, India}'),
      );

      expect(address?.city, 'Koduvally');
      expect(address?.address, '177, Kottakkal, India',
          reason: 'commas inside a street address are not field separators');
    });
  });

  group('nested lookup objects', () {
    test('resolves nested state and pincode from a real map', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson(
        orderWith({
          'state': {'id': 10, 'name': 'Kerala'},
          'pincode': {'id': 3, 'pin_code': '673572'},
        }),
      );

      expect(address?.state, 'Kerala');
      expect(address?.pincode, '673572');
    });

    test('resolves nested objects inside Map.toString() output', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson(
        orderWith(
          '{city: 897, state: {id: 10, name: Kerala}, '
          'pincode: {id: 3, pin_code: 673572}, '
          'address: 177, Kottakkal, Koduvally, India, landmark: null}',
        ),
      );

      expect(address?.state, 'Kerala',
          reason: 'a nested object must not be split into "{id: 10"');
      expect(address?.pincode, '673572');
      expect(address?.address, '177, Kottakkal, Koduvally, India');
      expect(address?.city, '897');
      expect(address?.landmark, isNull);
    });
  });

  group('sources and fallbacks', () {
    test('prefers the order address over the customer saved address', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson(
        orderWith(
          {'address': 'Office, Building 4'},
          savedAddress: [
            {'address': 'Home, 12 Elm Street', 'type': 'Home'}
          ],
        ),
      );

      expect(address?.address, 'Office, Building 4',
          reason: 'the order must show where it was actually delivered');
    });

    test('reads the address type when the saved address is the source', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson({
        'customer_details': {
          'address': [
            {'address': 'Home, 12 Elm Street', 'type': 'Home'}
          ]
        }
      });

      expect(address?.addressType, 'Home');
    });

    test('never mixes the order address with the saved one', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson(
        orderWith(
          {'address': 'Office, Building 4', 'city': 'Riyadh'},
          savedAddress: [
            {
              'address': 'Home, 12 Elm Street',
              'city': 'Jeddah',
              'pincode_id': '23442',
              'state_id': 'Makkah',
              'landmark': 'Near the mosque',
              'type': 'Home',
            }
          ],
        ),
      );

      expect(address?.address, 'Office, Building 4');
      expect(address?.city, 'Riyadh');
      expect(address?.pincode, isNull,
          reason: 'a home pincode on an office delivery would be misleading');
      expect(address?.state, isNull);
      expect(address?.landmark, isNull);
      expect(address?.addressType, isNull,
          reason: 'a delivery prop carries no type; "Home" would mislabel it');
    });

    test('falls back to the saved address when the order carries none', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson({
        'customer_details': {
          'address': [
            {'address': 'Home, 12 Elm Street', 'city': 'Kozhikode'}
          ]
        }
      });

      expect(address?.address, 'Home, 12 Elm Street');
      expect(address?.city, 'Kozhikode');
    });

    test('is null when there is no address anywhere, so the card hides', () {
      expect(
        OrderDetailsModelDataDeliveryAddress.fromOrderJson({'order_props': []}),
        isNull,
      );
    });

    test('treats the literal string "null" as empty', () {
      final address = OrderDetailsModelDataDeliveryAddress.fromOrderJson(
        orderWith('{address: 12 Elm Street, state: null, landmark: null}'),
      );

      expect(address?.address, '12 Elm Street');
      expect(address?.state, isNull);
      expect(address?.landmark, isNull);
    });
  });
}
