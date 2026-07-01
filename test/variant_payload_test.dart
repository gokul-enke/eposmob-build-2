/// P-05 slices 4–5 — mobile order payload contract for variant (+ sale-unit) lines.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

GetProduct _productWithVariantAndSaleUnit() {
  return GetProduct(
    productId: 77,
    productName: 'Combo SKU',
    unit: 'PCS',
    price: ProductPrice(price: '100'),
    mrp: '120',
    saleUnits: [
      SaleUnit(
        id: 10,
        unitName: 'CASE',
        conversionRate: '12',
        barcode: 'CASE77',
      ),
    ],
    variants: [
      ProductVariant(
        id: 201,
        price: 110,
        attributes: const {'COLOR': 'Red'},
      ),
      ProductVariant(
        id: 202,
        price: 115,
        attributes: const {'COLOR': 'Blue'},
      ),
    ],
  );
}

void main() {
  group('variant order payload (mobile contract)', () {
    test('includes product_variant_id for variant cart lines', () {
      final product = _productWithVariantAndSaleUnit();
      final item = LocalCartItem(
        product: product,
        quantity: 2,
        price: 110,
        mrp: 120,
        variantId: 201,
        variantAttributes: const {'COLOR': 'Red'},
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload.length, 1);
      expect(payload.first['product_id'], 77);
      expect(payload.first['product_variant_id'], 201);
      expect(payload.first['quantity'], 2);
      expect(payload.first['price'], 110);
      expect(payload.first.containsKey('sale_unit_id'), isFalse);
    });

    test('variant + sale unit emits both product_variant_id and sale_unit_id', () {
      final product = _productWithVariantAndSaleUnit();
      final item = LocalCartItem(
        product: product,
        quantity: 24,
        price: 10,
        mrp: 12,
        variantId: 201,
        variantAttributes: const {'COLOR': 'Red'},
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload.length, 1);
      expect(payload.first['product_variant_id'], 201);
      expect(payload.first['sale_unit_id'], 10);
      expect(payload.first['product_sale_unit_id'], 10);
      expect(payload.first['quantity'], 2);
      expect(payload.first['price'], 120);
    });

    test('different variants on same product produce separate payload lines', () {
      final product = _productWithVariantAndSaleUnit();
      final redLine = LocalCartItem(
        product: product,
        quantity: 1,
        price: 110,
        variantId: 201,
        variantAttributes: const {'COLOR': 'Red'},
      );
      final blueLine = LocalCartItem(
        product: product,
        quantity: 1,
        price: 115,
        variantId: 202,
        variantAttributes: const {'COLOR': 'Blue'},
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom(
        [redLine, blueLine],
      );

      expect(payload.length, 2);
      expect(
        payload.map((line) => line['product_variant_id']).toList(),
        [201, 202],
      );
    });

    test('variant lines with stock reservations include product_variant_id per row',
        () {
      final product = GetProduct(
        productId: 88,
        productName: 'Stocked Variant',
        unit: 'PCS',
        price: ProductPrice(price: '50'),
        variants: [
          ProductVariant(id: 301, attributes: const {'SIZE': 'L'}),
        ],
      );
      final item = LocalCartItem(
        product: product,
        quantity: 3,
        price: 55,
        variantId: 301,
        variantAttributes: const {'SIZE': 'L'},
        stockReservations: [
          StockReservation(stockId: 1, quantity: 2),
          StockReservation(stockId: 2, quantity: 1),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload.length, 2);
      expect(payload.every((line) => line['product_variant_id'] == 301), isTrue);
      expect(payload.map((line) => line['stock_id']).toList(), [1, 2]);
    });
  });

  group('variant + sale unit cart identity', () {
    test('merge key treats variant and sale unit as independent dimensions', () {
      final product = _productWithVariantAndSaleUnit();
      final redLine = LocalCartItem(
        product: product,
        quantity: 12,
        price: 10,
        variantId: 201,
        variantAttributes: const {'COLOR': 'Red'},
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );
      final blueLine = LocalCartItem(
        product: product,
        quantity: 12,
        price: 10,
        variantId: 202,
        variantAttributes: const {'COLOR': 'Blue'},
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom(
        [redLine, blueLine],
      );

      expect(payload.length, 2);
      expect(
        payload.map((line) => line['product_variant_id']).toSet(),
        {201, 202},
      );
      expect(payload.every((line) => line['sale_unit_id'] == 10), isTrue);
    });
  });
}
