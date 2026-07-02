/// P0.8 — mobile checkout `items[]` payload contract for mixed carts.
///
/// [CheckoutService.confirmOrder] calls [LocalProductProvider.buildOrderItemsPayload]
/// before [CartProvider.addToOrderAPI]. This test pins the per-line key shape for
/// plain, variant, sale-unit, and variant+sale-unit rows — same contract exercised
/// in `variant_payload_test.dart` and `sale_unit_payload_test.dart`, but through the
/// provider path used at confirm time.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

const _baseLineKeys = {'product_id', 'quantity', 'price', 'mrp', 'stock_id'};
const _saleUnitKeys = {'sale_unit_id', 'product_sale_unit_id'};
const _variantKey = 'product_variant_id';

void _expectBaseLineShape(Map<String, dynamic> line) {
  expect(line.keys.toSet().containsAll(_baseLineKeys), isTrue);
  expect(line['product_id'], isA<int>());
  expect(line['quantity'], isA<num>());
  expect(line['price'], isA<num>());
  expect(line['mrp'], isA<num>());
}

GetProduct _plainProduct() {
  return GetProduct(
    productId: 1,
    productName: 'Plain SKU',
    unit: 'PCS',
    price: ProductPrice(price: '10'),
    mrp: '12',
  );
}

GetProduct _variantProduct() {
  return GetProduct(
    productId: 2,
    productName: 'Variant SKU',
    unit: 'PCS',
    price: ProductPrice(price: '100'),
    mrp: '120',
    variants: [
      ProductVariant(
        id: 201,
        price: 110,
        attributes: const {'COLOR': 'Red'},
      ),
    ],
  );
}

GetProduct _saleUnitProduct() {
  return GetProduct(
    productId: 3,
    productName: 'Case SKU',
    unit: 'PCS',
    price: ProductPrice(price: '10'),
    mrp: '12',
    saleUnits: [
      SaleUnit(
        id: 10,
        unitName: 'CASE',
        conversionRate: '12',
        barcode: 'CASE3',
      ),
    ],
  );
}

