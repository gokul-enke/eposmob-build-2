import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_wtd_test_');
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
    SharedPreferences.setMockInitialValues({
      'general_stock_enabled': true,
    });

    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  GetProduct buildProduct({
    required int productId,
    String basePrice = '10',
    String mrp = '12',
    List<Stock> stocks = const [],
    List<ProductTax> taxes = const [],
  }) {
    return GetProduct(
      productId: productId,
      productName: 'Product $productId',
      price: ProductPrice(price: basePrice),
      mrp: mrp,
      purchasePrice: '8',
      unit: 'PCS',
      stock: stocks,
      taxes: taxes,
    );
  }

  Stock buildStock({
    required int id,
    required num quantity,
    required String price,
    required String mrp,
    String purchasePrice = '8',
    int storeId = 1,
    String storeName = 'Main Store',
    String taxRate = '5',
    String unit = 'PCS',
    String hsnCode = 'HSN-1',
    String? wholesalePrice,
    int? wholesaleMinUnit,
  }) {
    return Stock(
      id: id,
      productId: 1,
      storeId: storeId,
      storeName: storeName,
      quantity: quantity,
      price: price,
      mrp: mrp,
      purchasePrice: purchasePrice,
      taxRate: taxRate,
      unit: unit,
      hsnCode: hsnCode,
      wholesalePrice: wholesalePrice,
      wholesaleMinUnit: wholesaleMinUnit,
    );
  }

  group('Wholesale Pricing', () {
    test('uses regular price when quantity is below wholesale threshold', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '10',
        mrp: '12',
        wholesalePrice: '8',
        wholesaleMinUnit: 5,
      );
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 3, selectedStock: stock);
      expect(provider.cartItems.first.price, 10.0);
    });

    test('uses wholesale price when quantity meets exact threshold', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '10',
        mrp: '12',
        wholesalePrice: '8',
        wholesaleMinUnit: 5,
      );
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 5, selectedStock: stock);
      expect(provider.cartItems.first.price, 8.0);
    });

    test('uses wholesale price when quantity exceeds threshold', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '10',
        mrp: '12',
        wholesalePrice: '8',
        wholesaleMinUnit: 5,
      );
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 8, selectedStock: stock);
      expect(provider.cartItems.first.price, 8.0);
    });

    test('falls back to regular price when wholesalePrice is null', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '10',
        mrp: '12',
        wholesaleMinUnit: 5,
      );
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 10, selectedStock: stock);
      expect(provider.cartItems.first.price, 10.0);
    });

    test('falls back to regular price when wholesaleMinUnit is null', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '10',
        mrp: '12',
        wholesalePrice: '8',
      );
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 10, selectedStock: stock);
      expect(provider.cartItems.first.price, 10.0);
    });

    test('recalculates to wholesale on quantity increase crossing threshold', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '10',
        mrp: '12',
        wholesalePrice: '8',
        wholesaleMinUnit: 5,
      );
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 3, selectedStock: stock);
      expect(provider.cartItems.first.price, 10.0);

      provider.addToCart(product: product, quantity: 3, selectedStock: stock);
      expect(provider.cartItems.first.quantity, 6);
      expect(provider.cartItems.first.price, 8.0);
    });

    test('recalculates to regular on quantity decrease below threshold', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '10',
        mrp: '12',
        wholesalePrice: '8',
        wholesaleMinUnit: 5,
      );
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 8, selectedStock: stock);
      expect(provider.cartItems.first.price, 8.0);

      provider.setCartItemQuantity(1, stock, 3);
      expect(provider.cartItems.first.price, 10.0);
    });

    test('preserves manual override when quantity crosses threshold', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '10',
        mrp: '12',
        wholesalePrice: '8',
        wholesaleMinUnit: 5,
      );
      final product = buildProduct(productId: 1, stocks: [stock]);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 3, selectedStock: stock);
      provider.updateItemPrice(1, stock, 9.5);
      expect(provider.cartItems.first.isManualPriceOverride, isTrue);

      provider.addToCart(product: product, quantity: 3, selectedStock: stock);
      expect(provider.cartItems.first.quantity, 6);
      expect(provider.cartItems.first.price, 9.5);
    });
  });

  group('Tax Calculation', () {
    test('uses 0 tax when no taxes defined', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1);
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);
      expect(provider.taxBreakdown, isEmpty);
      expect(provider.cartItems.first.taxRate, 0.0);
      expect(provider.cartItems.first.taxAmount, 0.0);
    });

    test('distributes multi-tax proportionally when rates match', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(
        productId: 1,
        basePrice: '118',
        mrp: '120',
        taxes: [
          ProductTax(name: 'CGST', rate: '9'),
          ProductTax(name: 'SGST', rate: '9'),
        ],
      );
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);

      final breakdown = provider.taxBreakdown;
      expect(breakdown, isNotEmpty);
      final totalTax = breakdown.values.fold<double>(0.0, (sum, v) => sum + v);
      // Item total = 118, taxRate = 18%, extracted tax = 118 * 18 / 118 = 18
      expect(totalTax, closeTo(18.0, 0.01));
      expect(breakdown.length, 2);
    });

    test('falls back to product tax name when cart tax rate mismatches product', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(
        productId: 1,
        basePrice: '100',
        taxes: [
          ProductTax(name: 'GST', rate: '18'),
        ],
      );
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);
      // Override cart tax rate to mismatch product
      provider.updateItemTax(1, null, 12.0);

      final breakdown = provider.taxBreakdown;
      expect(breakdown, isNotEmpty);
      // Fallback branch uses the product's single tax name for the key,
      // but computes amount using the cart's currentTaxRate (12).
      expect(
        breakdown.keys.any((k) => k.contains('GST')),
        isTrue,
        reason: 'Expected a key containing GST, got $breakdown',
      );
      // Tax amount = 100 * 12 / 112 ≈ 10.714
      final totalTax = breakdown.values.fold<double>(0.0, (sum, v) => sum + v);
      expect(totalTax, closeTo(10.714, 0.01));
    });

    test('uses single tax name when exactly one tax exists and rate matches', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(
        productId: 1,
        basePrice: '100',
        taxes: [
          ProductTax(name: 'GST', rate: '18'),
        ],
      );
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);

      final breakdown = provider.taxBreakdown;
      expect(breakdown, isNotEmpty);
      expect(breakdown.length, 1);
      // Key should contain the tax name GST
      expect(
        breakdown.keys.first.contains('GST'),
        isTrue,
        reason: 'Expected key to contain GST, got ${breakdown.keys.first}',
      );
    });

    test('uses stock-level tax rate when present', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      final stock = buildStock(
        id: 1,
        quantity: 10,
        price: '100',
        mrp: '110',
        taxRate: '12',
      );
      final product = buildProduct(
        productId: 1,
        stocks: [stock],
        taxes: [
          ProductTax(name: 'GST', rate: '18'),
        ],
      );
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1, selectedStock: stock);
      expect(provider.cartItems.first.taxRate, 12.0);
    });
  });

  group('Discounts', () {
    test('flat discount reduces subtotal correctly', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1, basePrice: '100', mrp: '100');
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 5); // subtotal 500
      provider.applyDiscount(flatDiscount: 50, percentageDiscount: 0);
      expect(provider.cartTotal, 450.0);
      expect(provider.priceSummary!.flatDiscount, 50.0);
    });

    test('percentage discount reduces subtotal correctly', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1, basePrice: '100', mrp: '100');
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 5); // subtotal 500
      provider.applyDiscount(flatDiscount: 0, percentageDiscount: 10);
      expect(provider.cartTotal, 450.0);
      expect(provider.priceSummary!.percentageDiscount, 50.0);
    });

    test('combined discounts sum correctly', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1, basePrice: '100', mrp: '100');
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 5); // subtotal 500
      provider.applyDiscount(flatDiscount: 50, percentageDiscount: 10);
      // 50 + 10% of 500 = 100
      expect(provider.cartTotal, 400.0);
      expect(provider.priceSummary!.discount, 100.0);
    });

    test('total discount is capped at subtotal', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1, basePrice: '100', mrp: '100');
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1); // subtotal 100
      provider.applyDiscount(flatDiscount: 150, percentageDiscount: 0);
      expect(provider.cartTotal, 0.0);
      expect(provider.priceSummary!.discount, 100.0);
    });

    test('clearCart clears discounts', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);
      final product = buildProduct(productId: 1, basePrice: '100', mrp: '100');
      provider.initializeProducts([product]);
      provider.addToCart(product: product, quantity: 1);
      provider.applyDiscount(flatDiscount: 10, percentageDiscount: 5);
      provider.clearCart();
      expect(provider.cartItems, isEmpty);
      expect(provider.getCurrentDiscount()['flatDiscount'], 0.0);
      expect(provider.getCurrentDiscount()['percentageDiscount'], 0.0);
    });
  });
}
