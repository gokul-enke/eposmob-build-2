import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

void main() {
  group('LocalCartItem Sale Unit Math', () {
    GetProduct buildProduct() => GetProduct(
          productId: 1,
          productName: 'Test Product',
          unit: 'PCS',
        );

    test('hasSaleUnit is false when conversion rate is null', () {
      final item = LocalCartItem(product: buildProduct());
      expect(item.hasSaleUnit, isFalse);
    });

    test('hasSaleUnit is false when conversion rate is 0', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 0,
      );
      expect(item.hasSaleUnit, isFalse);
    });

    test('hasSaleUnit is true when all fields are set positively', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );
      expect(item.hasSaleUnit, isTrue);
    });

    test('toDisplayQuantity divides base by conversion rate', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitConversionRate: 12,
      );
      expect(item.toDisplayQuantity(24), 2);
      expect(item.toDisplayQuantity(12), 1);
      expect(item.toDisplayQuantity(6), 0.5);
    });

    test('toBaseQuantity multiplies display by conversion rate', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitConversionRate: 12,
      );
      expect(item.toBaseQuantity(2), 24);
      expect(item.toBaseQuantity(1), 12);
      expect(item.toBaseQuantity(0.5), 6);
    });

    test('toDisplayAmount multiplies base amount by conversion rate', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitConversionRate: 12,
      );
      expect(item.toDisplayAmount(10.0), 120.0);
      expect(item.toDisplayAmount(null), isNull);
    });

    test('toBaseAmount divides display amount by conversion rate', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitConversionRate: 12,
      );
      expect(item.toBaseAmount(120.0), 10.0);
      expect(item.toBaseAmount(null), isNull);
    });

    test('canUseSaleUnitPayloadFor returns true for clean multiples', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitConversionRate: 12,
      );
      expect(item.canUseSaleUnitPayloadFor(24), isTrue);
      expect(item.canUseSaleUnitPayloadFor(12), isTrue);
      expect(item.canUseSaleUnitPayloadFor(36), isTrue);
    });

    test(
        'canUseSaleUnitPayloadFor rejects partial packs for whole-number products',
        () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitConversionRate: 12,
      );
      expect(item.canUseSaleUnitPayloadFor(13), isFalse);
      expect(item.canUseSaleUnitPayloadFor(5), isFalse);
    });

    test('canUseSaleUnitPayloadFor returns false without sale unit', () {
      final item = LocalCartItem(product: buildProduct());
      expect(item.canUseSaleUnitPayloadFor(12), isFalse);
    });

    test('displayQuantity returns normalized integer when close to whole', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        quantity: 24,
        saleUnitConversionRate: 12,
      );
      expect(item.displayQuantity, 2);
    });

    test('displayUnitName returns sale unit name when set', () {
      final item = LocalCartItem(
        product: buildProduct(),
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );
      expect(item.displayUnitName, 'CASE');
    });

    test('displayUnitName falls back to product unit', () {
      final item = LocalCartItem(product: buildProduct());
      expect(item.displayUnitName, 'PCS');
    });

    test('displayUnitName returns dash when both are empty', () {
      final product = GetProduct(productId: 1, productName: 'X');
      final item = LocalCartItem(product: product);
      expect(item.displayUnitName, '-');
    });
  });

  group('buildOrderItemsPayloadFrom', () {
    GetProduct buildProduct() => GetProduct(
          productId: 1,
          productName: 'Test Product',
          unit: 'PCS',
          price: ProductPrice(price: '10'),
          mrp: '12',
        );

    test('uses display quantity and price for clean sale-unit reservations',
        () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 24,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 24),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload.length, 1);
      expect(payload.first['quantity'], 2); // display
      expect(payload.first['price'], 120.0); // display
      expect(payload.first['mrp'], 144.0); // display
      expect(payload.first['stock_id'], 1);
      expect(payload.first['sale_unit_id'], 10);
    });

    test('splits payload across multiple grouped stock reservations', () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 36,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 24),
          StockReservation(stockId: 2, quantity: 12),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload.length, 2);
      expect(payload[0]['quantity'], 2); // 24/12
      expect(payload[0]['stock_id'], 1);
      expect(payload[0]['sale_unit_id'], 10);

      expect(payload[1]['quantity'], 1); // 12/12
      expect(payload[1]['stock_id'], 2);
      expect(payload[1]['sale_unit_id'], 10);
    });

    test('omits sale_unit_id for base-unit items', () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 5,
        price: 10,
        mrp: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 5),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload.length, 1);
      expect(payload.first['quantity'], 5);
      expect(payload.first.containsKey('sale_unit_id'), isFalse);
    });

    test('filters out zero-quantity payload lines', () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 0,
        price: 10,
        mrp: 12,
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload, isEmpty);
    });

    test('includes stock_id null for unreserved overflow quantity', () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 10,
        price: 10,
        mrp: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 6),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload.length, 2);
      expect(payload[0]['stock_id'], 1);
      expect(payload[0]['quantity'], 6);
      expect(payload[1]['stock_id'], isNull);
      expect(payload[1]['quantity'], 4);
    });

    test(
        'empty reservations and no stock selected sends one line with null stock_id',
        () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 3,
        price: 10,
        mrp: 12,
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload.length, 1);
      expect(payload.first['stock_id'], isNull);
      expect(payload.first['quantity'], 3);
    });

    test('payload falls back to base units for a partial whole-number pack',
        () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 13,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 13),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);
      expect(payload.length, 1);
      expect(payload.first['quantity'], 13);
      expect(payload.first['price'], 10.0);
      expect(payload.first.containsKey('sale_unit_id'), isFalse);
    });

    test('uses base units when 2 CASE is split as 16 reserved and 8 unreserved',
        () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 24,
        price: 10,
        mrp: 12,
        selectedStock: Stock(id: 1),
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 16),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload, [
        {
          'product_id': 1,
          'quantity': 16,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 1,
          'warranty_enabled': false,
        },
        {
          'product_id': 1,
          'quantity': 8,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': null,
          'warranty_enabled': false,
        },
      ]);
    });

    test('current payload for 2 CASE fully reserved from one stock row', () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 24,
        price: 10,
        mrp: 12,
        selectedStock: Stock(id: 1),
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 24),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload, [
        {
          'product_id': 1,
          'quantity': 2,
          'price': 120.0,
          'mrp': 144.0,
          'stock_id': 1,
          'sale_unit_id': 10,
          'product_sale_unit_id': 10,
          'warranty_enabled': false,
        },
      ]);
    });

    test('uses base units when 1 CASE is split as 4 reserved and 8 unreserved',
        () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 12,
        price: 10,
        mrp: 12,
        selectedStock: Stock(id: 1),
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 4),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload, [
        {
          'product_id': 1,
          'quantity': 4,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 1,
          'warranty_enabled': false,
        },
        {
          'product_id': 1,
          'quantity': 8,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': null,
          'warranty_enabled': false,
        },
      ]);
    });

    test(
        '25-piece PACK with only 6 reserved never emits fractional PC quantity',
        () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 25,
        price: 10,
        mrp: 12,
        selectedStock: Stock(id: 1),
        saleUnitId: 10,
        saleUnitName: 'PACK',
        saleUnitConversionRate: 25,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 6),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload, [
        {
          'product_id': 1,
          'quantity': 6,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 1,
          'warranty_enabled': false,
        },
        {
          'product_id': 1,
          'quantity': 19,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': null,
          'warranty_enabled': false,
        },
      ]);
      expect(
        payload.every((line) => (line['quantity'] as num) % 1 == 0),
        isTrue,
      );
    });

    test('current payload for blocked stock case is empty only if item absent',
        () {
      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([]);

      expect(payload, isEmpty);
    });

    test('floors fractional base-unit reservation lines for non-decimal units',
        () {
      // Simulates legacy reservations persisted before the splitter fix:
      // a PCS item split as 1.3 + 0.7 across two batches.
      final item = LocalCartItem(
        product: buildProduct(), // unit PCS
        quantity: 2,
        price: 10,
        mrp: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 1.3),
          StockReservation(stockId: 2, quantity: 0.7),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      // 1.3 -> 1 (line kept), 0.7 -> 0 (line dropped by the > 0 filter).
      expect(payload, [
        {
          'product_id': 1,
          'quantity': 1,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 1,
          'warranty_enabled': false,
        },
      ]);
    });

    test('floors fractional unreserved overflow for non-decimal units', () {
      final item = LocalCartItem(
        product: buildProduct(), // unit PCS
        quantity: 2,
        price: 10,
        mrp: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 0.5),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      // reserved 0.5 -> floored to 0 (dropped); unreserved 1.5 -> floored to 1.
      expect(payload, [
        {
          'product_id': 1,
          'quantity': 1,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': null,
          'warranty_enabled': false,
        },
      ]);
    });

    test('preserves fractional base-unit lines for decimal units (KG)', () {
      final kgProduct = GetProduct(
        productId: 2,
        productName: 'Loose Rice',
        unit: 'KG',
        price: ProductPrice(price: '10'),
        mrp: '12',
      );
      final item = LocalCartItem(
        product: kgProduct,
        quantity: 2,
        price: 10,
        mrp: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 1.3),
          StockReservation(stockId: 2, quantity: 0.7),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload.map((line) => line['quantity']).toList(), [1.3, 0.7]);
    });

    test('uses base units when 2 CASE is split across partial stock rows', () {
      final item = LocalCartItem(
        product: buildProduct(),
        quantity: 24,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 16),
          StockReservation(stockId: 2, quantity: 8),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload, [
        {
          'product_id': 1,
          'quantity': 16,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 1,
          'warranty_enabled': false,
        },
        {
          'product_id': 1,
          'quantity': 8,
          'price': 10.0,
          'mrp': 12.0,
          'stock_id': 2,
          'warranty_enabled': false,
        },
      ]);
    });
  });
}
