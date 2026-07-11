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
    hiveDir = await Directory.systemTemp.createTemp('epos_warranty_test_');
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

  GetProduct product(int id) => GetProduct(
        productId: id,
        productName: 'Warranty product $id',
        price: ProductPrice(price: '100'),
        mrp: '120',
        unit: 'PCS',
      );

  test('warranty is emitted per item and remains after Hive rehydration',
      () async {
    final provider = LocalProductProvider();
    provider.setStockEnabled(false);
    final warrantyProduct = product(1);
    final standardProduct = product(2);

    provider.addToCart(product: warrantyProduct, warrantyEnabled: true);
    provider.addToCart(product: standardProduct);
    await provider.flushPersistence();

    expect(
      provider.buildOrderItemsPayload(),
      containsAll([
        containsPair('warranty_enabled', true),
        containsPair('warranty_enabled', false),
      ]),
    );

    final rehydratedProvider = LocalProductProvider();
    expect(rehydratedProvider.cartItems, hasLength(2));
    expect(
      rehydratedProvider.cartItems
          .firstWhere((item) => item.product.productId == 1)
          .warrantyEnabled,
      isTrue,
    );
    expect(
      rehydratedProvider.buildOrderItemsPayload(),
      contains(containsPair('warranty_enabled', true)),
    );
  });
}
