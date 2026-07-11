/// Widget-level regression coverage for strict stock mode. The former
/// per-sale "sell anyway" dialog was replaced by the tenant-level
/// ALLOW_OVERSELL policy, so strict mode must block without showing a dialog.
///
/// See test/product_cart_helper_sellable_test.dart for the
/// `sellable == false` rejection coverage (kept in a separate file — see
/// the note on the test below for why).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/helpers/cart_quantity_stock_helper.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/models/local_models.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support/hive_test_teardown.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('epos_oversell_confirm_');
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
    SharedPreferences.setMockInitialValues({'general_stock_enabled': true});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(awaitPendingHiveBoxWrites);
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  group('CartQuantityStockHelper.syncCartItemQuantity strict stock', () {
    GetProduct buildProduct() {
      return GetProduct(
        productId: 1,
        productName: 'Sugar 1kg',
        unit: 'PCS',
        price: ProductPrice(price: '9'),
        mrp: '11',
        stock: <Stock>[
          Stock(
            id: 1,
            productId: 1,
            storeId: 1,
            quantity: 5,
            price: '10',
            mrp: '12',
          ),
        ],
      );
    }

    test('exhausted stock blocks increase in strict mode', () async {
      final provider = LocalProductProvider();
      provider.setStockEnabled(true);
      provider.setAllowOverselling(false);
      final product = buildProduct();
      provider.initializeProducts([product]);
      final stock = product.stock!.single;
      provider.addToCart(product: product, quantity: 5, selectedStock: stock);

      final cartItem =
          provider.cartItems.firstWhere((item) => item.selectedStock?.id == 1);

      String? blockedMessage;
      final result = await CartQuantityStockHelper.syncCartItemQuantity(
        cartItem: cartItem,
        newQuantity: 6,
        localProductProvider: provider,
        activeStoreId: 1,
        onBlocked: (message) {
          blockedMessage = message;
        },
      );

      expect(blockedMessage, isNotNull);
      expect(result.changed, isFalse);
      expect(result.appliedQuantity, 5);
      expect(
        provider.cartItems
            .firstWhere((item) => item.selectedStock?.id == 1)
            .quantity,
        5,
      );
    });
  });
}
