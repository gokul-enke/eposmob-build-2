import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/models/delivery_method_registry.dart';

/// Guards the delivery-method identity resolution that the billing flow depends
/// on for car-number and address validation.
///
/// Before this, ~64 sites compared the *display name* (`== "Car Delivery"`).
/// Once the API began returning localized names those comparisons silently
/// stopped matching, disabling validation with no error. These tests pin the
/// replacement behaviour under every payload shape we expect to see in the
/// field, old and new.
void main() {
  tearDown(DeliveryMethodRegistry.clear);

  group('kind resolution', () {
    test('resolves from the legacy English name when no code is present', () {
      // Exactly what an older backend returns today.
      final method = DeliveryMethod.fromMap({
        'id': '2',
        'name': 'Car Delivery',
      });

      expect(method.kind, DeliveryKind.carDelivery);
      expect(method.requiresCarNumber, isTrue);
      expect(method.requiresAddress, isFalse);
    });

    test('resolves from code regardless of separator or casing', () {
      for (final code in ['car-delivery', 'CAR_DELIVERY', 'Car Delivery']) {
        final method = DeliveryMethod.fromMap({
          'id': '2',
          'name': 'anything at all',
          'code': code,
        });
        expect(method.kind, DeliveryKind.carDelivery, reason: 'code=$code');
      }
    });

    test('resolves from code when the name is Arabic', () {
      final method = DeliveryMethod.fromMap({
        'id': '2',
        'name': 'توصيل بالسيارة',
        'code': 'car-delivery',
        'translations': {'en': 'Car Delivery', 'ar': 'توصيل بالسيارة'},
      });

      expect(method.kind, DeliveryKind.carDelivery);
      expect(method.requiresCarNumber, isTrue);
    });

    test('falls back to the English translation when code is missing', () {
      // Backend ships translations before it ships stable codes.
      final method = DeliveryMethod.fromMap({
        'id': '3',
        'name': 'توصيل للمنزل',
        'translations': {'en': 'Door Delivery', 'ar': 'توصيل للمنزل'},
      });

      expect(method.kind, DeliveryKind.doorDelivery);
      expect(method.requiresAddress, isTrue);
      expect(method.requiresCarNumber, isFalse);
    });

    test('an unknown tenant method is "other" and demands nothing', () {
      final method = DeliveryMethod.fromMap({
        'id': '9',
        'name': 'Drone Drop',
        'code': 'drone-drop',
      });

      expect(method.kind, DeliveryKind.other);
      expect(method.requiresCarNumber, isFalse);
      expect(method.requiresAddress, isFalse);
    });

    test('an explicit capability flag overrides the inferred kind', () {
      // This is the payoff: a tenant adds a curbside-style method and it starts
      // demanding a car number with no app release.
      final method = DeliveryMethod.fromMap({
        'id': '9',
        'name': 'Drone Drop',
        'code': 'drone-drop',
        'requires_car_number': true,
        'requires_address': true,
      });

      expect(method.kind, DeliveryKind.other);
      expect(method.requiresCarNumber, isTrue);
      expect(method.requiresAddress, isTrue);
    });

    test('an explicit false flag suppresses the inferred requirement', () {
      final method = DeliveryMethod.fromMap({
        'id': '2',
        'name': 'Car Delivery',
        'requires_car_number': false,
      });

      expect(method.kind, DeliveryKind.carDelivery);
      expect(method.requiresCarNumber, isFalse,
          reason: 'explicit false must win over inference');
    });
  });

  group('translations parsing', () {
    test('accepts the empty array the backend currently sends', () {
      // PHP json_encode emits [] for an empty associative array. This must not
      // throw — it is what every untranslated record looks like today.
      final method = DeliveryMethod.fromMap({
        'id': '1',
        'name': 'Store Takeaway',
        'translations': <dynamic>[],
      });

      expect(method.translations, isEmpty);
      expect(method.kind, DeliveryKind.storeTakeaway);
    });

    test('accepts a missing translations key', () {
      final method = DeliveryMethod.fromMap({'id': '1', 'name': 'Pickup'});
      expect(method.translations, isEmpty);
    });

    test('backfills a base language from a region-qualified key', () {
      // The backend normalizes ar_SA -> ar-sa. The app looks up by base
      // language only, so `ar` must be derivable or offline switching breaks.
      final method = DeliveryMethod.fromMap({
        'id': '2',
        'name': 'Car Delivery',
        'translations': {'en': 'Car Delivery', 'ar-SA': 'توصيل بالسيارة'},
      });

      expect(method.translations['ar'], 'توصيل بالسيارة');
      expect(method.translations['ar-sa'], 'توصيل بالسيارة');
    });

    test('does not overwrite an explicit base key with a regional one', () {
      final method = DeliveryMethod.fromMap({
        'id': '2',
        'name': 'Car Delivery',
        'translations': {'ar': 'base', 'ar-sa': 'regional'},
      });

      expect(method.translations['ar'], 'base');
    });
  });

  group('status parsing', () {
    test('accepts Y/N, booleans and 1/0, and defaults to enabled', () {
      expect(DeliveryMethod.fromMap({'id': '1', 'name': 'a'}).enabled, isTrue);
      for (final truthy in ['Y', 'y', 'true', '1', 1, true]) {
        expect(
          DeliveryMethod.fromMap({'id': '1', 'name': 'a', 'status': truthy})
              .enabled,
          isTrue,
          reason: 'status=$truthy',
        );
      }
      for (final falsy in ['N', 'n', 'false', '0', 0, false]) {
        expect(
          DeliveryMethod.fromMap({'id': '1', 'name': 'a', 'status': falsy})
              .enabled,
          isFalse,
          reason: 'status=$falsy',
        );
      }
    });
  });

  group('registry lookup', () {
    setUp(() {
      DeliveryMethodRegistry.update([
        DeliveryMethod.fromMap({
          'id': '1',
          'name': 'استلام من المتجر',
          'code': 'store-takeaway',
          'translations': {'en': 'Store Takeaway', 'ar': 'استلام من المتجر'},
        }),
        DeliveryMethod.fromMap({
          'id': '2',
          'name': 'توصيل بالسيارة',
          'code': 'car-delivery',
          'translations': {'en': 'Car Delivery', 'ar': 'توصيل بالسيارة'},
        }),
      ]);
    });

    test('an order saved in English still resolves while running Arabic', () {
      // The critical regression: an order persisted before the language switch
      // carries the English name, but the loaded methods are now Arabic.
      expect(DeliveryMethodRegistry.requiresCarNumber('Car Delivery'), isTrue);
      expect(DeliveryMethodRegistry.kindOf('Car Delivery'),
          DeliveryKind.carDelivery);
    });

    test('an order saved in Arabic resolves too', () {
      expect(
          DeliveryMethodRegistry.requiresCarNumber('توصيل بالسيارة'), isTrue);
    });

    test('lookup works by id and by code', () {
      expect(DeliveryMethodRegistry.find('2')?.id, '2');
      expect(DeliveryMethodRegistry.find('car-delivery')?.id, '2');
      expect(DeliveryMethodRegistry.find('CAR-DELIVERY')?.id, '2');
    });

    test('default method is the store-takeaway one, not merely the first', () {
      DeliveryMethodRegistry.update([
        DeliveryMethod.fromMap(
            {'id': '2', 'name': 'Car Delivery', 'code': 'car-delivery'}),
        DeliveryMethod.fromMap(
            {'id': '1', 'name': 'Store Takeaway', 'code': 'store-takeaway'}),
      ]);

      expect(DeliveryMethodRegistry.defaultMethod?.id, '1');
    });

    test('resolves before the registry has loaded (cold start / offline)', () {
      // Degrades to exactly what the old English-name comparison did, rather
      // than to nothing.
      DeliveryMethodRegistry.clear();

      expect(DeliveryMethodRegistry.requiresCarNumber('Car Delivery'), isTrue);
      expect(DeliveryMethodRegistry.requiresAddress('Door Delivery'), isTrue);
      expect(DeliveryMethodRegistry.requiresCarNumber('Store Takeaway'),
          isFalse);
    });

    test('an unknown string demands nothing rather than throwing', () {
      expect(DeliveryMethodRegistry.requiresCarNumber(null), isFalse);
      expect(DeliveryMethodRegistry.requiresCarNumber(''), isFalse);
      expect(DeliveryMethodRegistry.kindOf('nonsense'), DeliveryKind.other);
    });
  });

  group('cache round trip', () {
    test('toJson/fromMap preserves every new field', () {
      final original = DeliveryMethod.fromMap({
        'id': '2',
        'name': 'توصيل بالسيارة',
        'code': 'car-delivery',
        'translations': {'en': 'Car Delivery', 'ar': 'توصيل بالسيارة'},
        'requires_car_number': true,
        'requires_address': false,
        'icon_key': 'car',
        'sort_order': 3,
        'status': 'Y',
        'prices': [
          {'id': '9', 'delivery_method_id': '2', 'price': '5.5'}
        ],
      });

      final restored = DeliveryMethod.fromMap(original.toJson());

      expect(restored.id, original.id);
      expect(restored.code, original.code);
      expect(restored.translations, original.translations);
      expect(restored.requiresCarNumber, isTrue);
      expect(restored.requiresAddress, isFalse);
      expect(restored.iconKey, 'car');
      expect(restored.sortOrder, 3);
      expect(restored.enabled, isTrue);
      expect(restored.prices.single.price, 5.5);
      expect(restored.kind, DeliveryKind.carDelivery);
    });
  });
}