GetProduct _variantAndSaleUnitProduct() {
  return GetProduct(
    productId: 4,
    productName: 'Combo SKU',
    unit: 'PCS',
    price: ProductPrice(price: '100'),
    mrp: '120',
    saleUnits: [
      SaleUnit(
        id: 20,
        unitName: 'CASE',
        conversionRate: '6',
        barcode: 'CASE4',
      ),
    ],
    variants: [
      ProductVariant(
        id: 301,
        price: 115,
        attributes: const {'COLOR': 'Blue'},
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_checkout_payload_');
    Hive.init(hiveDir.path);

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveStringValueAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveLocalCartItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveSavedOrderAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveProductAdapter());
    }

    await Hive.openBox<HiveProduct>('products');
    await Hive.openBox<HiveLocalCartItem>('cart_items');
    await Hive.openBox<HiveSavedOrder>('saved_orders');
    await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  group('P0.8 mobile checkout items payload contract', () {
    test('mixed cart emits correct keys per line type via buildOrderItemsPayload',
        () {
      final provider = LocalProductProvider()..setStockEnabled(false);

      provider.addProduct(_plainProduct());
      provider.addProduct(_variantProduct());
      provider.addProduct(_saleUnitProduct());
      provider.addProduct(_variantAndSaleUnitProduct());

      provider.addToCart(product: _plainProduct(), quantity: 2, price: 10, mrp: 12);
      provider.addToCart(
        product: _variantProduct(),
        quantity: 1,
        price: 110,
        mrp: 120,
        variantId: 201,
        variantAttributes: const {'COLOR': 'Red'},
      );
      provider.addToCart(
        product: _saleUnitProduct(),
        quantity: 24,
        price: 10,
        mrp: 12,
        saleUnitId: 10,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 12,
      );
      provider.addToCart(
        product: _variantAndSaleUnitProduct(),
        quantity: 12,
        price: 10,
        mrp: 12,
        variantId: 301,
        variantAttributes: const {'COLOR': 'Blue'},
        saleUnitId: 20,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 6,
      );

      final payload = provider.buildOrderItemsPayload();

      expect(payload, hasLength(4));

      final plain = payload.firstWhere((line) => line['product_id'] == 1);
      _expectBaseLineShape(plain);
      expect(plain['quantity'], 2);
      expect(plain.containsKey(_variantKey), isFalse);
      expect(plain.keys.toSet().intersection(_saleUnitKeys), isEmpty);

      final variant = payload.firstWhere((line) => line['product_id'] == 2);
      _expectBaseLineShape(variant);
      expect(variant[_variantKey], 201);
      expect(variant.keys.toSet().intersection(_saleUnitKeys), isEmpty);

      final saleUnit = payload.firstWhere((line) => line['product_id'] == 3);
      _expectBaseLineShape(saleUnit);
      expect(saleUnit.keys.toSet().containsAll(_saleUnitKeys), isTrue);
      expect(saleUnit['sale_unit_id'], 10);
      expect(saleUnit['product_sale_unit_id'], 10);
      expect(saleUnit['quantity'], 2);
      expect(saleUnit['price'], 120.0);
      expect(saleUnit.containsKey(_variantKey), isFalse);

      final combo = payload.firstWhere((line) => line['product_id'] == 4);
      _expectBaseLineShape(combo);
      expect(combo[_variantKey], 301);
      expect(combo.keys.toSet().containsAll(_saleUnitKeys), isTrue);
      expect(combo['sale_unit_id'], 20);
      expect(combo['quantity'], 2);
      expect(combo['price'], 60.0);
    });

    test('provider path matches static buildOrderItemsPayloadFrom for same cart',
        () {
      final items = [
        LocalCartItem(
          product: _plainProduct(),
          quantity: 1,
          price: 10,
          mrp: 12,
        ),
        LocalCartItem(
          product: _variantProduct(),
          quantity: 1,
          price: 110,
          mrp: 120,
          variantId: 201,
          variantAttributes: const {'COLOR': 'Red'},
        ),
        LocalCartItem(
          product: _saleUnitProduct(),
          quantity: 12,
          price: 10,
          mrp: 12,
          saleUnitId: 10,
          saleUnitName: 'CASE',
          saleUnitConversionRate: 12,
        ),
      ];

      final provider = LocalProductProvider()..setStockEnabled(false);
      for (final product in [
        _plainProduct(),
        _variantProduct(),
        _saleUnitProduct(),
      ]) {
        provider.addProduct(product);
      }
      provider.addToCart(
        product: items[0].product,
        quantity: items[0].quantity,
        price: items[0].price!,
        mrp: items[0].mrp!,
      );
      provider.addToCart(
        product: items[1].product,
        quantity: items[1].quantity,
        price: items[1].price!,
        mrp: items[1].mrp!,
        variantId: items[1].variantId,
        variantAttributes: items[1].variantAttributes,
      );
      provider.addToCart(
        product: items[2].product,
        quantity: items[2].quantity,
        price: items[2].price!,
        mrp: items[2].mrp!,
        saleUnitId: items[2].saleUnitId,
        saleUnitName: items[2].saleUnitName,
        saleUnitConversionRate: items[2].saleUnitConversionRate,
      );

      final fromProvider = provider.buildOrderItemsPayload();
      final fromStatic =
          LocalProductProvider.buildOrderItemsPayloadFrom(items);

      // Provider iterates cart in insertion order (newest-first in storage);
      // compare semantically — CartProvider reverses again before API submit.
      expect(
        fromProvider.map((line) => line['product_id']).toSet(),
        fromStatic.map((line) => line['product_id']).toSet(),
      );
      for (final productId in [1, 2, 3]) {
        expect(
          fromProvider.firstWhere((line) => line['product_id'] == productId),
          fromStatic.firstWhere((line) => line['product_id'] == productId),
        );
      }
    });

    test('stock-split lines preserve variant and sale-unit keys on every row', () {
      final item = LocalCartItem(
        product: _variantAndSaleUnitProduct(),
        quantity: 12,
        price: 10,
        mrp: 12,
        variantId: 301,
        variantAttributes: const {'COLOR': 'Blue'},
        saleUnitId: 20,
        saleUnitName: 'CASE',
        saleUnitConversionRate: 6,
        stockReservations: [
          StockReservation(stockId: 1, quantity: 6),
          StockReservation(stockId: 2, quantity: 6),
        ],
      );

      final payload = LocalProductProvider.buildOrderItemsPayloadFrom([item]);

      expect(payload, hasLength(2));
      for (final line in payload) {
        _expectBaseLineShape(line);
        expect(line[_variantKey], 301);
        expect(line.keys.toSet().containsAll(_saleUnitKeys), isTrue);
        expect(line['sale_unit_id'], 20);
      }
      expect(payload.map((line) => line['stock_id']).toList(), [1, 2]);
    });
  });
}
