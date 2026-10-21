import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_product.dart';

void main() {
  group('GetProduct sku', () {
    test('a numeric SKU from the server is read as text', () {
      final product = GetProduct.fromJson({'product_id': 1, 'sku': 4228});

      expect(product.sku, '4228');
    });

    test('a text SKU is kept and a missing one stays null', () {
      expect(GetProduct.fromJson({'product_id': 1, 'sku': 'SKU-7'}).sku,
          'SKU-7');
      expect(GetProduct.fromJson({'product_id': 1}).sku, isNull);
      expect(GetProduct.fromJson({'product_id': 1, 'sku': null}).sku, isNull);
    });

    test('survives the JSON round trip used to store products in Hive', () {
      final stored = json.encode(
          GetProduct.fromJson({'product_id': 1, 'sku': 4228}).toJson());

      final restored =
          GetProduct.fromJson(json.decode(stored) as Map<String, dynamic>);

      expect(restored.sku, '4228');
    });
  });
}
