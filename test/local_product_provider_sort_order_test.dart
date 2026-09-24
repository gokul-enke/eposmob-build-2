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
    hiveDir = await Directory.systemTemp.createTemp('epos_sort_order_test_');
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
    SharedPreferences.setMockInitialValues({'api_key': 'test-api-key'});
    await Hive.box<HiveProduct>('products').clear();
    await Hive.box<HiveLocalCartItem>('cart_items').clear();
    await Hive.box<HiveSavedOrder>('saved_orders').clear();
    await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
  });

  tearDown(awaitPendingHiveBoxWrites);
  tearDownAll(() => closeHiveAndDeleteTestDir(hiveDir));

  GetProduct product(int id, String name, int? sortOrder) =>
      GetProduct(productId: id, productName: name, sortOrder: sortOrder);

  List<int?> ids(List<GetProduct> products) =>
      products.map((p) => p.productId).toList();

  test('a synced change places products by sort_order, not at the end',
      () async {
    final provider = LocalProductProvider();
    provider.initializeProducts([
      product(1, 'asd', 10),
      product(2, 'classic', 20),
      product(3, 'crispy', 30),
    ]);
    expect(ids(provider.products), [1, 2, 3]);

    await provider.mergeRealtimeCatalog(
      [
        product(3, 'crispy', 5), // sort_order changed 30 -> 5
        product(4, 'Test', 15), // new product
      ],
      deletedProductIds: const <int>{},
    );

    expect(ids(provider.products), [3, 1, 4, 2]);
    expect(ids(provider.sellableProducts), [3, 1, 4, 2]);
  });
}
