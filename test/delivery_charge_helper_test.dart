import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/helpers/delivery_charge_helper.dart';
import 'package:pos_machine/models/delivery_method.dart';

DeliveryMethod _method({
  required String id,
  required String name,
  double price = 15.0,
}) {
  return DeliveryMethod(
    id: id,
    name: name,
    prices: [
      DeliveryPrice(
        id: 'p-$id',
        deliveryMethodId: id,
        price: price,
      ),
    ],
  );
}

void main() {
  group('computeDeliveryCharge', () {
    final methods = [
      _method(id: '1', name: 'Door Delivery', price: 20.0),
      _method(id: '2', name: 'Car Delivery', price: 10.0),
    ];

    test('returns 0 when free delivery feature is disabled', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: false,
          freeDeliveryMinimumAmount: 100,
          netTotal: 50,
          deliveryMethodId: '1',
          deliveryMethodName: 'Door Delivery',
          deliveryMethods: methods,
        ),
        0.0,
      );
    });

    test('returns base price when below threshold', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: true,
          freeDeliveryMinimumAmount: 100,
          netTotal: 99.99,
          deliveryMethodId: '1',
          deliveryMethodName: 'Door Delivery',
          deliveryMethods: methods,
        ),
        20.0,
      );
    });

    test('returns 0 at threshold', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: true,
          freeDeliveryMinimumAmount: 100,
          netTotal: 100,
          deliveryMethodId: '1',
          deliveryMethodName: 'Door Delivery',
          deliveryMethods: methods,
        ),
        0.0,
      );
    });

    test('returns 0 above threshold', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: true,
          freeDeliveryMinimumAmount: 100,
          netTotal: 250,
          deliveryMethodId: '1',
          deliveryMethodName: 'Door Delivery',
          deliveryMethods: methods,
        ),
        0.0,
      );
    });

    test('returns 0 when delivery method is missing', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: true,
          freeDeliveryMinimumAmount: 0,
          netTotal: 50,
          deliveryMethodId: 'missing',
          deliveryMethodName: 'Unknown',
          deliveryMethods: methods,
        ),
        0.0,
      );
    });

    test('returns 0 when delivery method name is empty', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: true,
          freeDeliveryMinimumAmount: 0,
          netTotal: 50,
          deliveryMethodId: '',
          deliveryMethodName: '',
          deliveryMethods: methods,
        ),
        0.0,
      );
    });

    test('uses override charge when provided', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: true,
          freeDeliveryMinimumAmount: 0,
          netTotal: 50,
          deliveryMethodId: '1',
          deliveryMethodName: 'Door Delivery',
          deliveryMethods: methods,
          overrideCharge: 7.5,
        ),
        7.5,
      );
    });

    test('override is ignored when free delivery applies at threshold', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: true,
          freeDeliveryMinimumAmount: 50,
          netTotal: 60,
          deliveryMethodId: '1',
          deliveryMethodName: 'Door Delivery',
          deliveryMethods: methods,
          overrideCharge: 7.5,
        ),
        0.0,
      );
    });

    test('matches method by name when id is empty', () {
      expect(
        computeDeliveryCharge(
          freeDeliveryEnabled: true,
          freeDeliveryMinimumAmount: 0,
          netTotal: 50,
          deliveryMethodId: '',
          deliveryMethodName: 'Car Delivery',
          deliveryMethods: methods,
        ),
        10.0,
      );
    });
  });

  group('formatDeliveryFeeLabel', () {
    test('shows Free for zero charge', () {
      expect(formatDeliveryFeeLabel(0, 'SAR'), 'Free');
    });

    test('formats non-zero charge', () {
      expect(formatDeliveryFeeLabel(12.5, 'SAR'), '(SAR 12.50)');
    });
  });
}
