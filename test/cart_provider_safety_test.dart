/// Regression coverage for the cart/add-to-cart oversell-confirmation fixes:
/// - LocalProductProvider.changeCartItemSaleUnit no longer blocks (returns
///   false) when the target sale unit has insufficient stock; it now
///   reserves whatever is available and succeeds.
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
    SharedPreferences.setMockInitialValues({
      'general_stock_enabled': true,
      'api_key': 'test-api-key',
    });

    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
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

  group('changeCartItemSaleUnit oversell (no longer blocks)', () {
    test(
        'switching to a sale unit that needs more stock than available still succeeds',
        () {
      // Only 5 base units in stock. Cart currently holds a base-unit row of
      // quantity 5 (fully reserved). Switching the displayed number "1" to a
      // CASE of conversion rate 12 asks for 12 base units total -> only 5 are
      // physically reservable, but the change must succeed rather than block.
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);

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

      // Previously this returned false (blocked); now it must succeed.
      expect(changed, isTrue);
      expect(provider.cartItems, hasLength(1));
      final item = provider.cartItems.first;
      // Displayed number (5) is reinterpreted in the new unit: base quantity
      // becomes 5 * 12 = 60, even though only 5 base units were physically
      // reservable. The sale still proceeds (oversell allowed).
      expect(item.saleUnitId, 10);
      expect(item.quantity, 60);
      expect(item.displayQuantity, 5);
      // Stock reservation cannot exceed what was actually available (5).
      expect(item.stockDeducted, lessThanOrEqualTo(5));

      final updatedProduct = provider.getProductById(1)!;
      expect(
        updatedProduct.stock!.firstWhere((s) => s.id == 1).quantity,
        0,
      );
    });
  });

  group('addToCart with unresolved productId', () {
    test('non-existent productId and no product param does not throw and no-ops',
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
