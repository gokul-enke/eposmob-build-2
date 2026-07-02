import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

void main() {
  group('SaleUnit.fromJson', () {
    test('parses resolved_price and conversionRateValue', () {
      final unit = SaleUnit.fromJson({
        'id': 100,
        'unit_id': 1991,
        'unit_name': 'DZ',
        'conversion_rate': '12.00',
        'price': 900.0,
        'resolved_price': 1000.0,
      });

      expect(unit.id, 100);
      expect(unit.price, 900.0);
      expect(unit.resolvedPrice, 1000.0);
      expect(unit.conversionRateValue, 12.0);
    });

    test('resolved_price null when absent', () {
      final unit = SaleUnit.fromJson({
        'id': 100,
        'conversion_rate': '12',
      });
      expect(unit.resolvedPrice, isNull);
      expect(unit.conversionRateValue, 12.0);
    });

    test('parses resolved_price from string', () {
      final unit = SaleUnit.fromJson({
        'id': 100,
        'conversion_rate': '12',
        'resolved_price': '1000.5',
      });
      expect(unit.resolvedPrice, 1000.5);
    });

    test('conversionRateValue is null for 0, negative, or invalid', () {
      expect(SaleUnit(conversionRate: '0').conversionRateValue, isNull);
      expect(SaleUnit(conversionRate: '-5').conversionRateValue, isNull);
      expect(SaleUnit(conversionRate: 'abc').conversionRateValue, isNull);
      expect(SaleUnit(conversionRate: null).conversionRateValue, isNull);
    });
  });

  group('Stock.unitPriceOverrides parsing', () {
    test('parses object form {"100": 1000.0}', () {
      final stock = Stock.fromJson({
        'id': 3279,
        'unit_prices': {'100': 1000.0, '101': 2000.0},
      });

      expect(stock.unitPriceOverrides, {100: 1000.0, 101: 2000.0});
      expect(stock.unitPriceOverrideFor(100), 1000.0);
      expect(stock.unitPriceOverrideFor(101), 2000.0);
      expect(stock.unitPriceOverrideFor(999), isNull);
      expect(stock.unitPriceOverrideFor(null), isNull);
    });

    test('parses list-of-entries form', () {
      final stock = Stock.fromJson({
        'id': 3279,
        'unit_prices': [
          {'sale_unit_id': 100, 'price': 1000.0},
          {'sale_unit_id': 101, 'price': 2000.0},
        ],
      });

      expect(stock.unitPriceOverrideFor(100), 1000.0);
      expect(stock.unitPriceOverrideFor(101), 2000.0);
      // The legacy List field is still retained for the list form.
      expect(stock.unitPrices, isNotNull);
    });

    test('list form supports alternate key names (id/unit_price)', () {
      final stock = Stock.fromJson({
        'id': 3279,
        'unit_prices': [
          {'id': 100, 'unit_price': 1500.0},
        ],
      });
      expect(stock.unitPriceOverrideFor(100), 1500.0);
    });

    test('overrides null when unit_prices absent', () {
      final stock = Stock.fromJson({'id': 1});
      expect(stock.unitPriceOverrides, isNull);
      expect(stock.unitPriceOverrideFor(100), isNull);
    });

    test('string prices in object form are parsed', () {
      final stock = Stock.fromJson({
        'id': 1,
        'unit_prices': {'100': '1000.0'},
      });
      expect(stock.unitPriceOverrideFor(100), 1000.0);
    });
  });

  group('Price resolution chain (through addToCart)', () {
    late Directory hiveDir;

    setUpAll(() async {
      hiveDir = await Directory.systemTemp.createTemp('epos_multi_unit_price_');
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
      SharedPreferences.setMockInitialValues({'general_stock_enabled': false});
      await Hive.box<HiveProduct>('products').clear();
      await Hive.box<HiveLocalCartItem>('cart_items').clear();
      await Hive.box<HiveSavedOrder>('saved_orders').clear();
      await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
    });

    tearDown(awaitPendingHiveBoxWrites);
    tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

    GetProduct buildProduct({
      String basePrice = '100',
      double? masterDozenPrice,
      double? resolvedDozenPrice,
    }) {
      return GetProduct(
        productId: 1,
        productName: 'Nivea Men',
        unit: 'PC',
        price: ProductPrice(price: basePrice),
        mrp: '120',
        saleUnits: [
          SaleUnit(
            id: 100,
            unitId: 1991,
            unitName: 'DZ',
            conversionRate: '12',
            price: masterDozenPrice,
            resolvedPrice: resolvedDozenPrice,
          ),
        ],
      );
    }

    LocalProductProvider newProvider(GetProduct product) {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      provider.initializeProducts([product]);
      return provider;
    }

    test('master price 900 for Dozen -> stored base 75, display back to 900',
        () {
      final product = buildProduct(masterDozenPrice: 900);
      final provider = newProvider(product);

      provider.addToCart(
        product: product,
        quantity: 12,
        saleUnitId: 100,
        saleUnitName: 'DZ',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      // Per-base price: 900 / 12 = 75.
      expect(item.price, closeTo(75, 0.0001));
      // Display multiplies back to the per-Dozen price the cashier expects.
      expect(item.displayPrice, closeTo(900, 0.0001));
    });

    test('batch override wins over master price', () {
      final product = buildProduct(masterDozenPrice: 900);
      final stock = Stock(
        id: 3279,
        unitPriceOverrides: {100: 1000.0},
      );
      final provider = newProvider(product);

      provider.addToCart(
        product: product,
        quantity: 12,
        selectedStock: stock,
        saleUnitId: 100,
        saleUnitName: 'DZ',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      // 1000 / 12 base, displays back to 1000.
      expect(item.price, closeTo(1000 / 12, 0.0001));
      expect(item.displayPrice, closeTo(1000, 0.0001));
    });

    test('resolved_price used when no override and no master price', () {
      final product = buildProduct(resolvedDozenPrice: 960);
      final provider = newProvider(product);

      provider.addToCart(
        product: product,
        quantity: 12,
        saleUnitId: 100,
        saleUnitName: 'DZ',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      expect(item.price, closeTo(80, 0.0001));
      expect(item.displayPrice, closeTo(960, 0.0001));
    });

    test('auto: no sale-unit price -> base retail price per base unit', () {
      final product = buildProduct(); // no master/resolved
      final provider = newProvider(product);

      provider.addToCart(
        product: product,
        quantity: 12,
        saleUnitId: 100,
        saleUnitName: 'DZ',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      // Falls through to base retail 100 per PC; display = 100 * 12 = 1200.
      expect(item.price, closeTo(100, 0.0001));
      expect(item.displayPrice, closeTo(1200, 0.0001));
    });

    test('override of 0 is ignored, falls to master', () {
      final product = buildProduct(masterDozenPrice: 900);
      final stock = Stock(id: 1, unitPriceOverrides: {100: 0.0});
      final provider = newProvider(product);

      provider.addToCart(
        product: product,
        quantity: 12,
        selectedStock: stock,
        saleUnitId: 100,
        saleUnitName: 'DZ',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      expect(item.price, closeTo(75, 0.0001));
    });

    test('no matching sale unit -> base price (no division applied)', () {
      final product = buildProduct(masterDozenPrice: 900);
      final provider = newProvider(product);

      // saleUnitId 999 has no match on the product.
      provider.addToCart(
        product: product,
        quantity: 1,
        saleUnitId: 999,
      );

      final item = provider.cartItems.single;
      // Falls through to base retail price 100.
      expect(item.price, closeTo(100, 0.0001));
    });

    test('explicit price passed to addToCart is respected (manual override)',
        () {
      final product = buildProduct(masterDozenPrice: 900);
      final provider = newProvider(product);

      provider.addToCart(
        product: product,
        quantity: 12,
        price: 50,
        saleUnitId: 100,
        saleUnitName: 'DZ',
        saleUnitConversionRate: 12,
      );

      final item = provider.cartItems.single;
      expect(item.price, 50);
    });
  });
}
