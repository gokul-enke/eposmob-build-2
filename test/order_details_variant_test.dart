import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/list_sales_return_items.dart';

void main() {
  group('OrderDetailsModelDataCartItem variant parsing', () {
    test('parses product_variant_id and variant_attributes as a Map', () {
      final item = OrderDetailsModelDataCartItem.fromJson({
        'id': 1,
        'product_id': 30,
        'product_name': 'Cotton T-Shirt',
        'quantity': '2',
        'unit_price': 549,
        'mrp': 599,
        'total_price': 1098,
        'product_variant_id': 41,
        'variant_attributes': {'COLOR': 'Red', 'SIZE': 'L'},
      });

      expect(item.productVariantId, 41);
      expect(item.variantAttributes, {'COLOR': 'Red', 'SIZE': 'L'});
      expect(item.formattedVariantAttributes, 'Red | L');
      expect(item.displayName, 'Cotton T-Shirt (Red | L)');
    });

    test('parses variant_attributes when arriving as a JSON string', () {
      final item = OrderDetailsModelDataCartItem.fromJson({
        'id': 1,
        'product_id': 30,
        'product_name': 'Cotton T-Shirt',
        'quantity': '2',
        'unit_price': 549,
        'mrp': 599,
        'total_price': 1098,
        'product_variant_id': 41,
        'variant_attributes': '{"COLOR":"Red","SIZE":"L"}',
      });

      expect(item.productVariantId, 41);
      expect(item.variantAttributes, {'COLOR': 'Red', 'SIZE': 'L'});
      expect(item.formattedVariantAttributes, 'Red | L');
      expect(item.displayName, 'Cotton T-Shirt (Red | L)');
    });

    test('handles missing / null variant fields (plain product)', () {
      final item = OrderDetailsModelDataCartItem.fromJson({
        'id': 1,
        'product_id': 30,
        'product_name': 'Plain Product',
        'quantity': '1',
        'unit_price': 100,
        'mrp': 100,
        'total_price': 100,
      });

      expect(item.productVariantId, isNull);
      expect(item.variantAttributes, isNull);
      expect(item.formattedVariantAttributes, '');
      expect(item.displayName, 'Plain Product');
    });

    test('treats empty variant_attributes map/string as no attributes', () {
      final emptyMap = OrderDetailsModelDataCartItem.fromJson({
        'product_name': 'p',
        'quantity': '1',
        'unit_price': 1,
        'mrp': 1,
        'total_price': 1,
        'variant_attributes': {},
      });
      final emptyString = OrderDetailsModelDataCartItem.fromJson({
        'product_name': 'p',
        'quantity': '1',
        'unit_price': 1,
        'mrp': 1,
        'total_price': 1,
        'variant_attributes': '',
      });
      final badString = OrderDetailsModelDataCartItem.fromJson({
        'product_name': 'p',
        'quantity': '1',
        'unit_price': 1,
        'mrp': 1,
        'total_price': 1,
        'variant_attributes': 'not-json',
      });

      expect(emptyMap.variantAttributes, isNull);
      expect(emptyString.variantAttributes, isNull);
      expect(badString.variantAttributes, isNull);
    });

    test('toJson round-trips variant fields', () {
      final item = OrderDetailsModelDataCartItem.fromJson({
        'product_name': 'p',
        'quantity': '1',
        'unit_price': 1,
        'mrp': 1,
        'total_price': 1,
        'product_variant_id': 7,
        'variant_attributes': {'COLOR': 'Blue'},
      });

      final json = item.toJson();
      expect(json['product_variant_id'], 7);
      expect(json['variant_attributes'], {'COLOR': 'Blue'});
    });
  });

  group('OrderReturnItem variant parsing', () {
    test('parses variant attributes for return items', () {
      final item = OrderReturnItem.fromJson({
        'id': 5,
        'product_name': 'Cotton T-Shirt',
        'quantity': 1,
        'reason': 'Damaged',
        'product_variant_id': 41,
        'variant_attributes': {'COLOR': 'Red', 'SIZE': 'L'},
      });

      expect(item.productVariantId, 41);
      expect(item.formattedVariantAttributes, 'Red | L');
    });
  });

  group('SalesReturnCart variant parsing', () {
    test('parses variant attributes (map form)', () {
      final item = SalesReturnCart.fromJson({
        'cart_item_id': 1,
        'return_order_id': 2,
        'product_name': 'Cotton T-Shirt',
        'quantity': '2',
        'unit_price': 549,
        'total_price': 1098,
        'returned_quantity': 0,
        'returned_total': '0',
        'is_returned': false,
        'product_variant_id': 41,
        'variant_attributes': {'COLOR': 'Red', 'SIZE': 'L'},
      });

      expect(item.productVariantId, 41);
      expect(item.formattedVariantAttributes, 'Red | L');
    });

    test('parses variant attributes (string form) and plain product', () {
      final variant = SalesReturnCart.fromJson({
        'cart_item_id': 1,
        'return_order_id': 2,
        'product_name': 'Cotton T-Shirt',
        'quantity': '2',
        'unit_price': 549,
        'total_price': 1098,
        'returned_quantity': 0,
        'returned_total': '0',
        'is_returned': false,
        'variant_attributes': '{"COLOR":"Blue"}',
      });
      final plain = SalesReturnCart.fromJson({
        'cart_item_id': 1,
        'return_order_id': 2,
        'product_name': 'Plain',
        'quantity': '2',
        'unit_price': 549,
        'total_price': 1098,
        'returned_quantity': 0,
        'returned_total': '0',
        'is_returned': false,
      });

      expect(variant.formattedVariantAttributes, 'Blue');
      expect(plain.productVariantId, isNull);
      expect(plain.formattedVariantAttributes, '');
    });
  });
}
