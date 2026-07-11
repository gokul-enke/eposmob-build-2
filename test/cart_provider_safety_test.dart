/// Regression coverage for provider-level cart safety:
/// - LocalProductProvider.changeCartItemSaleUnit blocks when the target sale
///   unit would create an unreserved oversell quantity.
/// - LocalProductProvider.addToCart with a non-existent productId (and no
///   product param) no longer throws a StateError; it safely no-ops.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_cart_safety_test_');
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
    // Provider mutations persist through an asynchronous queue. Drain writes
    // from the preceding test before clearing the shared Hive boxes, otherwise
    // a delayed cart save can repopulate them during this test.
    await awaitPendingHiveBoxWrites();
    SharedPreferences.setMockInitialValues({
      'general_stock_enabled': true,
      'api_key': 'test-api-key',
    });

    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(() async {
    await awaitPendingHiveBoxWrites();
  });

  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  GetProduct buildProduct({
    required int productId,
    required String basePrice,
    required String mrp,
    required List<Stock> stocks,
    String unit = 'PCS',
    List<SaleUnit>? saleUnits,
  }) {
    return GetProduct(
      productId: productId,
      productName: 'Product $productId',
      price: ProductPrice(price: basePrice),
      mrp: mrp,
      purchasePrice: '8',
      unit: unit,
      stock: stocks,
      saleUnits: saleUnits,
      taxes: const <ProductTax>[],
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
    );
  }

  group('changeCartItemSaleUnit strict stock', () {
    test(
        'switching to a sale unit that needs more stock is rejected atomically',
        () {
      // Only 5 base units in stock. Cart currently holds a base-unit row of
      // quantity 5 (fully reserved). Switching the displayed number "1" to a
      // CASE of conversion rate 12 reinterprets display quantity 5 as 60 base
      // units. No additional stock is available, so the change must fail.
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      provider.setAllowOverselling(false);

      final stockOne = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(
        productId: 1,
        basePrice: '10',
        mrp: '12',
        stocks: <Stock>[stockOne],
        saleUnits: <SaleUnit>[
          SaleUnit(
            id: 10,
            unitId: 100,
            unitName: 'CASE',
            conversionRate: '12',
          ),
        ],
      );

      provider.initializeProducts(<GetProduct>[product]);
      provider.addToCart(
        product: product,
        quantity: 5,
        selectedStock: stockOne,
      );

      expect(provider.cartItems, hasLength(1));
      expect(provider.cartItems.first.stockDeducted, 5);

      final changed = provider.changeCartItemSaleUnit(
        product.productId!,
        stockOne,
        newSaleUnitId: 10,
        newSaleUnitName: 'CASE',
        newSaleUnitConversionRate: 12,
      );

      expect(changed, isFalse);
      expect(provider.cartItems, hasLength(1));
      final item = provider.cartItems.first;
      // The original line and reservation remain unchanged.
      expect(item.saleUnitId, isNull);
      expect(item.quantity, 5);
      expect(item.displayQuantity, 5);
      expect(item.stockDeducted, 5);

      final updatedProduct = provider.getProductById(1)!;
      expect(
        updatedProduct.stock!.firstWhere((s) => s.id == 1).quantity,
        0,
      );
    });

    test('default policy allows the sale-unit oversell', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);

      final stockOne = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(
        productId: 1,
        basePrice: '10',
        mrp: '12',
        stocks: <Stock>[stockOne],
      );
      provider.initializeProducts(<GetProduct>[product]);
      expect(
        provider.addToCart(
          product: product,
          quantity: 5,
          selectedStock: stockOne,
        ),
        isTrue,
      );

      final changed = provider.changeCartItemSaleUnit(
        product.productId!,
        stockOne,
        newSaleUnitId: 10,
        newSaleUnitName: 'CASE',
        newSaleUnitConversionRate: 12,
      );

      expect(changed, isTrue);
      expect(provider.cartItems.single.saleUnitId, 10);
      expect(provider.cartItems.single.quantity, 60);
      // Only real frontend stock is reserved; the remaining quantity is sent
      // as an oversell quantity for the backend to accept.
      expect(provider.cartItems.single.stockDeducted, 5);
    });

    test('sale-unit change consumes compatible stock before overselling', () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);

      final stockOne = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final stockTwo = buildStock(id: 2, quantity: 60, price: '10', mrp: '12');
      final product = buildProduct(
        productId: 1,
        basePrice: '10',
        mrp: '12',
        stocks: <Stock>[stockOne, stockTwo],
      );
      provider.initializeProducts(<GetProduct>[product]);
      provider.addToCart(
        product: product,
        quantity: 5,
        selectedStock: stockOne,
      );

      final changed = provider.changeCartItemSaleUnit(
        product.productId!,
        stockOne,
        newSaleUnitId: 10,
        newSaleUnitName: 'CASE',
        newSaleUnitConversionRate: 12,
      );

      expect(changed, isTrue);
      expect(provider.cartItems.single.quantity, 60);
      expect(provider.cartItems.single.stockDeducted, 60);
      expect(
        provider.cartItems.single.stockReservations
            .map((reservation) => reservation.stockId),
        <int>[1, 2],
      );
      expect(provider.getProductById(1)!.stock![1].quantity, 5);
    });
  });

  group('addToCart with unresolved productId', () {
    test(
        'non-existent productId and no product param does not throw and no-ops',
        () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);

      final stockOne = buildStock(id: 1, quantity: 5, price: '10', mrp: '12');
      final product = buildProduct(
        productId: 1,
        basePrice: '10',
        mrp: '12',
        stocks: <Stock>[stockOne],
      );
      provider.initializeProducts(<GetProduct>[product]);

      expect(
        () => provider.addToCart(
          productId: 999,
          quantity: 1,
        ),
        returnsNormally,
      );

      expect(provider.cartItems, isEmpty);
    });

    test('non-existent productId falls back to passed product without throwing',
        () {
      final provider = LocalProductProvider();
      provider.setStockEnabled(false);

      final fallbackProduct = buildProduct(
        productId: 42,
        basePrice: '15',
        mrp: '18',
        stocks: const <Stock>[],
      );
      provider.initializeProducts(<GetProduct>[fallbackProduct]);

      // productId 999 does not match any product in _products, but a
      // fallback `product` param is supplied, so it should be used instead
      // of throwing a StateError.
      expect(
        () => provider.addToCart(
          productId: 999,
          product: fallbackProduct,
          quantity: 2,
        ),
        returnsNormally,
      );

      expect(provider.cartItems, hasLength(1));
      expect(provider.cartItems.first.quantity, 2);
    });
  });
}
